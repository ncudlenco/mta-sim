#include "DesktopDuplicationBackend.h"
#include "../core/FrameBuffer.h"
#include "../core/DebugLog.h"

DesktopDuplicationBackend::DesktopDuplicationBackend(const std::string& windowTitle,
                                                     int cropTop, int cropLeft, int cropRight, int cropBottom)
    : d3dDevice(nullptr)
    , d3dContext(nullptr)
    , deskDupl(nullptr)
    , initialized(false)
    , cropTop(cropTop)
    , cropLeft(cropLeft)
    , cropRight(cropRight)
    , cropBottom(cropBottom)
    , currentWidth(0)
    , currentHeight(0)
    , windowTitle(windowTitle)
    , cachedWindow(nullptr)
    , windowFound(false)
{
    DEBUG_LOG_FMT("DesktopDuplicationBackend", "Constructor: windowTitle=%s, crops(t=%d,l=%d,r=%d,b=%d)",
                  windowTitle.c_str(), cropTop, cropLeft, cropRight, cropBottom);
    memset(&windowRect, 0, sizeof(windowRect));
}

DesktopDuplicationBackend::~DesktopDuplicationBackend() {
    DEBUG_LOG("DesktopDuplicationBackend", "Destructor called");
    Cleanup();
}

bool DesktopDuplicationBackend::Initialize() {
    DEBUG_LOG("DesktopDuplicationBackend", "Initialize called");

    if (initialized) {
        DEBUG_LOG("DesktopDuplicationBackend", "Initialize: already initialized");
        return true;  // Already initialized
    }

    HRESULT hr;

    // 1. Create D3D11 device
    DEBUG_LOG("DesktopDuplicationBackend", "Creating D3D11 device...");
    D3D_FEATURE_LEVEL featureLevel;
    hr = D3D11CreateDevice(
        nullptr,                    // Adapter
        D3D_DRIVER_TYPE_HARDWARE,   // Driver type
        nullptr,                    // Software rasterizer
        0,                          // Flags
        nullptr,                    // Feature levels
        0,                          // Num feature levels
        D3D11_SDK_VERSION,          // SDK version
        &d3dDevice,                 // Device
        &featureLevel,              // Feature level
        &d3dContext                 // Device context
    );

    if (FAILED(hr)) {
        DEBUG_LOG_HR("DesktopDuplicationBackend", "D3D11CreateDevice", hr);
        return false;
    }

    DEBUG_LOG("DesktopDuplicationBackend", "D3D11 device created successfully");

    // 2. Get DXGI device
    DEBUG_LOG("DesktopDuplicationBackend", "Getting DXGI device...");
    IDXGIDevice* dxgiDevice = nullptr;
    hr = d3dDevice->QueryInterface(__uuidof(IDXGIDevice), (void**)&dxgiDevice);
    if (FAILED(hr)) {
        DEBUG_LOG_HR("DesktopDuplicationBackend", "QueryInterface (IDXGIDevice)", hr);
        Cleanup();
        return false;
    }

    // 3. Get DXGI adapter
    DEBUG_LOG("DesktopDuplicationBackend", "Getting DXGI adapter...");
    IDXGIAdapter* dxgiAdapter = nullptr;
    hr = dxgiDevice->GetAdapter(&dxgiAdapter);
    dxgiDevice->Release();
    if (FAILED(hr)) {
        DEBUG_LOG_HR("DesktopDuplicationBackend", "GetAdapter", hr);
        Cleanup();
        return false;
    }

    // 4. Get primary output
    DEBUG_LOG("DesktopDuplicationBackend", "Getting primary output...");
    IDXGIOutput* dxgiOutput = nullptr;
    hr = dxgiAdapter->EnumOutputs(0, &dxgiOutput);
    dxgiAdapter->Release();
    if (FAILED(hr)) {
        DEBUG_LOG_HR("DesktopDuplicationBackend", "EnumOutputs", hr);
        Cleanup();
        return false;
    }

    // 5. Get output1 interface (for Desktop Duplication)
    DEBUG_LOG("DesktopDuplicationBackend", "Getting IDXGIOutput1 interface...");
    IDXGIOutput1* dxgiOutput1 = nullptr;
    hr = dxgiOutput->QueryInterface(__uuidof(IDXGIOutput1), (void**)&dxgiOutput1);
    dxgiOutput->Release();
    if (FAILED(hr)) {
        DEBUG_LOG_HR("DesktopDuplicationBackend", "QueryInterface (IDXGIOutput1)", hr);
        Cleanup();
        return false;
    }

    // 6. Create Desktop Duplication API
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
    // This handles window resizing, moving, or switching between windowed/fullscreen
    if (windowFound || FindTargetWindow()) {
        if (!UpdateWindowBounds()) {
            DEBUG_LOG("DesktopDuplicationBackend", "CaptureFrame: WARNING - failed to update window bounds");
            // Continue with last known bounds rather than failing
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

    // Apply crops
    int width = (windowRect.right - windowRect.left) - cropLeft - cropRight;
    int height = (windowRect.bottom - windowRect.top) - cropTop - cropBottom;

    if (width <= 0 || height <= 0) {
        DEBUG_LOG_FMT("DesktopDuplicationBackend", "UpdateWindowBounds: invalid dimensions after cropping (%dx%d)", width, height);
        return false;
    }

    currentWidth = width;
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

    // Calculate crop box (window bounds + crops)
    int left = windowRect.left + cropLeft;
    int top = windowRect.top + cropTop;
    int right = windowRect.right - cropRight;
    int bottom = windowRect.bottom - cropBottom;

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
