#include <windows.h>
#include <gdiplus.h>
#include <thread>
#include <string>
#include <queue>
#include <mutex>
#include <condition_variable>
#include <iostream>
#include <vector>
#include <algorithm>

#include "ILuaModuleManager.h"

#pragma comment(lib, "gdiplus.lib")

using namespace Gdiplus;
using namespace std;

// Debug control - set to true to enable debug output
const bool ENABLE_DEBUG = false;

// Crop settings - remove toolbar from top of screenshot
const int CROP_TOP = 40;  // Pixels to crop from top (MTA toolbar height)

// Debug logging helper
void DebugLog(const char* message) {
    if (!ENABLE_DEBUG) return;

    // Write to file
    FILE* f = fopen("screenshot_module_debug.log", "a");
    if (f) {
        fprintf(f, "[Screenshot Module] %s\n", message);
        fclose(f);
    }
    // Print to console
    printf("[Screenshot Module] %s\n", message);
    OutputDebugStringA("[Screenshot Module] ");
    OutputDebugStringA(message);
    OutputDebugStringA("\n");
}

void DebugLogFormat(const char* format, ...) {
    if (!ENABLE_DEBUG) return;

    char buffer[512];
    va_list args;
    va_start(args, format);
    vsnprintf(buffer, sizeof(buffer), format, args);
    va_end(args);
    DebugLog(buffer);
}

// Global module manager
ILuaModuleManager10* pModuleManager = nullptr;

// Simple module state tracking (like ml_pathfind)
class ScreenshotModule {
public:
    std::vector<lua_State*> luaVMs;

    void AddLuaVM(lua_State* luaVM) {
        luaVMs.push_back(luaVM);
    }

    void RemoveLuaVM(lua_State* luaVM) {
        luaVMs.erase(std::remove(luaVMs.begin(), luaVMs.end(), luaVM), luaVMs.end());
    }
};

ScreenshotModule* g_Module = nullptr;

// Screenshot request structure
struct ScreenshotRequest {
    string outputPath;
    string windowTitle;
    bool completed;
    bool success;
    int callbackRef; // Lua callback reference
    lua_State* luaVM; // Lua state for callback
};

// Thread-safe queue for screenshot requests
class ScreenshotQueue {
private:
    queue<shared_ptr<ScreenshotRequest>> requests;
    mutex mtx;
    condition_variable cv;
    bool running = true;

public:
    void push(shared_ptr<ScreenshotRequest> req) {
        lock_guard<mutex> lock(mtx);
        requests.push(req);
        cv.notify_one();
    }

    shared_ptr<ScreenshotRequest> pop() {
        unique_lock<mutex> lock(mtx);
        cv.wait(lock, [this] { return !requests.empty() || !running; });

        if (!running && requests.empty()) return nullptr;

        auto req = requests.front();
        requests.pop();
        return req;
    }

    void stop() {
        lock_guard<mutex> lock(mtx);
        running = false;
        cv.notify_all();
    }
};

// Global screenshot queue and worker thread
ScreenshotQueue screenshotQueue;
thread* workerThread = nullptr;
ULONG_PTR gdiplusToken;

// Forward declaration
int GetEncoderClsid(const WCHAR* format, CLSID* pClsid);

// Convert relative path to absolute path
string GetAbsolutePath(const string& path) {
    // Check if path is already absolute (has drive letter or starts with \\)
    if (path.length() >= 2 && path[1] == ':') {
        DebugLogFormat("Path is already absolute: %s", path.c_str());
        return path;
    }
    if (path.length() >= 2 && path[0] == '\\' && path[1] == '\\') {
        DebugLogFormat("Path is UNC path: %s", path.c_str());
        return path;
    }

    // Get current working directory
    char cwd[MAX_PATH];
    GetCurrentDirectoryA(MAX_PATH, cwd);

    DebugLogFormat("Current working directory: %s", cwd);
    DebugLogFormat("Relative path: %s", path.c_str());

    // Combine paths
    string absolutePath = string(cwd) + "\\" + path;

    // Replace forward slashes with backslashes
    for (char& c : absolutePath) {
        if (c == '/') c = '\\';
    }

    DebugLogFormat("Absolute path: %s", absolutePath.c_str());
    return absolutePath;
}

