#include <windows.h>
#include <gdiplus.h>
#include <d3d11.h>
#include <thread>
#include <queue>
#include <mutex>
#include <condition_variable>
#include "ILuaModuleManager.h"
#include "DesktopDuplicationBackend.h"
#include "../core/ModalityManager.h"
#include "../core/MediaFoundationUtils.h"
#include "../core/DebugLog.h"
#include "AsyncFrameProcessor.h"
#include "LuaBindings.h"

#pragma comment(lib, "gdiplus.lib")
#pragma comment(lib, "d3d11.lib")

using namespace Gdiplus;

// Debug control flag - can be controlled from Lua
bool ENABLE_SCREENSHOT_MODULE_DEBUG = true;

// Feature flags
bool USE_DESKTOP_DUPLICATION = true;  // Desktop Duplication API (fast, video support)
bool USE_BITBLT_FALLBACK = false;      // BitBlt fallback (slower, PNG only)
const int DEFAULT_CROP_TOP = 40;
const int DEFAULT_CROP_LEFT = 3;
const int DEFAULT_CROP_RIGHT = 3;
const int DEFAULT_CROP_BOTTOM = 15;

// Global state
ILuaModuleManager10* g_pModuleManager = nullptr;
ModalityManager* g_modalityManager = nullptr;
DesktopDuplicationBackend* g_captureBackend = nullptr;
AsyncFrameProcessor* g_frameProcessor = nullptr;
ULONG_PTR g_gdiplusToken = 0;

// BitBlt screenshot queue and worker thread
struct ScreenshotRequest {
    std::string outputPath;
    std::string windowTitle;
    int callbackRef;
    lua_State* luaVM;
    bool completed;
    bool success;
};

class ScreenshotQueue {
private:
    std::queue<std::shared_ptr<ScreenshotRequest>> requests;
    std::mutex mtx;
    std::condition_variable cv;
    bool running = true;

public:
    void push(std::shared_ptr<ScreenshotRequest> req) {
        std::lock_guard<std::mutex> lock(mtx);
        requests.push(req);
        cv.notify_one();
    }

    std::shared_ptr<ScreenshotRequest> pop() {
        std::unique_lock<std::mutex> lock(mtx);
        cv.wait(lock, [this] { return !requests.empty() || !running; });
        if (!running && requests.empty()) return nullptr;
        auto req = requests.front();
        requests.pop();
        return req;
    }

    void stop() {
        std::lock_guard<std::mutex> lock(mtx);
        running = false;
        cv.notify_all();
    }
};

ScreenshotQueue g_screenshotQueue;
std::thread* g_workerThread = nullptr;

// Pending Lua callbacks queue
struct PendingLuaCallback {
    lua_State* luaVM;
    int callbackRef;
    bool success;
    int width;
    int height;
};

std::queue<PendingLuaCallback> g_pendingCallbacks;
std::mutex g_callbackMutex;

// Helper functions
int GetEncoderClsid(const WCHAR* format, CLSID* pClsid);
bool CreateDirectoryRecursive(const std::string& path);
HWND FindWindowByTitle(const std::string& title);
bool TakeWindowScreenshotBitBlt(HWND hwnd, const std::string& outputPath, std::shared_ptr<ScreenshotRequest> request);
void ScreenshotWorker();

