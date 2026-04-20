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

    // Viewport-side crop constants (configured at construction).
    // These are pixels to strip from the *client area* (viewport), independent
    // of OS chrome. Used for MTA-specific overlays like the watermark.
    int viewportCropTop;
    int viewportCropLeft;
    int viewportCropRight;
    int viewportCropBottom;

    // Effective window-side crop (viewport crop + auto-detected OS chrome).
    // Recomputed on every UpdateWindowBounds(); used by the DXGI subregion copy.
    int cropTop;
    int cropLeft;
    int cropRight;
    int cropBottom;

    // Detected OS chrome offsets in window-space, from GetClientRect +
    // ClientToScreen. Vary with Windows theme and DPI.
    int chromeTop;
    int chromeLeft;
    int chromeRight;
    int chromeBottom;

    // Viewport (client area) dims, from GetClientRect.
    int viewportWidth;
    int viewportHeight;

    // Post-crop output dims (what the resize/encoder receives).
    int currentWidth;
    int currentHeight;

    // Window tracking for accurate capture
    std::string windowTitle;
    HWND cachedWindow;
    RECT windowRect;  // Cached window rectangle
    bool windowFound;

    // Monitor tracking for correct DXGI output
    RECT outputRect;  // Desktop coordinates of the duplicated output

public:
    /// Constructor
    /// @param windowTitle Title of window to capture (e.g., "MTA: San Andreas")
    /// @param viewportCropTop Pixels to crop from top of the *viewport* (inside client area)
    /// @param viewportCropLeft Pixels to crop from left edge of viewport
    /// @param viewportCropRight Pixels to crop from right edge of viewport
    /// @param viewportCropBottom Pixels to crop from bottom of viewport (e.g. MTA watermark)
    ///
    /// OS chrome (title bar, borders) is auto-detected at runtime via
    /// GetClientRect / ClientToScreen and added to these constants to form
    /// the effective window-space crop.
    DesktopDuplicationBackend(const std::string& windowTitle = "MTA: San Andreas",
                             int viewportCropTop = 0, int viewportCropLeft = 0,
                             int viewportCropRight = 0, int viewportCropBottom = 0);
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

    /// Get frame dimensions (width and height)
    /// @param width Output: frame width
    /// @param height Output: frame height
    void GetDimensions(int& width, int& height) const;

    /// Check if initialized
    bool IsInitialized() const { return initialized; }

    /// Set window title to track
    void SetWindowTitle(const std::string& title);

    /// Get viewport (client area) size of the tracked window.
    /// @param width Output: viewport width in pixels
    /// @param height Output: viewport height in pixels
    void GetViewportSize(int& width, int& height) const;

    /// Get the viewport-side crop (pixels removed from each edge of the
    /// viewport — MTA watermark / overlays). Does not include OS chrome.
    void GetCropInViewport(int& left, int& top, int& right, int& bottom) const;

    /// Get the detected OS chrome (title bar, borders) offsets in
    /// window-space. Useful for debugging / diagnostics.
    void GetChrome(int& left, int& top, int& right, int& bottom) const;

    /// Get the rectangle in viewport coords that survives the crop
    /// (= what ends up in the saved image, pre-resize).
    void GetVisibleRect(int& x, int& y, int& width, int& height) const;

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
