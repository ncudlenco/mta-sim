#include "DesktopDuplicationBackend.h"
#include "../core/FrameBuffer.h"
#include "../core/DebugLog.h"

DesktopDuplicationBackend::DesktopDuplicationBackend(const std::string& windowTitle,
                                                     int viewportCropTop, int viewportCropLeft,
                                                     int viewportCropRight, int viewportCropBottom)
    : d3dDevice(nullptr)
    , d3dContext(nullptr)
    , deskDupl(nullptr)
    , initialized(false)
    , viewportCropTop(viewportCropTop)
    , viewportCropLeft(viewportCropLeft)
    , viewportCropRight(viewportCropRight)
    , viewportCropBottom(viewportCropBottom)
    , cropTop(viewportCropTop)
    , cropLeft(viewportCropLeft)
    , cropRight(viewportCropRight)
    , cropBottom(viewportCropBottom)
    , chromeTop(0)
    , chromeLeft(0)
    , chromeRight(0)
    , chromeBottom(0)
    , viewportWidth(0)
    , viewportHeight(0)
    , currentWidth(0)
    , currentHeight(0)
    , windowTitle(windowTitle)
    , cachedWindow(nullptr)
    , windowFound(false)
{
    DEBUG_LOG_FMT("DesktopDuplicationBackend",
                  "Constructor: windowTitle=%s, viewportCrops(t=%d,l=%d,r=%d,b=%d); OS chrome auto-detected at capture start",
                  windowTitle.c_str(), viewportCropTop, viewportCropLeft, viewportCropRight, viewportCropBottom);
    memset(&windowRect, 0, sizeof(windowRect));
    memset(&outputRect, 0, sizeof(outputRect));
}

DesktopDuplicationBackend::~DesktopDuplicationBackend() {
    DEBUG_LOG("DesktopDuplicationBackend", "Destructor called");
    Cleanup();
}

