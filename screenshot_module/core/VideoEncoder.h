#pragma once

#include <string>
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <d3d11.h>
#include <d3d11_1.h>  // For ID3D11VideoDevice, ID3D11VideoContext, ID3D11VideoProcessor

/// VideoEncoder: Encodes frames to H.264 video using Media Foundation
/// Core reusable component (game-agnostic)
class VideoEncoder {
private:
    IMFSinkWriter* sinkWriter;
    DWORD streamIndex;
    LONGLONG frameCount;
    int fps;
    int width;
    int height;
    int bitrate;
    bool initialized;

    // Video processor for GPU-accelerated scaling
    ID3D11VideoDevice* videoDevice;
    ID3D11VideoContext* videoContext;
    ID3D11VideoProcessor* videoProcessor;
    ID3D11VideoProcessorEnumerator* videoProcessorEnum;

public:
    VideoEncoder();
    ~VideoEncoder();

    /// Start video recording session
    /// @param path Output MP4 file path
    /// @param w Frame width
    /// @param h Frame height
    /// @param fps Frames per second
    /// @param bitrate Video bitrate in bps
    /// @return Success
    bool Start(const std::string& path, int w, int h, int fps, int bitrate);

    /// Add frame from GPU texture (Desktop Duplication path)
    /// @param gpuTexture D3D11 texture containing frame data
    /// @return Success
    bool AddFrame(ID3D11Texture2D* gpuTexture);

    /// Add frame from CPU pixel buffer (BitBlt path - future fallback)
    /// @param pixels Pixel data buffer
    /// @param w Frame width
    /// @param h Frame height
    /// @param pitch Row pitch in bytes
    /// @param format Pixel format GUID
    /// @return Success
    bool AddFrame(void* pixels, int w, int h, int pitch, GUID format);

    /// Stop recording and finalize MP4 file
    /// @return Success
    bool Stop();

private:
    bool InitializeMediaFoundation();
    bool CreateSinkWriter(const std::string& path);
    bool ConfigureVideoStream();
    IMFSample* CreateSampleFromTexture(ID3D11Texture2D* texture);
    IMFSample* CreateSampleFromPixels(void* pixels, int w, int h, int pitch, GUID format);

    /// Resize texture to target dimensions using D3D11
    /// @param source Source texture
    /// @param targetWidth Target width
    /// @param targetHeight Target height
    /// @return Resized texture (caller must release), or nullptr on failure
    ID3D11Texture2D* ResizeTexture(ID3D11Texture2D* source, int targetWidth, int targetHeight);

    /// Initialize GPU video processor for hardware-accelerated scaling
    /// @return Success
    bool InitializeVideoProcessor();

    /// Cleanup video processor resources
    void CleanupVideoProcessor();
};
