#pragma once

#include <d3d11.h>
#include <string>

/// FrameBuffer utilities: Texture operations and pixel format conversions
/// Core reusable component (game-agnostic)
namespace FrameBuffer {
    /// Create cropped texture (remove top rows)
    /// @param device D3D11 device
    /// @param context D3D11 device context
    /// @param sourceTexture Source texture to crop
    /// @param cropTop Number of pixels to remove from top
    /// @param outTexture Output cropped texture (caller must release)
    /// @return Success
    bool CreateCroppedTexture(
        ID3D11Device* device,
        ID3D11DeviceContext* context,
        ID3D11Texture2D* sourceTexture,
        int cropTop,
        ID3D11Texture2D** outTexture
    );

    /// Create staging texture for CPU readback
    /// @param device D3D11 device
    /// @param sourceTexture Source texture to match dimensions/format
    /// @param outStagingTexture Output staging texture (caller must release)
    /// @return Success
    bool CreateStagingTexture(
        ID3D11Device* device,
        ID3D11Texture2D* sourceTexture,
        ID3D11Texture2D** outStagingTexture
    );

    /// Map texture to CPU memory
    /// @param context D3D11 device context
    /// @param stagingTexture Staging texture to map
    /// @param outMappedResource Output mapped resource
    /// @return Success
    bool MapTexture(
        ID3D11DeviceContext* context,
        ID3D11Texture2D* stagingTexture,
        D3D11_MAPPED_SUBRESOURCE& outMappedResource
    );

    /// Unmap texture
    /// @param context D3D11 device context
    /// @param stagingTexture Staging texture to unmap
    void UnmapTexture(
        ID3D11DeviceContext* context,
        ID3D11Texture2D* stagingTexture
    );
}