bool DesktopDuplicationBackend::Initialize() {
    DEBUG_LOG("DesktopDuplicationBackend", "Initialize called");

    if (initialized) {
        DEBUG_LOG("DesktopDuplicationBackend", "Initialize: already initialized");
        return true;
    }

    HRESULT hr;

    // 1. Create DXGI Factory to enumerate all adapters (GPUs)
    DEBUG_LOG("DesktopDuplicationBackend", "Creating DXGI Factory...");
    IDXGIFactory1* dxgiFactory = nullptr;
    hr = CreateDXGIFactory1(__uuidof(IDXGIFactory1), (void**)&dxgiFactory);
    if (FAILED(hr)) {
        DEBUG_LOG_HR("DesktopDuplicationBackend", "CreateDXGIFactory1", hr);
        return false;
    }

    // 2. Find the adapter+output that contains the target window
    IDXGIAdapter* matchedAdapter = nullptr;
    IDXGIOutput* matchedOutput = nullptr;

    FindTargetWindow();
    RECT targetRect = {0};
    bool haveWindowRect = false;
    if (cachedWindow) {
        haveWindowRect = (GetWindowRect(cachedWindow, &targetRect) != 0);
    }

    if (haveWindowRect) {
        int centerX = (targetRect.left + targetRect.right) / 2;
        int centerY = (targetRect.top + targetRect.bottom) / 2;
        DEBUG_LOG_FMT("DesktopDuplicationBackend", "Window center: (%d, %d)", centerX, centerY);

        IDXGIAdapter* adapter = nullptr;
        for (UINT ai = 0; dxgiFactory->EnumAdapters(ai, &adapter) != DXGI_ERROR_NOT_FOUND; ai++) {
            DXGI_ADAPTER_DESC adapterDesc;
            adapter->GetDesc(&adapterDesc);
            DEBUG_LOG_FMT("DesktopDuplicationBackend", "Adapter %u: %ls (VRAM=%lluMB)",
                ai, adapterDesc.Description, adapterDesc.DedicatedVideoMemory / (1024*1024));

            IDXGIOutput* output = nullptr;
            for (UINT oi = 0; adapter->EnumOutputs(oi, &output) != DXGI_ERROR_NOT_FOUND; oi++) {
                DXGI_OUTPUT_DESC desc;
                output->GetDesc(&desc);
                RECT r = desc.DesktopCoordinates;
                DEBUG_LOG_FMT("DesktopDuplicationBackend", "  Output %u: (%d,%d)-(%d,%d) [%ls]",
                    oi, r.left, r.top, r.right, r.bottom, desc.DeviceName);

                if (centerX >= r.left && centerX < r.right &&
                    centerY >= r.top && centerY < r.bottom) {
                    matchedAdapter = adapter;
                    matchedOutput = output;
                    outputRect = r;
                    DEBUG_LOG_FMT("DesktopDuplicationBackend", "Matched window to adapter %u output %u", ai, oi);
                    break;
                }
                output->Release();
            }
            if (matchedAdapter) break;
            adapter->Release();
        }
    }

    // Fall back to default adapter, output 0
    if (!matchedAdapter) {
        DEBUG_LOG("DesktopDuplicationBackend", "No adapter match, falling back to adapter 0 output 0");
        hr = dxgiFactory->EnumAdapters(0, &matchedAdapter);
        if (SUCCEEDED(hr)) {
            hr = matchedAdapter->EnumOutputs(0, &matchedOutput);
            if (SUCCEEDED(hr)) {
                DXGI_OUTPUT_DESC desc;
                matchedOutput->GetDesc(&desc);
                outputRect = desc.DesktopCoordinates;
            }
        }
    }

    dxgiFactory->Release();

    if (!matchedAdapter || !matchedOutput) {
        DEBUG_LOG("DesktopDuplicationBackend", "Failed to find any adapter/output");
        if (matchedAdapter) matchedAdapter->Release();
        if (matchedOutput) matchedOutput->Release();
        return false;
    }

    // 3. Create D3D11 device on the matched adapter
    DEBUG_LOG("DesktopDuplicationBackend", "Creating D3D11 device on matched adapter...");
    D3D_FEATURE_LEVEL featureLevel;
    hr = D3D11CreateDevice(
        matchedAdapter,             // Specific adapter for this output
        D3D_DRIVER_TYPE_UNKNOWN,    // Must be UNKNOWN when adapter is specified
        nullptr,                    // Software rasterizer
        0,                          // Flags
        nullptr,                    // Feature levels
        0,                          // Num feature levels
        D3D11_SDK_VERSION,          // SDK version
        &d3dDevice,                 // Device
        &featureLevel,              // Feature level
        &d3dContext                 // Device context
    );

    matchedAdapter->Release();

    if (FAILED(hr)) {
        DEBUG_LOG_HR("DesktopDuplicationBackend", "D3D11CreateDevice", hr);
        matchedOutput->Release();
        return false;
    }

    DEBUG_LOG("DesktopDuplicationBackend", "D3D11 device created on matched adapter");

    // 4. Get output1 interface (for Desktop Duplication)
    DEBUG_LOG("DesktopDuplicationBackend", "Getting IDXGIOutput1 interface...");
    IDXGIOutput1* dxgiOutput1 = nullptr;
    hr = matchedOutput->QueryInterface(__uuidof(IDXGIOutput1), (void**)&dxgiOutput1);
    matchedOutput->Release();
    if (FAILED(hr)) {
        DEBUG_LOG_HR("DesktopDuplicationBackend", "QueryInterface (IDXGIOutput1)", hr);
        Cleanup();
        return false;
    }

    // 5. Create Desktop Duplication API
    DEBUG_LOG("DesktopDuplicationBackend", "Creating Desktop Duplication...");
    hr = dxgiOutput1->DuplicateOutput(d3dDevice, &deskDupl);
    dxgiOutput1->Release();
    if (FAILED(hr)) {
        DEBUG_LOG_HR("DesktopDuplicationBackend", "DuplicateOutput", hr);
        Cleanup();
        return false;
    }

    DEBUG_LOG("DesktopDuplicationBackend", "Desktop Duplication created");

    // 7. Get screen dimensions
    DXGI_OUTDUPL_DESC desc;
    deskDupl->GetDesc(&desc);

    DEBUG_LOG_FMT("DesktopDuplicationBackend", "Initialize: Desktop Duplication ready, screen dims=%dx%d, format=%u",
        desc.ModeDesc.Width, desc.ModeDesc.Height, desc.ModeDesc.Format);

    // 8. Find target window and cache bounds
    if (!FindTargetWindow()) {
        DEBUG_LOG("DesktopDuplicationBackend", "Initialize: WARNING - target window not found, using full desktop");
        currentWidth = desc.ModeDesc.Width - cropLeft - cropRight;
        currentHeight = desc.ModeDesc.Height - cropTop - cropBottom;
        windowFound = false;
    } else {
        if (!UpdateWindowBounds()) {
            DEBUG_LOG("DesktopDuplicationBackend", "Initialize: WARNING - failed to get window bounds, using full desktop");
            currentWidth = desc.ModeDesc.Width - cropLeft - cropRight;
            currentHeight = desc.ModeDesc.Height - cropTop - cropBottom;
            windowFound = false;
        } else {
            DEBUG_LOG_FMT("DesktopDuplicationBackend", "Initialize: window bounds cached (%dx%d at %d,%d)",
                currentWidth, currentHeight, windowRect.left, windowRect.top);
            windowFound = true;
        }
    }

    DEBUG_LOG_FMT("DesktopDuplicationBackend", "Initialize: success, target dims=%dx%d",
        currentWidth, currentHeight);

    initialized = true;
    return true;
}