// Create directory recursively
bool CreateDirectoryRecursive(const string& path) {
    string dir = path;

    // Extract directory from full path (remove filename)
    size_t lastSlash = dir.find_last_of("/\\");
    if (lastSlash != string::npos) {
        dir = dir.substr(0, lastSlash);
    }

    // Replace forward slashes with backslashes for Windows
    for (char& c : dir) {
        if (c == '/') c = '\\';
    }

    DebugLogFormat("Creating directory: %s", dir.c_str());

    // Create directory recursively
    size_t pos = 0;
    do {
        pos = dir.find_first_of('\\', pos + 1);
        string subdir = dir.substr(0, pos);

        if (!subdir.empty() && subdir.length() > 2) { // Skip drive letter (e.g., "C:")
            BOOL result = CreateDirectoryA(subdir.c_str(), NULL);
            DWORD error = GetLastError();
            if (!result && error != ERROR_ALREADY_EXISTS) {
                DebugLogFormat("Failed to create directory '%s': error %d", subdir.c_str(), error);
            }
        }
    } while (pos != string::npos);

    return true;
}

// Find window by title
struct WindowSearchData {
    const string* targetTitle;
    HWND foundWindow;
};

HWND FindWindowByTitle(const string& title) {
    DebugLogFormat("Looking for window with title: %s", title.c_str());

    WindowSearchData searchData;
    searchData.targetTitle = &title;
    searchData.foundWindow = nullptr;

    EnumWindows([](HWND hwnd, LPARAM lParam) -> BOOL {
        WindowSearchData* data = reinterpret_cast<WindowSearchData*>(lParam);

        char windowText[256];
        GetWindowTextA(hwnd, windowText, sizeof(windowText));

        DebugLogFormat("Checking window: %s", windowText);
        if (string(windowText).find(*data->targetTitle) != string::npos) {
            DebugLogFormat("MATCH FOUND: %s", windowText);
            data->foundWindow = hwnd;
            return FALSE; // Stop enumeration
        }

        return TRUE; // Continue enumeration
    }, reinterpret_cast<LPARAM>(&searchData));

    if (searchData.foundWindow) {
        DebugLog("Window found!");
    } else {
        DebugLog("Window NOT found!");
    }

    return searchData.foundWindow;
}

// Take screenshot of specific window with callback support
bool TakeWindowScreenshot(HWND hwnd, const string& outputPath, shared_ptr<ScreenshotRequest> request = nullptr) {
    DebugLogFormat("TakeWindowScreenshot called: path=%s", outputPath.c_str());

    // Convert to absolute path
    string absolutePath = GetAbsolutePath(outputPath);

    if (!hwnd || !IsWindow(hwnd)) {
        DebugLog("ERROR: Invalid window handle");
        return false;
    }

    RECT rect;
    if (!GetWindowRect(hwnd, &rect)) {
        DebugLog("ERROR: Failed to get window rect");
        return false;
    }

    int fullWidth = rect.right - rect.left;
    int fullHeight = rect.bottom - rect.top;
    DebugLogFormat("Window dimensions: %dx%d", fullWidth, fullHeight);

    // Apply crop - remove toolbar from top
    int croppedHeight = fullHeight - CROP_TOP;
    int width = fullWidth;
    int height = croppedHeight;

    if (width <= 0 || height <= 0) {
        DebugLog("ERROR: Invalid window dimensions after cropping");
        return false;
    }

    DebugLogFormat("Cropped dimensions: %dx%d (removed %d pixels from top)", width, height, CROP_TOP);

    // Create device contexts
    HDC hdcScreen = GetDC(nullptr);
    HDC hdcMemory = CreateCompatibleDC(hdcScreen);
    HBITMAP hBitmap = CreateCompatibleBitmap(hdcScreen, width, height);

    if (!hdcScreen || !hdcMemory || !hBitmap) {
        DebugLog("ERROR: Failed to create device contexts");
        if (hdcScreen) ReleaseDC(nullptr, hdcScreen);
        if (hdcMemory) DeleteDC(hdcMemory);
        if (hBitmap) DeleteObject(hBitmap);
        return false;
    }

    HBITMAP hOldBitmap = (HBITMAP)SelectObject(hdcMemory, hBitmap);

    // Copy window content to memory DC (pixels are now in memory)
    // Skip CROP_TOP pixels from the top to remove the toolbar
    DebugLog("Capturing pixels with BitBlt (cropping toolbar)...");
    bool result = BitBlt(hdcMemory, 0, 0, width, height, hdcScreen, rect.left, rect.top + CROP_TOP, SRCCOPY);

    if (result) {
        DebugLog("Pixels captured successfully!");
    } else {
        DebugLog("ERROR: BitBlt failed!");
    }

    if (result && request && request->callbackRef != LUA_NOREF && request->luaVM) {
        // Pixels are available in memory - trigger callback before saving to disk
        DebugLog("Invoking Lua callback (pixels in memory)...");
        lua_State* L = request->luaVM;

        // Get the callback function from registry
        lua_rawgeti(L, LUA_REGISTRYINDEX, request->callbackRef);

        // Push success status and dimensions
        lua_pushboolean(L, true);
        lua_pushinteger(L, width);
        lua_pushinteger(L, height);

        // Call the callback
        if (lua_pcall(L, 3, 0, 0) != 0) {
            // Error in callback execution
            const char* err = lua_tostring(L, -1);
            DebugLogFormat("ERROR: Callback execution failed: %s", err ? err : "unknown");
            lua_pop(L, 1);
        } else {
            DebugLog("Callback invoked successfully!");
        }

        // Unref the callback
        luaL_unref(L, LUA_REGISTRYINDEX, request->callbackRef);
    }

    if (result) {
        // Convert to GDI+ Bitmap and save
        DebugLog("Converting to GDI+ Bitmap and saving to disk...");

        // Create directory structure first
        CreateDirectoryRecursive(absolutePath);

        Bitmap bitmap(hBitmap, nullptr);

        // Get PNG encoder CLSID
        CLSID pngClsid;
        int encoderResult = GetEncoderClsid(L"image/png", &pngClsid);
        if (encoderResult < 0) {
            DebugLog("ERROR: Failed to get PNG encoder CLSID");
        }

        // Convert path to wide string
        wstring wPath(absolutePath.begin(), absolutePath.end());

        DebugLogFormat("Saving to: %s", absolutePath.c_str());

        // Save as PNG
        Status status = bitmap.Save(wPath.c_str(), &pngClsid, nullptr);
        result = (status == Ok);

        if (result) {
            DebugLogFormat("Screenshot saved successfully to: %s", absolutePath.c_str());
        } else {
            DebugLogFormat("ERROR: Failed to save screenshot (GDI+ status: %d)", status);
        }
    }

    // Cleanup
    SelectObject(hdcMemory, hOldBitmap);
    DeleteObject(hBitmap);
    DeleteDC(hdcMemory);
    ReleaseDC(nullptr, hdcScreen);

    return result;
}