// Lua API implementation
namespace LuaBindings {

int lua_startVideoRecording(lua_State* L) {
    int modalityId = (int)luaL_checkinteger(L, 1);
    const char* path = luaL_checkstring(L, 2);
    int width = (int)luaL_checkinteger(L, 3);
    int height = (int)luaL_checkinteger(L, 4);
    int fps = (int)luaL_optinteger(L, 5, 30);
    int bitrate = (int)luaL_optinteger(L, 6, 5000000);

    DEBUG_LOG_FMT("LuaBindings", "startVideoRecording: modality=%d, path=%s, target_dims=%dx%d, fps=%d, bitrate=%d",
        modalityId, path, width, height, fps, bitrate);

    if (!USE_DESKTOP_DUPLICATION) {
        lua_pushboolean(L, false);
        lua_pushstring(L, "Desktop Duplication disabled - use BitBlt mode");
        return 2;
    }

    if (!g_modalityManager || !g_captureBackend) {
        lua_pushboolean(L, false);
        lua_pushstring(L, "Module not initialized");
        return 2;
    }

    if (!g_captureBackend->IsInitialized()) {
        lua_pushboolean(L, false);
        lua_pushstring(L, "Desktop Duplication not initialized");
        return 2;
    }

    // Log native capture dimensions vs target dimensions
    int nativeWidth = g_captureBackend->GetWidth();
    int nativeHeight = g_captureBackend->GetHeight();
    DEBUG_LOG_FMT("LuaBindings", "startVideoRecording: native_capture=%dx%d, target_output=%dx%d",
        nativeWidth, nativeHeight, width, height);

    bool success = g_modalityManager->StartRecording(modalityId, path, width, height, fps, bitrate);

    if (success) {
        lua_pushboolean(L, true);
        return 1;
    } else {
        lua_pushboolean(L, false);
        lua_pushstring(L, "Failed to start video encoder");
        return 2;
    }
}

int lua_stopVideoRecording(lua_State* L) {
    int modalityId = (int)luaL_checkinteger(L, 1);

    if (!USE_DESKTOP_DUPLICATION) {
        lua_pushboolean(L, false);
        lua_pushstring(L, "Desktop Duplication disabled");
        return 2;
    }

    if (!g_modalityManager) {
        lua_pushboolean(L, false);
        lua_pushstring(L, "Module not initialized");
        return 2;
    }

    bool success = g_modalityManager->StopRecording(modalityId);

    if (success) {
        lua_pushboolean(L, true);
        return 1;
    } else {
        lua_pushboolean(L, false);
        lua_pushstring(L, "No encoder found for modality");
        return 2;
    }
}

int lua_captureFrame(lua_State* L) {
    // Parameters: path, imageFormat, saveToVideo, modalityId, callback, [jpegQuality]
    const char* path = luaL_checkstring(L, 1);
    const char* imageFormatStr = luaL_checkstring(L, 2);
    bool saveToVideo = lua_toboolean(L, 3);
    int modality = (int)luaL_checkinteger(L, 4);
    int callbackRef = LUA_NOREF;
    int jpegQuality = 95;

    // Parse callback (parameter 5)
    if (lua_isfunction(L, 5)) {
        lua_pushvalue(L, 5);
        callbackRef = luaL_ref(L, LUA_REGISTRYINDEX);
    }

    // Parse optional jpegQuality (parameter 6)
    if (lua_isnumber(L, 6)) {
        jpegQuality = (int)lua_tointeger(L, 6);
        if (jpegQuality < 0) jpegQuality = 0;
        if (jpegQuality > 100) jpegQuality = 100;
    }

    // Parse image format string
    ImageFormat imageFormat = ImageFormat::NONE;
    std::string formatStr(imageFormatStr);
    if (formatStr == "png") {
        imageFormat = ImageFormat::PNG;
    } else if (formatStr == "png_indexed") {
        imageFormat = ImageFormat::PNG_INDEXED;
    } else if (formatStr == "jpeg") {
        imageFormat = ImageFormat::JPEG;
    } else if (formatStr == "none") {
        imageFormat = ImageFormat::NONE;
    }

    if (!USE_DESKTOP_DUPLICATION) {
        if (callbackRef != LUA_NOREF) {
            luaL_unref(L, LUA_REGISTRYINDEX, callbackRef);
        }
        lua_pushboolean(L, false);
        lua_pushstring(L, "Desktop Duplication disabled");
        return 2;
    }

    if (!g_frameProcessor) {
        if (callbackRef != LUA_NOREF) {
            luaL_unref(L, LUA_REGISTRYINDEX, callbackRef);
        }
        lua_pushboolean(L, false);
        lua_pushstring(L, "Module not initialized");
        return 2;
    }

    CaptureRequest req;
    req.modalityId = modality;
    req.imagePath = path;
    req.imageFormat = imageFormat;
    req.saveToVideo = saveToVideo;
    req.jpegQuality = jpegQuality;
    req.callbackRef = callbackRef;
    req.luaVM = L;

    g_frameProcessor->SubmitCaptureRequest(req);

    lua_pushboolean(L, true);
    return 1;
}

// BitBlt fallback function - takeAsyncScreenshot (original implementation)
int lua_takeAsyncScreenshot(lua_State* L) {
    const char* outputPath = luaL_checkstring(L, 1);
    const char* windowTitle = luaL_optstring(L, 2, "MTA: San Andreas");

    DEBUG_LOG_FMT("LuaBindings", "takeAsyncScreenshot: path=%s, window=%s", outputPath, windowTitle);

    auto request = std::make_shared<ScreenshotRequest>();
    request->outputPath = outputPath;
    request->windowTitle = windowTitle;
    request->completed = false;
    request->success = false;
    request->callbackRef = LUA_NOREF;
    request->luaVM = L;

    if (lua_isfunction(L, 3)) {
        lua_pushvalue(L, 3);
        request->callbackRef = luaL_ref(L, LUA_REGISTRYINDEX);
        DEBUG_LOG("LuaBindings", "takeAsyncScreenshot: callback registered");
    }

    g_screenshotQueue.push(request);
    DEBUG_LOG("LuaBindings", "takeAsyncScreenshot: request queued");

    lua_pushboolean(L, 1);
    return 1;
}

// Debug control functions
int lua_setScreenshotModuleDebug(lua_State* L) {
    bool enable = lua_toboolean(L, 1);
    ENABLE_SCREENSHOT_MODULE_DEBUG = enable;

    // Log the state change
    if (enable) {
        DEBUG_LOG("LuaBindings", "Debug tracing ENABLED via Lua");
    } else {
        // This won't print if we just disabled it, but that's expected
        printf("[LuaBindings] Debug tracing DISABLED via Lua\n");
    }

    lua_pushboolean(L, true);
    return 1;
}

int lua_getScreenshotModuleDebug(lua_State* L) {
    lua_pushboolean(L, ENABLE_SCREENSHOT_MODULE_DEBUG);
    return 1;
}

void InvokeLuaCallback(lua_State* L, int callbackRef, bool success, int width, int height) {
    lua_rawgeti(L, LUA_REGISTRYINDEX, callbackRef);
    lua_pushboolean(L, success);
    lua_pushinteger(L, width);
    lua_pushinteger(L, height);

    if (lua_pcall(L, 3, 0, 0) != 0) {
        const char* err = lua_tostring(L, -1);
        lua_pop(L, 1);
    }

    luaL_unref(L, LUA_REGISTRYINDEX, callbackRef);
}

void QueueLuaCallback(lua_State* L, int callbackRef, bool success, int width, int height) {
    if (callbackRef == LUA_NOREF) return;

    PendingLuaCallback cb;
    cb.luaVM = L;
    cb.callbackRef = callbackRef;
    cb.success = success;
    cb.width = width;
    cb.height = height;

    std::lock_guard<std::mutex> lock(g_callbackMutex);
    g_pendingCallbacks.push(cb);
}

void RegisterFunctions(lua_State* L) {
    // Desktop Duplication API functions (video support)
    lua_register(L, "startVideoRecording", lua_startVideoRecording);
    lua_register(L, "stopVideoRecording", lua_stopVideoRecording);
    lua_register(L, "captureFrame", lua_captureFrame);

    // BitBlt fallback (PNG only)
    lua_register(L, "takeAsyncScreenshot", lua_takeAsyncScreenshot);

    // Debug control
    lua_register(L, "setScreenshotModuleDebug", lua_setScreenshotModuleDebug);
    lua_register(L, "getScreenshotModuleDebug", lua_getScreenshotModuleDebug);
}

} // namespace LuaBindings