void DesktopDuplicationBackend::Cleanup() {
    DEBUG_LOG("DesktopDuplicationBackend", "Cleanup called");

    if (deskDupl) {
        deskDupl->Release();
        deskDupl = nullptr;
        DEBUG_LOG("DesktopDuplicationBackend", "Desktop Duplication released");
    }

    if (d3dContext) {
        d3dContext->Release();
        d3dContext = nullptr;
        DEBUG_LOG("DesktopDuplicationBackend", "D3D context released");
    }

    if (d3dDevice) {
        d3dDevice->Release();
        d3dDevice = nullptr;
        DEBUG_LOG("DesktopDuplicationBackend", "D3D device released");
    }

    initialized = false;
    DEBUG_LOG("DesktopDuplicationBackend", "Cleanup complete");
}

ID3D11Texture2D* DesktopDuplicationBackend::CaptureFrame() {
    if (!initialized || !deskDupl) {
        DEBUG_LOG("DesktopDuplicationBackend", "CaptureFrame: not initialized");
        return nullptr;
    }

    // Update window bounds on every capture (worker thread)
    // This handles window resizing, moving, or late window appearance
    if (!windowFound) {
        if (FindTargetWindow()) {
            windowFound = true;
            DEBUG_LOG("DesktopDuplicationBackend", "CaptureFrame: window found (late detection)");
        }
    }
    if (windowFound) {
        if (!UpdateWindowBounds()) {
            DEBUG_LOG("DesktopDuplicationBackend", "CaptureFrame: WARNING - failed to update window bounds");
        }
    }

    // Acquire next frame
    IDXGIResource* desktopResource = nullptr;
    DXGI_OUTDUPL_FRAME_INFO frameInfo;
    HRESULT hr = deskDupl->AcquireNextFrame(500, &frameInfo, &desktopResource);

    if (FAILED(hr)) {
        // Timeout or access lost - try to recover
        if (hr == DXGI_ERROR_ACCESS_LOST) {
            DEBUG_LOG("DesktopDuplicationBackend", "CaptureFrame: access lost, reinitializing...");
            Cleanup();
            Initialize();
        } else if (hr != DXGI_ERROR_WAIT_TIMEOUT) {
            DEBUG_LOG_HR("DesktopDuplicationBackend", "AcquireNextFrame", hr);
        }
        return nullptr;
    }

    DEBUG_LOG_FMT("DesktopDuplicationBackend", "CaptureFrame: acquired, AccumulatedFrames=%u, LastPresentTime=%lld",
        frameInfo.AccumulatedFrames, frameInfo.LastPresentTime.QuadPart);

    // Warn if no new frames were presented since last acquire (stale frame)
    if (frameInfo.AccumulatedFrames == 0) {
        DEBUG_LOG("DesktopDuplicationBackend", "WARNING: AccumulatedFrames=0 - capturing STALE frame! GPU may not have presented new frame yet.");
    }

    // Get texture from resource
    ID3D11Texture2D* acquiredTexture = nullptr;
    hr = desktopResource->QueryInterface(__uuidof(ID3D11Texture2D), (void**)&acquiredTexture);
    desktopResource->Release();

    if (FAILED(hr)) {
        DEBUG_LOG_HR("DesktopDuplicationBackend", "QueryInterface (ID3D11Texture2D)", hr);
        deskDupl->ReleaseFrame();
        return nullptr;
    }

    // Crop to window bounds (GPU operation, fast)
    DEBUG_LOG("DesktopDuplicationBackend", "CaptureFrame: cropping to window bounds...");
    ID3D11Texture2D* croppedTexture = CreateWindowCroppedTexture(acquiredTexture);
    acquiredTexture->Release();

    if (!croppedTexture) {
        DEBUG_LOG("DesktopDuplicationBackend", "CaptureFrame: window crop failed");
        deskDupl->ReleaseFrame();
        return nullptr;
    }

    DEBUG_LOG("DesktopDuplicationBackend", "CaptureFrame: window crop success");
    return croppedTexture;
}

