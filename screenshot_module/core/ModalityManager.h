#pragma once

#include <map>
#include <mutex>
#include <string>
#include <d3d11.h>
#include "VideoEncoder.h"

/// ModalityManager: Manages multiple video encoders (one per modality)
/// Core reusable component (game-agnostic)
class ModalityManager {
private:
    std::map<int, VideoEncoder*> encoders;
    mutable std::mutex encoderMutex;

public:
    ModalityManager();
    ~ModalityManager();

    /// Start video recording for a specific modality
    /// @param modalityId Unique modality identifier (0=raw, 1=seg, 2=depth, etc.)
    /// @param path Output MP4 file path
    /// @param w Frame width
    /// @param h Frame height
    /// @param fps Frames per second
    /// @param bitrate Video bitrate in bps
    /// @return Success
    bool StartRecording(int modalityId, const std::string& path, int w, int h, int fps, int bitrate);

    /// Add frame to specific modality encoder (GPU texture)
    /// @param modalityId Modality identifier
    /// @param texture D3D11 texture containing frame data
    /// @return Success
    bool AddFrame(int modalityId, ID3D11Texture2D* texture);

    /// Add frame to specific modality encoder (CPU pixels)
    /// @param modalityId Modality identifier
    /// @param pixels Pixel data buffer
    /// @param w Frame width
    /// @param h Frame height
    /// @param pitch Row pitch in bytes
    /// @param format Pixel format GUID
    /// @return Success
    bool AddFrame(int modalityId, void* pixels, int w, int h, int pitch, GUID format);

    /// Stop recording for specific modality
    /// @param modalityId Modality identifier
    /// @return Success
    bool StopRecording(int modalityId);

    /// Check if recording for specific modality
    /// @param modalityId Modality identifier
    /// @return True if recording
    bool IsRecording(int modalityId) const;

    /// Get target dimensions for a modality
    /// @param modalityId Modality identifier
    /// @param outWidth Output: target width (0 if not recording)
    /// @param outHeight Output: target height (0 if not recording)
    /// @return True if modality exists
    bool GetTargetDimensions(int modalityId, int& outWidth, int& outHeight) const;

    /// Snapshot of every recording modality's target dimensions.
    /// @return Copy of the internal modalityId -> (width, height) map.
    std::map<int, std::pair<int, int>> GetAllTargetDimensions() const;

    /// Stop all recordings
    void StopAll();

private:
    // Store target dimensions per modality
    std::map<int, std::pair<int, int>> targetDimensions;  // modalityId -> (width, height)
};
