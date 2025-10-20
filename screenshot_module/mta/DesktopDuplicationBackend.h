#pragma once

#include <d3d11.h>
#include <dxgi1_2.h>
#include <windows.h>
#include <string>

/// DesktopDuplicationBackend: DXGI Desktop Duplication wrapper
/// MTA-specific component (uses Desktop Duplication for screen capture)
class DesktopDuplicationBackend {
private:
    ID3D11Device* d3dDevice;
    ID3D11DeviceContext* d3dContext;
    IDXGIOutputDuplication* deskDupl;
    bool initialized;
    int cropTop;
    int cropLeft;
    int cropRight;
    int cropBottom;
    int currentWidth;
    int currentHeight;

    // Window tracking for accurate capture
    std::string windowTitle;
    HWND cachedWindow;
    RECT windowRect;  // Cached window rectangle
    bool windowFound;

public:
    /// Constructor
    /// @param windowTitle Title of window to capture (e.g., "MTA: San Andreas")
    /// @param cropTop Pixels to crop from top of window
    /// @param cropLeft Pixels to crop from left edge
    /// @param cropRight Pixels to crop from right edge
    /// @param cropBottom Pixels to crop from bottom edge
    DesktopDuplicationBackend(const std::string& windowTitle = "MTA: San Andreas",
                             int cropTop = 0, int cropLeft = 0, int cropRight = 0, int cropBottom = 0);
    ~DesktopDuplicationBackend();

    /// Initialize Desktop Duplication
    /// @return Success
    bool Initialize();

    /// Cleanup resources
    void Cleanup();

    /// Capture next frame (crops to window bounds)
    /// @return Cropped texture (caller must release), or nullptr on failure
    ID3D11Texture2D* CaptureFrame();

    /// Release frame (must be called after CaptureFrame)
    void ReleaseFrame();

    /// Get frame width (window width after cropping)
    int GetWidth() const { return currentWidth; }

    /// Get frame height (after cropping)
    int GetHeight() const { return currentHeight; }

    /// Check if initialized
    bool IsInitialized() const { return initialized; }

    /// Set window title to track
    void SetWindowTitle(const std::string& title);

private:
    /// Find and cache the target window handle
    /// @return Success
    bool FindTargetWindow();

    /// Update window bounds from cached handle
    /// @return Success (false if window no longer valid)
    bool UpdateWindowBounds();

    /// Create texture cropped to window bounds
    /// @param source Source desktop texture
    /// @return Cropped texture (caller must release), or nullptr on failure
    ID3D11Texture2D* CreateWindowCroppedTexture(ID3D11Texture2D* source);

    /// Legacy: Create texture with simple top crop
    ID3D11Texture2D* CreateCroppedTexture(ID3D11Texture2D* source);
};