void DesktopDuplicationBackend::ReleaseFrame() {
    if (deskDupl) {
        deskDupl->ReleaseFrame();
        DEBUG_LOG("DesktopDuplicationBackend", "ReleaseFrame: frame released");
    }
}

ID3D11Texture2D* DesktopDuplicationBackend::CreateCroppedTexture(ID3D11Texture2D* source) {
    ID3D11Texture2D* cropped = nullptr;

    if (FrameBuffer::CreateCroppedTexture(d3dDevice, d3dContext, source, cropTop, &cropped)) {
        return cropped;
    }

    return nullptr;
}

// Helper function for window enumeration
struct WindowSearchData {
    const std::string* targetTitle;
    HWND foundWindow;
};

static BOOL CALLBACK EnumWindowsProc(HWND hwnd, LPARAM lParam) {
    WindowSearchData* data = reinterpret_cast<WindowSearchData*>(lParam);

    char windowText[256];
    GetWindowTextA(hwnd, windowText, sizeof(windowText));

    if (std::string(windowText).find(*data->targetTitle) != std::string::npos) {
        data->foundWindow = hwnd;
        return FALSE; // Stop enumeration
    }

    return TRUE; // Continue enumeration
}

bool DesktopDuplicationBackend::FindTargetWindow() {
    WindowSearchData searchData;
    searchData.targetTitle = &windowTitle;
    searchData.foundWindow = nullptr;

    EnumWindows(EnumWindowsProc, reinterpret_cast<LPARAM>(&searchData));

    if (searchData.foundWindow) {
        cachedWindow = searchData.foundWindow;
        DEBUG_LOG_FMT("DesktopDuplicationBackend", "FindTargetWindow: found window with title containing '%s'", windowTitle.c_str());
        return true;
    }

    DEBUG_LOG_FMT("DesktopDuplicationBackend", "FindTargetWindow: no window found with title containing '%s'", windowTitle.c_str());
    return false;
}

bool DesktopDuplicationBackend::UpdateWindowBounds() {
    if (!cachedWindow) {
        return false;
    }

    if (!GetWindowRect(cachedWindow, &windowRect)) {
        DEBUG_LOG("DesktopDuplicationBackend", "UpdateWindowBounds: GetWindowRect failed");
        return false;
    }

    // Detect OS chrome (title bar + borders) dynamically. GetClientRect gives
    // the viewport dimensions; mapping the client-area top-left to screen
    // coords tells us where the viewport lives inside the window rect.
    RECT clientRect;
    if (!GetClientRect(cachedWindow, &clientRect)) {
        DEBUG_LOG("DesktopDuplicationBackend", "UpdateWindowBounds: GetClientRect failed");
        return false;
    }
    POINT clientTopLeft = {0, 0};
    if (!ClientToScreen(cachedWindow, &clientTopLeft)) {
        DEBUG_LOG("DesktopDuplicationBackend", "UpdateWindowBounds: ClientToScreen failed");
        return false;
    }

    viewportWidth  = clientRect.right  - clientRect.left;
    viewportHeight = clientRect.bottom - clientRect.top;

    chromeLeft   = clientTopLeft.x - windowRect.left;
    chromeTop    = clientTopLeft.y - windowRect.top;
    chromeRight  = (windowRect.right  - windowRect.left) - viewportWidth  - chromeLeft;
    chromeBottom = (windowRect.bottom - windowRect.top)  - viewportHeight - chromeTop;

    // Effective window-space crop = OS chrome + viewport-side crop.
    cropLeft   = chromeLeft   + viewportCropLeft;
    cropTop    = chromeTop    + viewportCropTop;
    cropRight  = chromeRight  + viewportCropRight;
    cropBottom = chromeBottom + viewportCropBottom;

    int width  = (windowRect.right  - windowRect.left) - cropLeft - cropRight;
    int height = (windowRect.bottom - windowRect.top)  - cropTop  - cropBottom;

    if (width <= 0 || height <= 0) {
        DEBUG_LOG_FMT("DesktopDuplicationBackend",
                      "UpdateWindowBounds: invalid dimensions after cropping (%dx%d); viewport=%dx%d, chrome=(l=%d,t=%d,r=%d,b=%d)",
                      width, height, viewportWidth, viewportHeight,
                      chromeLeft, chromeTop, chromeRight, chromeBottom);
        return false;
    }

    currentWidth  = width;
    currentHeight = height;

    return true;
}