// Helper function implementations
struct WindowSearchData {
    const std::string* targetTitle;
    HWND foundWindow;
};

HWND FindWindowByTitle(const std::string& title) {
    WindowSearchData searchData;
    searchData.targetTitle = &title;
    searchData.foundWindow = nullptr;

    EnumWindows([](HWND hwnd, LPARAM lParam) -> BOOL {
        WindowSearchData* data = reinterpret_cast<WindowSearchData*>(lParam);
        char windowText[256];
        GetWindowTextA(hwnd, windowText, sizeof(windowText));

        if (std::string(windowText).find(*data->targetTitle) != std::string::npos) {
            data->foundWindow = hwnd;
            return FALSE;
        }
        return TRUE;
    }, reinterpret_cast<LPARAM>(&searchData));

    return searchData.foundWindow;
}

bool CreateDirectoryRecursive(const std::string& path) {
    std::string dir = path;
    size_t lastSlash = dir.find_last_of("/\\");
    if (lastSlash != std::string::npos) {
        dir = dir.substr(0, lastSlash);
    }

    for (char& c : dir) {
        if (c == '/') c = '\\';
    }

    size_t pos = 0;
    do {
        pos = dir.find_first_of('\\', pos + 1);
        std::string subdir = dir.substr(0, pos);
        if (!subdir.empty() && subdir.length() > 2) {
            CreateDirectoryA(subdir.c_str(), NULL);
        }
    } while (pos != std::string::npos);

    return true;
}

