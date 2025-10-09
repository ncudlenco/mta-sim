#include <windows.h>
// #include <gdiplus.h>
#include <thread>
#include <string>
#include <queue>
#include <mutex>
#include <condition_variable>
#include <iostream>
#include <vector>
#include <algorithm>

#include "ILuaModuleManager.h"

// #pragma comment(lib, "gdiplus.lib")

// using namespace Gdiplus;
using namespace std;

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

// Find window by title
HWND FindWindowByTitle(const string& title) {
    HWND hwnd = nullptr;

    EnumWindows([](HWND hwnd, LPARAM lParam) -> BOOL {
        string* targetTitle = reinterpret_cast<string*>(lParam);

        char windowText[256];
        GetWindowTextA(hwnd, windowText, sizeof(windowText));

        if (string(windowText).find(*targetTitle) != string::npos) {
            *reinterpret_cast<HWND*>(lParam) = hwnd;
            return FALSE; // Stop enumeration
        }

        return TRUE; // Continue enumeration
    }, reinterpret_cast<LPARAM>(&title));

    return hwnd;
}

// Take screenshot of specific window
bool TakeWindowScreenshot(HWND hwnd, const string& outputPath) {
    if (!hwnd || !IsWindow(hwnd)) return false;

    RECT rect;
    if (!GetWindowRect(hwnd, &rect)) return false;

    int width = rect.right - rect.left;
    int height = rect.bottom - rect.top;

    if (width <= 0 || height <= 0) return false;

    // Create device contexts
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

    // Copy window content to memory DC
    bool result = BitBlt(hdcMemory, 0, 0, width, height, hdcScreen, rect.left, rect.top, SRCCOPY);

    if (result) {
        // Convert to GDI+ Bitmap and save
        Bitmap bitmap(hBitmap, nullptr);

        // Get PNG encoder CLSID
        CLSID pngClsid;
        GetEncoderClsid(L"image/png", &pngClsid);

        // Convert path to wide string
        wstring wPath(outputPath.begin(), outputPath.end());

        // Save as PNG
        Status status = bitmap.Save(wPath.c_str(), &pngClsid, nullptr);
        result = (status == Ok);
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
    while (true) {
        auto request = screenshotQueue.pop();
        if (!request) break; // Thread shutdown

        // Find window by title
        HWND hwnd = FindWindowByTitle(request->windowTitle);

        if (hwnd) {
            // Take screenshot
            request->success = TakeWindowScreenshot(hwnd, request->outputPath);
        } else {
            request->success = false;
        }

        request->completed = true;
    }
}

// Lua function: takeAsyncScreenshot(outputPath, windowTitle)
int lua_takeAsyncScreenshot(lua_State* L) {
    const char* outputPath = luaL_checkstring(L, 1);
    const char* windowTitle = luaL_optstring(L, 2, "MTA: San Andreas");

    // Create screenshot request
    auto request = make_shared<ScreenshotRequest>();
    request->outputPath = outputPath;
    request->windowTitle = windowTitle;
    request->completed = false;
    request->success = false;

    // Add to queue
    screenshotQueue.push(request);

    lua_pushboolean(L, 1); // Return true (request queued)
    return 1;
}

// Lua function: takeScreenshotSync(outputPath, windowTitle)
int lua_takeScreenshotSync(lua_State* L) {
    const char* outputPath = luaL_checkstring(L, 1);
    const char* windowTitle = luaL_optstring(L, 2, "MTA: San Andreas");

    // Find window
    HWND hwnd = FindWindowByTitle(windowTitle);
    bool success = false;

    if (hwnd) {
        success = TakeWindowScreenshot(hwnd, outputPath);
    }

    lua_pushboolean(L, success);
    return 1;
}

// MTA Module initialization - exact pattern from ml_pathfind
MTAEXPORT bool InitModule(ILuaModuleManager10* pManager, char* szModuleName, char* szAuthor, float* fVersion)
{
    MessageBoxA(NULL, "InitModule called!", "Debug", MB_OK);
    
    pModuleManager = pManager;

    // Set module info
    strcpy(szModuleName, "Screenshot Module");
    strcpy(szAuthor, "Claude");
    *fVersion = 1.0f;

    // Create module instance (like ml_pathfind)
    g_Module = new ScreenshotModule();

    // Skip GDI+ and threading for now - test basic loading
    // GdiplusStartupInput gdiplusStartupInput;
    // GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, nullptr);

    // Start worker thread
    // if (!workerThread) {
    //     workerThread = new thread(ScreenshotWorker);
    // }

    return true;
}

// Register functions - exact pattern from ml_pathfind
MTAEXPORT void RegisterFunctions(lua_State* luaVM)
{
    MessageBoxA(NULL, "RegisterFunctions called!", "Debug", MB_OK);
    
    if (!pModuleManager || !luaVM)
        return;

    // Add lua vm to states list (to check validity)
    g_Module->AddLuaVM(luaVM);

    // Register functions with the MTA module manager
    pModuleManager->RegisterFunction(luaVM, "takeAsyncScreenshot", lua_takeAsyncScreenshot);
    pModuleManager->RegisterFunction(luaVM, "takeScreenshotSync", lua_takeScreenshotSync);
    
    MessageBoxA(NULL, "Functions registered!", "Debug", MB_OK);
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
        MessageBoxA(NULL, "Screenshot Module DLL Loaded!", "Debug", MB_OK);
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

        // Skip cleanup for now
        // screenshotQueue.stop();

        // if (workerThread) {
        //     workerThread->join();
        //     delete workerThread;
        //     workerThread = nullptr;
        // }

        // GdiplusShutdown(gdiplusToken);
    }
    return TRUE;
}