ID3D11Texture2D* DesktopDuplicationBackend::CreateWindowCroppedTexture(ID3D11Texture2D* source) {
    if (!windowFound) {
        // No window found - crop from edges only
        return CreateCroppedTexture(source);
    }

    // Get source texture dimensions
    D3D11_TEXTURE2D_DESC sourceDesc;
    source->GetDesc(&sourceDesc);

    // Calculate crop box relative to the duplicated output's origin
    // Window coordinates are absolute (virtual desktop), but the texture
    // only covers the matched output, so subtract the output origin.
    int left = (windowRect.left - outputRect.left) + cropLeft;
    int top = (windowRect.top - outputRect.top) + cropTop;
    int right = (windowRect.right - outputRect.left) - cropRight;
    int bottom = (windowRect.bottom - outputRect.top) - cropBottom;

    // Bounds check
    if (left < 0) left = 0;
    if (top < 0) top = 0;
    if (right > (int)sourceDesc.Width) right = sourceDesc.Width;
    if (bottom > (int)sourceDesc.Height) bottom = sourceDesc.Height;

    int width = right - left;
    int height = bottom - top;

    if (width <= 0 || height <= 0) {
        DEBUG_LOG_FMT("DesktopDuplicationBackend", "CreateWindowCroppedTexture: invalid crop dimensions (%dx%d)", width, height);
        return nullptr;
    }

    // Create cropped texture
    D3D11_TEXTURE2D_DESC croppedDesc = sourceDesc;
    croppedDesc.Width = width;
    croppedDesc.Height = height;
    croppedDesc.MipLevels = 1;
    croppedDesc.ArraySize = 1;
    croppedDesc.Usage = D3D11_USAGE_DEFAULT;
    croppedDesc.BindFlags = 0;
    croppedDesc.CPUAccessFlags = 0;

    ID3D11Texture2D* croppedTexture = nullptr;
    HRESULT hr = d3dDevice->CreateTexture2D(&croppedDesc, nullptr, &croppedTexture);
    if (FAILED(hr)) {
        DEBUG_LOG_HR("DesktopDuplicationBackend", "CreateTexture2D (cropped)", hr);
        return nullptr;
    }

    // Copy cropped region
    D3D11_BOX box;
    box.left = left;
    box.top = top;
    box.front = 0;
    box.right = right;
    box.bottom = bottom;
    box.back = 1;

    d3dContext->CopySubresourceRegion(croppedTexture, 0, 0, 0, 0, source, 0, &box);

    return croppedTexture;
}

void DesktopDuplicationBackend::GetDimensions(int& width, int& height) const {
    width = currentWidth;
    height = currentHeight;
}

void DesktopDuplicationBackend::GetViewportSize(int& width, int& height) const {
    width = viewportWidth;
    height = viewportHeight;
}

void DesktopDuplicationBackend::GetCropInViewport(int& left, int& top, int& right, int& bottom) const {
    left = viewportCropLeft;
    top = viewportCropTop;
    right = viewportCropRight;
    bottom = viewportCropBottom;
}

void DesktopDuplicationBackend::GetChrome(int& left, int& top, int& right, int& bottom) const {
    left = chromeLeft;
    top = chromeTop;
    right = chromeRight;
    bottom = chromeBottom;
}

void DesktopDuplicationBackend::GetVisibleRect(int& x, int& y, int& width, int& height) const {
    x = viewportCropLeft;
    y = viewportCropTop;
    width = viewportWidth - viewportCropLeft - viewportCropRight;
    height = viewportHeight - viewportCropTop - viewportCropBottom;
}