int GetEncoderClsid(const WCHAR* format, CLSID* pClsid) {
    UINT num = 0, size = 0;
    ImageCodecInfo* pImageCodecInfo = nullptr;

    GetImageEncodersSize(&num, &size);
    if (size == 0) return -1;

    pImageCodecInfo = (ImageCodecInfo*)(malloc(size));
    if (pImageCodecInfo == nullptr) return -1;

    GetImageEncoders(num, size, pImageCodecInfo);

    for (UINT j = 0; j < num; ++j) {
        if (wcscmp(pImageCodecInfo[j].MimeType, format) == 0) {
            *pClsid = pImageCodecInfo[j].Clsid;
            free(pImageCodecInfo);
            return j;
        }
    }

    free(pImageCodecInfo);
    return -1;
}

bool TakeWindowScreenshotBitBlt(HWND hwnd, const std::string& outputPath, std::shared_ptr<ScreenshotRequest> request) {
    if (!hwnd || !IsWindow(hwnd)) return false;

    RECT rect;
    if (!GetWindowRect(hwnd, &rect)) return false;

    int fullWidth = rect.right - rect.left;
    int fullHeight = rect.bottom - rect.top;
    int croppedHeight = fullHeight - DEFAULT_CROP_TOP;
    int width = fullWidth;
    int height = croppedHeight;

    if (width <= 0 || height <= 0) return false;

    HDC hdcScreen = GetDC(nullptr);
    HDC hdcMemory = CreateCompatibleDC(hdcScreen);
    HBITMAP hBitmap = CreateCompatibleBitmap(hdcScreen, width, height);

    if (!hdcScreen || !hdcMemory || !hBitmap) {
        if (hdcScreen) ReleaseDC(nullptr, hdcScreen);
        if (hdcMemory) DeleteDC(hdcMemory);
        if (hBitmap) DeleteObject(hBitmap);
        return false;
    }

    HBITMAP hOldBitmap = (HBITMAP)SelectObject(hdcMemory, hBitmap);

    // Capture pixels with BitBlt (crop toolbar)
    bool result = BitBlt(hdcMemory, 0, 0, width, height, hdcScreen, rect.left, rect.top + DEFAULT_CROP_TOP, SRCCOPY);

    // Pixels are in memory - release resources BEFORE callback (allows re-rendering)
    SelectObject(hdcMemory, hOldBitmap);
    DeleteDC(hdcMemory);
    ReleaseDC(nullptr, hdcScreen);

    // NOW invoke callback - client can safely re-render
    if (result && request && request->callbackRef != LUA_NOREF && request->luaVM) {
        lua_State* L = request->luaVM;
        lua_rawgeti(L, LUA_REGISTRYINDEX, request->callbackRef);
        lua_pushboolean(L, true);
        lua_pushinteger(L, width);
        lua_pushinteger(L, height);

        if (lua_pcall(L, 3, 0, 0) != 0) {
            const char* err = lua_tostring(L, -1);
            lua_pop(L, 1);
        }

        luaL_unref(L, LUA_REGISTRYINDEX, request->callbackRef);
    }

    // Save to disk (happens in background)
    if (result) {
        CreateDirectoryRecursive(outputPath);
        Bitmap bitmap(hBitmap, nullptr);
        CLSID pngClsid;
        GetEncoderClsid(L"image/png", &pngClsid);
        std::wstring wPath(outputPath.begin(), outputPath.end());
        Status status = bitmap.Save(wPath.c_str(), &pngClsid, nullptr);
        result = (status == Ok);
    }

    DeleteObject(hBitmap);
    return result;
}