// Get encoder CLSID for image format
int GetEncoderClsid(const WCHAR* format, CLSID* pClsid) {
    UINT num = 0;
    UINT size = 0;

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

// Worker thread function
void ScreenshotWorker() {
    DebugLog("Worker thread started");
    while (true) {
        DebugLog("Worker thread waiting for request...");
        auto request = screenshotQueue.pop();
        if (!request) {
            DebugLog("Worker thread shutting down");
            break; // Thread shutdown
        }

        DebugLogFormat("Worker thread received request: %s", request->outputPath.c_str());

        // Find window by title
        HWND hwnd = FindWindowByTitle(request->windowTitle);

        if (hwnd) {
            // Take screenshot with callback support
            DebugLog("Taking screenshot...");
            request->success = TakeWindowScreenshot(hwnd, request->outputPath, request);
        } else {
            // Window with title request->windowTitle not found
            DebugLogFormat("ERROR: Window not found - title: %s", request->windowTitle.c_str());
            request->success = false;
            // Call callback with failure if provided
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
        DebugLogFormat("Request completed: success=%d", request->success);
    }
}

// Lua function: takeAsyncScreenshot(outputPath, windowTitle, callback)
int lua_takeAsyncScreenshot(lua_State* L) {
    const char* outputPath = luaL_checkstring(L, 1);
    const char* windowTitle = luaL_optstring(L, 2, "MTA: San Andreas");

    DebugLogFormat("Lua: takeAsyncScreenshot called - path=%s, window=%s", outputPath, windowTitle);

    // Create screenshot request
    auto request = make_shared<ScreenshotRequest>();
    request->outputPath = outputPath;
    request->windowTitle = windowTitle;
    request->completed = false;
    request->success = false;
    request->callbackRef = LUA_NOREF;
    request->luaVM = L;

    // Check if callback is provided (3rd argument)
    if (lua_isfunction(L, 3)) {
        DebugLog("Callback function provided, storing in registry");
        // Store the callback in registry
        lua_pushvalue(L, 3); // Push callback to top
        request->callbackRef = luaL_ref(L, LUA_REGISTRYINDEX);
    } else {
        DebugLog("No callback function provided");
    }

    // Add to queue
    screenshotQueue.push(request);
    DebugLog("Request queued successfully");

    lua_pushboolean(L, 1); // Return true (request queued)
    return 1;
}

// Lua function: takeScreenshotSync(outputPath, windowTitle, callback)
int lua_takeScreenshotSync(lua_State* L) {
    const char* outputPath = luaL_checkstring(L, 1);
    const char* windowTitle = luaL_optstring(L, 2, "MTA: San Andreas");

    // Create request for callback support
    shared_ptr<ScreenshotRequest> request = nullptr;
    if (lua_isfunction(L, 3)) {
        request = make_shared<ScreenshotRequest>();
        request->luaVM = L;
        lua_pushvalue(L, 3);
        request->callbackRef = luaL_ref(L, LUA_REGISTRYINDEX);
    }

    // Find window
    HWND hwnd = FindWindowByTitle(windowTitle);
    bool success = false;

    if (hwnd) {
        success = TakeWindowScreenshot(hwnd, outputPath, request);
    } else if (request && request->callbackRef != LUA_NOREF) {
        // Call callback with failure
        lua_rawgeti(L, LUA_REGISTRYINDEX, request->callbackRef);
        lua_pushboolean(L, false);
        lua_pushinteger(L, 0);
        lua_pushinteger(L, 0);
        lua_pcall(L, 3, 0, 0);
        luaL_unref(L, LUA_REGISTRYINDEX, request->callbackRef);
    }

    lua_pushboolean(L, success);
    return 1;
}

// MTA Module initialization - exact pattern from ml_pathfind
MTAEXPORT bool InitModule(ILuaModuleManager10* pManager, char* szModuleName, char* szAuthor, float* fVersion)
{
    DebugLog("==== InitModule called ====");

    pModuleManager = pManager;

    // Set module info
    strcpy(szModuleName, "Screenshot Module");
    strcpy(szAuthor, "Claude");
    *fVersion = 1.1f;

    DebugLog("Creating module instance...");
    // Create module instance (like ml_pathfind)
    g_Module = new ScreenshotModule();

    DebugLog("Initializing GDI+...");
    // Initialize GDI+
    GdiplusStartupInput gdiplusStartupInput;
    GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, nullptr);

    DebugLog("Starting worker thread...");
    // Start worker thread
    if (!workerThread) {
        workerThread = new thread(ScreenshotWorker);
    }

    DebugLog("==== InitModule completed successfully ====");
    return true;
}

// Register functions - exact pattern from ml_pathfind
MTAEXPORT void RegisterFunctions(lua_State* luaVM)
{
    DebugLog("==== RegisterFunctions called ====");

    if (!pModuleManager || !luaVM) {
        DebugLog("ERROR: pModuleManager or luaVM is NULL!");
        return;
    }

    // Add lua vm to states list (to check validity)
    g_Module->AddLuaVM(luaVM);

    // Register functions with the MTA module manager
    DebugLog("Registering takeAsyncScreenshot...");
    pModuleManager->RegisterFunction(luaVM, "takeAsyncScreenshot", lua_takeAsyncScreenshot);

    DebugLog("Registering takeScreenshotSync...");
    pModuleManager->RegisterFunction(luaVM, "takeScreenshotSync", lua_takeScreenshotSync);

    DebugLog("==== Functions registered successfully ====");
}

// Module lifecycle functions - from ml_pathfind pattern
MTAEXPORT bool DoPulse()
{
    return true;
}

MTAEXPORT bool ShutdownModule()
{
    // Cleanup
    screenshotQueue.stop();

    if (workerThread) {
        workerThread->join();
        delete workerThread;
        workerThread = nullptr;
    }

    GdiplusShutdown(gdiplusToken);

    // Clean up module instance
    if (g_Module) {
        delete g_Module;
        g_Module = nullptr;
    }

    return true;
}

MTAEXPORT bool ResourceStopping(lua_State* luaVM)
{
    if (g_Module && luaVM) {
        g_Module->RemoveLuaVM(luaVM);
    }
    return true;
}

// Module cleanup
extern "C" __declspec(dllexport) BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpvReserved) {
    if (fdwReason == DLL_PROCESS_ATTACH) {
        // MessageBoxA(NULL, "Screenshot Module DLL Loaded!", "Debug", MB_OK);
        FILE* f = fopen("screenshot_module_debug.log", "a");
        if (f) {
            fprintf(f, "[Screenshot Module] DLL loaded\n");
            fclose(f);
        }
    }
    else if (fdwReason == DLL_PROCESS_DETACH) {
        FILE* f = fopen("screenshot_module_debug.log", "a");
        if (f) {
            fprintf(f, "[Screenshot Module] DLL unloading\n");
            fclose(f);
        }
    }
    return TRUE;
}