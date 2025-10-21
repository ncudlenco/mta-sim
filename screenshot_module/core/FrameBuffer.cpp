#include "FrameBuffer.h"
#include "DebugLog.h"

namespace FrameBuffer {

bool CreateCroppedTexture(
    ID3D11Device* device,
    ID3D11DeviceContext* context,
    ID3D11Texture2D* sourceTexture,
    int cropTop,
    ID3D11Texture2D** outTexture
) {
    DEBUG_LOG_FMT("FrameBuffer", "CreateCroppedTexture: cropTop=%d", cropTop);

    if (!device || !context || !sourceTexture || !outTexture) {
        DEBUG_LOG("FrameBuffer", "CreateCroppedTexture: null parameter");
        return false;
    }

    // Get source texture description
    D3D11_TEXTURE2D_DESC srcDesc;
    sourceTexture->GetDesc(&srcDesc);

    DEBUG_LOG_FMT("FrameBuffer", "CreateCroppedTexture: source dims=%dx%d", srcDesc.Width, srcDesc.Height);

    // Calculate cropped dimensions
    int croppedHeight = srcDesc.Height - cropTop;
    if (croppedHeight <= 0) {
        DEBUG_LOG_FMT("FrameBuffer", "CreateCroppedTexture: invalid cropped height=%d", croppedHeight);
        return false;
    }

    // Create cropped texture description
    D3D11_TEXTURE2D_DESC croppedDesc = srcDesc;
    croppedDesc.Height = croppedHeight;
    croppedDesc.BindFlags = 0;
    croppedDesc.MiscFlags = 0;
    croppedDesc.Usage = D3D11_USAGE_DEFAULT;
    croppedDesc.CPUAccessFlags = 0;

    // Create cropped texture
    HRESULT hr = device->CreateTexture2D(&croppedDesc, nullptr, outTexture);
    if (FAILED(hr)) {
        DEBUG_LOG_HR("FrameBuffer", "CreateTexture2D", hr);
        return false;
    }

    // Copy region (skip top rows)
    D3D11_BOX srcBox;
    srcBox.left = 0;
    srcBox.right = srcDesc.Width;
    srcBox.top = cropTop;
    srcBox.bottom = srcDesc.Height;
    srcBox.front = 0;
    srcBox.back = 1;

    context->CopySubresourceRegion(
        *outTexture,
        0,          // Dest subresource
        0, 0, 0,    // Dest x, y, z
        sourceTexture,
        0,          // Source subresource
        &srcBox     // Source box
    );

    DEBUG_LOG_FMT("FrameBuffer", "CreateCroppedTexture: success, cropped dims=%dx%d", srcDesc.Width, croppedHeight);
    return true;
}

bool CreateStagingTexture(
    ID3D11Device* device,
    ID3D11Texture2D* sourceTexture,
    ID3D11Texture2D** outStagingTexture
) {
    DEBUG_LOG("FrameBuffer", "CreateStagingTexture called");

    if (!device || !sourceTexture || !outStagingTexture) {
        DEBUG_LOG("FrameBuffer", "CreateStagingTexture: null parameter");
        return false;
    }

    // Get source texture description
    D3D11_TEXTURE2D_DESC srcDesc;
    sourceTexture->GetDesc(&srcDesc);

    DEBUG_LOG_FMT("FrameBuffer", "CreateStagingTexture: source dims=%dx%d", srcDesc.Width, srcDesc.Height);

    // Create staging texture description
    D3D11_TEXTURE2D_DESC stagingDesc = srcDesc;
    stagingDesc.Usage = D3D11_USAGE_STAGING;
    stagingDesc.BindFlags = 0;
    stagingDesc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
    stagingDesc.MiscFlags = 0;

    // Create staging texture
    HRESULT hr = device->CreateTexture2D(&stagingDesc, nullptr, outStagingTexture);
    if (FAILED(hr)) {
        DEBUG_LOG_HR("FrameBuffer", "CreateTexture2D (staging)", hr);
        return false;
    }

    DEBUG_LOG("FrameBuffer", "CreateStagingTexture: success");
    return true;
}

bool MapTexture(
    ID3D11DeviceContext* context,
    ID3D11Texture2D* stagingTexture,
    D3D11_MAPPED_SUBRESOURCE& outMappedResource
) {
    DEBUG_LOG("FrameBuffer", "MapTexture called");

    if (!context || !stagingTexture) {
        DEBUG_LOG("FrameBuffer", "MapTexture: null parameter");
        return false;
    }

    HRESULT hr = context->Map(
        stagingTexture,
        0,                          // Subresource
        D3D11_MAP_READ,             // Map type
        0,                          // Map flags
        &outMappedResource
    );

    if (FAILED(hr)) {
        DEBUG_LOG_HR("FrameBuffer", "Map", hr);
        return false;
    }

    DEBUG_LOG_FMT("FrameBuffer", "MapTexture: success, pitch=%u", outMappedResource.RowPitch);
    return true;
}

void UnmapTexture(
    ID3D11DeviceContext* context,
    ID3D11Texture2D* stagingTexture
) {
    DEBUG_LOG("FrameBuffer", "UnmapTexture called");

    if (context && stagingTexture) {
        context->Unmap(stagingTexture, 0);
        DEBUG_LOG("FrameBuffer", "UnmapTexture: success");
    } else {
        DEBUG_LOG("FrameBuffer", "UnmapTexture: null parameter");
    }
}

} // namespace FrameBuffer