void ScreenshotWorker() {
    while (true) {
        auto request = g_screenshotQueue.pop();
        if (!request) break;

        HWND hwnd = FindWindowByTitle(request->windowTitle);

        if (hwnd) {
            request->success = TakeWindowScreenshotBitBlt(hwnd, request->outputPath, request);
        } else {
            request->success = false;
            if (request->callbackRef != LUA_NOREF && request->luaVM) {
                lua_State* L = request->luaVM;
                lua_rawgeti(L, LUA_REGISTRYINDEX, request->callbackRef);
                lua_pushboolean(L, false);
                lua_pushinteger(L, 0);
                lua_pushinteger(L, 0);
                lua_pcall(L, 3, 0, 0);
                luaL_unref(L, LUA_REGISTRYINDEX, request->callbackRef);
            }
        }

        request->completed = true;
    }
}

// MTA Module exports
extern "C" {

MTAEXPORT bool InitModule(ILuaModuleManager10* pManager, char* szModuleName, char* szAuthor, float* fVersion) {
    DEBUG_LOG("InitModule", "==== Screenshot Module InitModule called ====");

    g_pModuleManager = pManager;

    // Set module info
    strcpy_s(szModuleName, 128, "Screenshot Module");
    strcpy_s(szAuthor, 128, "Claude");
    *fVersion = 2.0f;

    DEBUG_LOG_FMT("InitModule", "Module info: name=%s, author=%s, version=%.1f", szModuleName, szAuthor, *fVersion);

    // Initialize GDI+
    DEBUG_LOG("InitModule", "Initializing GDI+...");
    GdiplusStartupInput gdiplusStartupInput;
    GdiplusStartup(&g_gdiplusToken, &gdiplusStartupInput, nullptr);
    DEBUG_LOG("InitModule", "GDI+ initialized");

    // Initialize Desktop Duplication backend if enabled
    if (USE_DESKTOP_DUPLICATION) {
        DEBUG_LOG("InitModule", "Desktop Duplication enabled, initializing...");

        // Initialize Media Foundation
        if (!MediaFoundationUtils::Initialize()) {
            DEBUG_LOG("InitModule", "Media Foundation initialization failed");
            if (!USE_BITBLT_FALLBACK) {
                GdiplusShutdown(g_gdiplusToken);
                return false;  // Fail fast if no fallback
            }
            DEBUG_LOG("InitModule", "Falling back to BitBlt mode");
            USE_DESKTOP_DUPLICATION = false;  // Disable and use fallback
        } else {
            // Create modality manager
            DEBUG_LOG("InitModule", "Creating modality manager...");
            g_modalityManager = new ModalityManager();

            // Create async frame processor
            DEBUG_LOG("InitModule", "Creating async frame processor...");
            g_frameProcessor = new AsyncFrameProcessor(g_modalityManager);
            g_frameProcessor->Start();

            // Create Desktop Duplication backend
            DEBUG_LOG_FMT("InitModule", "Creating Desktop Duplication backend (window=MTA: San Andreas, crops t=%d l=%d r=%d b=%d)...",
                         DEFAULT_CROP_TOP, DEFAULT_CROP_LEFT, DEFAULT_CROP_RIGHT, DEFAULT_CROP_BOTTOM);
            g_captureBackend = new DesktopDuplicationBackend("MTA: San Andreas",
                                                            DEFAULT_CROP_TOP, DEFAULT_CROP_LEFT, DEFAULT_CROP_RIGHT, DEFAULT_CROP_BOTTOM);
            if (!g_captureBackend->Initialize()) {
                DEBUG_LOG("InitModule", "Desktop Duplication backend initialization failed");
                delete g_captureBackend;
                g_captureBackend = nullptr;
                g_frameProcessor->Stop();
                delete g_frameProcessor;
                g_frameProcessor = nullptr;
                delete g_modalityManager;
                g_modalityManager = nullptr;
                MediaFoundationUtils::Shutdown();

                if (!USE_BITBLT_FALLBACK) {
                    GdiplusShutdown(g_gdiplusToken);
                    return false;  // Fail fast if no fallback
                }
                DEBUG_LOG("InitModule", "Falling back to BitBlt mode");
                USE_DESKTOP_DUPLICATION = false;  // Disable and use fallback
            } else {
                DEBUG_LOG("InitModule", "Desktop Duplication backend initialized successfully");
            }
        }
    }

    // Start BitBlt worker thread if fallback enabled
    if (USE_BITBLT_FALLBACK) {
        DEBUG_LOG("InitModule", "Starting BitBlt worker thread...");
        g_workerThread = new std::thread(ScreenshotWorker);
        DEBUG_LOG("InitModule", "BitBlt worker thread started");
    }

    DEBUG_LOG("InitModule", "==== InitModule completed successfully ====");
    return true;
}

MTAEXPORT void DeinitModule() {
    // Stop async frame processor (waits for queue to empty)
    if (g_frameProcessor) {
        g_frameProcessor->Stop();
        delete g_frameProcessor;
        g_frameProcessor = nullptr;
    }

    // Stop all video recordings
    if (g_modalityManager) {
        g_modalityManager->StopAll();
        delete g_modalityManager;
        g_modalityManager = nullptr;
    }

    // Cleanup Desktop Duplication
    if (g_captureBackend) {
        g_captureBackend->Cleanup();
        delete g_captureBackend;
        g_captureBackend = nullptr;
    }

    // Shutdown Media Foundation
    MediaFoundationUtils::Shutdown();

    // Stop BitBlt worker thread
    if (g_workerThread) {
        g_screenshotQueue.stop();
        g_workerThread->join();
        delete g_workerThread;
        g_workerThread = nullptr;
    }

    // Shutdown GDI+
    GdiplusShutdown(g_gdiplusToken);
}

MTAEXPORT void RegisterFunctions(lua_State* luaVM) {
    if (g_pModuleManager && luaVM) {
        LuaBindings::RegisterFunctions(luaVM);
    }
}

MTAEXPORT bool DoPulse() {
    // Process pending Lua callbacks on main thread
    std::lock_guard<std::mutex> lock(g_callbackMutex);
    while (!g_pendingCallbacks.empty()) {
        PendingLuaCallback cb = g_pendingCallbacks.front();
        g_pendingCallbacks.pop();

        LuaBindings::InvokeLuaCallback(cb.luaVM, cb.callbackRef, cb.success, cb.width, cb.height);
    }

    return true;
}

MTAEXPORT bool ShutdownModule() {
    DeinitModule();
    return true;
}

MTAEXPORT bool ResourceStopping(lua_State* luaVM) {
    return true;
}

MTAEXPORT bool ResourceStopped(lua_State* luaVM) {
    return true;
}

} // extern "C"
