#include "VideoEncoder.h"
#include "MediaFoundationUtils.h"
#include "FrameBuffer.h"
#include "DebugLog.h"
#include <mferror.h>

// External helper function from main.cpp
extern bool CreateDirectoryRecursive(const std::string& path);

VideoEncoder::VideoEncoder()
    : sinkWriter(nullptr)
    , streamIndex(0)
    , frameCount(0)
    , fps(30)
    , width(1920)
    , height(1080)
    , bitrate(5000000)
    , initialized(false)
{
    DEBUG_LOG("VideoEncoder", "Constructor called");
}

VideoEncoder::~VideoEncoder() {
    DEBUG_LOG("VideoEncoder", "Destructor called");
    Stop();
}

bool VideoEncoder::Start(const std::string& path, int w, int h, int fps, int bitrate) {
    DEBUG_LOG_FMT("VideoEncoder", "Start: path=%s, dims=%dx%d, fps=%d, bitrate=%d",
        path.c_str(), w, h, fps, bitrate);

    if (initialized) {
        DEBUG_LOG("VideoEncoder", "Start: already initialized");
        return false;  // Already started
    }

    this->width = w;
    this->height = h;
    this->fps = fps;
    this->bitrate = bitrate;

    if (!InitializeMediaFoundation()) {
        DEBUG_LOG("VideoEncoder", "Start: Media Foundation initialization failed");
        return false;
    }

    if (!CreateSinkWriter(path)) {
        DEBUG_LOG("VideoEncoder", "Start: CreateSinkWriter failed");
        return false;
    }

    if (!ConfigureVideoStream()) {
        DEBUG_LOG("VideoEncoder", "Start: ConfigureVideoStream failed");
        return false;
    }

    // Start writing
    HRESULT hr = sinkWriter->BeginWriting();
    if (FAILED(hr)) {
        DEBUG_LOG_HR("VideoEncoder", "BeginWriting", hr);
        return false;
    }

    initialized = true;
    frameCount = 0;
    DEBUG_LOG("VideoEncoder", "Start: success");
    return true;
}

bool VideoEncoder::AddFrame(ID3D11Texture2D* gpuTexture) {
    if (!initialized || !gpuTexture) {
        if (!initialized) DEBUG_LOG("VideoEncoder", "AddFrame: not initialized");
        if (!gpuTexture) DEBUG_LOG("VideoEncoder", "AddFrame: null texture");
        return false;
    }

    DEBUG_LOG_FMT("VideoEncoder", "AddFrame (texture): frame %lld", frameCount);

    // CRITICAL FIX: Check texture dimensions BEFORE attempting resize
    // Only resize if dimensions actually differ (avoid expensive operation when not needed)
    D3D11_TEXTURE2D_DESC desc;
    gpuTexture->GetDesc(&desc);

    ID3D11Texture2D* textureToEncode = nullptr;
    bool needsResize = ((int)desc.Width != width || (int)desc.Height != height);

    if (needsResize) {
        DEBUG_LOG_FMT("VideoEncoder", "AddFrame: resizing from %dx%d to %dx%d", desc.Width, desc.Height, width, height);

        // Resize texture to target dimensions if needed
        // NOTE: This is a BLOCKING operation that can take 100-500ms+
        // TODO: Move this to background thread via async queue
        textureToEncode = ResizeTexture(gpuTexture, width, height);
        if (!textureToEncode) {
            DEBUG_LOG("VideoEncoder", "AddFrame: ResizeTexture failed");
            return false;
        }
    } else {
        DEBUG_LOG("VideoEncoder", "AddFrame: dimensions match, no resize needed");
        // Use texture directly - no copy needed since CreateSampleFromTexture will copy anyway
        textureToEncode = gpuTexture;
        textureToEncode->AddRef();  // AddRef since we'll Release later
    }

    IMFSample* sample = CreateSampleFromTexture(textureToEncode);
    textureToEncode->Release();  // Release texture (whether resized or original)

    if (!sample) {
        DEBUG_LOG("VideoEncoder", "AddFrame: CreateSampleFromTexture failed");
        return false;
    }

    // Set sample time and duration
    LONGLONG sampleTime = (frameCount * 10000000LL) / fps;  // 100-nanosecond units
    LONGLONG sampleDuration = 10000000LL / fps;

    sample->SetSampleTime(sampleTime);
    sample->SetSampleDuration(sampleDuration);

    // Write sample
    HRESULT hr = sinkWriter->WriteSample(streamIndex, sample);
    sample->Release();

    if (FAILED(hr)) {
        DEBUG_LOG_HR("VideoEncoder", "WriteSample", hr);
        return false;
    }

    frameCount++;
    DEBUG_LOG_FMT("VideoEncoder", "AddFrame (texture): success, total frames=%lld", frameCount);
    return true;
}

bool VideoEncoder::AddFrame(void* pixels, int w, int h, int pitch, GUID format) {
    if (!initialized || !pixels) {
        if (!initialized) DEBUG_LOG("VideoEncoder", "AddFrame: not initialized");
        if (!pixels) DEBUG_LOG("VideoEncoder", "AddFrame: null pixels");
        return false;
    }

    DEBUG_LOG_FMT("VideoEncoder", "AddFrame (pixels): frame %lld, dims=%dx%d, pitch=%d", frameCount, w, h, pitch);

    IMFSample* sample = CreateSampleFromPixels(pixels, w, h, pitch, format);
    if (!sample) {
        DEBUG_LOG("VideoEncoder", "AddFrame: CreateSampleFromPixels failed");
        return false;
    }

    // Set sample time and duration
    LONGLONG sampleTime = (frameCount * 10000000LL) / fps;
    LONGLONG sampleDuration = 10000000LL / fps;

    sample->SetSampleTime(sampleTime);
    sample->SetSampleDuration(sampleDuration);

    // Write sample
    HRESULT hr = sinkWriter->WriteSample(streamIndex, sample);
    sample->Release();

    if (FAILED(hr)) {
        DEBUG_LOG_HR("VideoEncoder", "WriteSample", hr);
        return false;
    }

    frameCount++;
    DEBUG_LOG_FMT("VideoEncoder", "AddFrame (pixels): success, total frames=%lld", frameCount);
    return true;
}

bool VideoEncoder::Stop() {
    DEBUG_LOG_FMT("VideoEncoder", "Stop: initialized=%d, frames=%lld", initialized, frameCount);

    if (!initialized) {
        DEBUG_LOG("VideoEncoder", "Stop: already stopped");
        return true;  // Already stopped
    }

    if (sinkWriter) {
        HRESULT hr = sinkWriter->Finalize();
        if (FAILED(hr)) {
            DEBUG_LOG_HR("VideoEncoder", "Finalize", hr);
        }
        sinkWriter->Release();
        sinkWriter = nullptr;
    }

    initialized = false;
    DEBUG_LOG("VideoEncoder", "Stop: success");
    return true;
}

bool VideoEncoder::InitializeMediaFoundation() {
    return MediaFoundationUtils::Initialize();
}

bool VideoEncoder::CreateSinkWriter(const std::string& path) {
    DEBUG_LOG_FMT("VideoEncoder", "CreateSinkWriter: creating directories for path=%s", path.c_str());

    // Create parent directories if they don't exist
    // Media Foundation requires parent directories to exist before creating the file
    CreateDirectoryRecursive(path);

    // Convert std::string to wstring
    int len = MultiByteToWideChar(CP_UTF8, 0, path.c_str(), -1, nullptr, 0);
    wchar_t* wPath = new wchar_t[len];
    MultiByteToWideChar(CP_UTF8, 0, path.c_str(), -1, wPath, len);

    IMFAttributes* attributes = nullptr;
    HRESULT hr = MFCreateAttributes(&attributes, 1);
    if (FAILED(hr)) {
        DEBUG_LOG_HR("VideoEncoder", "MFCreateAttributes", hr);
        delete[] wPath;
        return false;
    }

    attributes->SetUINT32(MF_READWRITE_ENABLE_HARDWARE_TRANSFORMS, TRUE);

    DEBUG_LOG("VideoEncoder", "CreateSinkWriter: calling MFCreateSinkWriterFromURL");
    hr = MFCreateSinkWriterFromURL(wPath, nullptr, attributes, &sinkWriter);

    attributes->Release();
    delete[] wPath;

    if (FAILED(hr)) {
        DEBUG_LOG_HR("VideoEncoder", "MFCreateSinkWriterFromURL", hr);
        return false;
    }

    DEBUG_LOG("VideoEncoder", "CreateSinkWriter: success");
    return true;
}

bool VideoEncoder::ConfigureVideoStream() {
    IMFMediaType* outputType = nullptr;
    IMFMediaType* inputType = nullptr;

    HRESULT hr = MFCreateMediaType(&outputType);
    if (FAILED(hr)) {
        return false;
    }

    // Configure output media type (H.264)
    outputType->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
    outputType->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_H264);
    outputType->SetUINT32(MF_MT_AVG_BITRATE, bitrate);
    outputType->SetUINT32(MF_MT_INTERLACE_MODE, MFVideoInterlace_Progressive);
    MFSetAttributeSize(outputType, MF_MT_FRAME_SIZE, width, height);
    MFSetAttributeRatio(outputType, MF_MT_FRAME_RATE, fps, 1);
    MFSetAttributeRatio(outputType, MF_MT_PIXEL_ASPECT_RATIO, 1, 1);

    hr = sinkWriter->AddStream(outputType, &streamIndex);
    outputType->Release();

    if (FAILED(hr)) {
        return false;
    }

    // Configure input media type (RGB32)
    hr = MFCreateMediaType(&inputType);
    if (FAILED(hr)) {
        return false;
    }

    inputType->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
    inputType->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_RGB32);
    inputType->SetUINT32(MF_MT_INTERLACE_MODE, MFVideoInterlace_Progressive);
    MFSetAttributeSize(inputType, MF_MT_FRAME_SIZE, width, height);
    MFSetAttributeRatio(inputType, MF_MT_FRAME_RATE, fps, 1);
    MFSetAttributeRatio(inputType, MF_MT_PIXEL_ASPECT_RATIO, 1, 1);

    hr = sinkWriter->SetInputMediaType(streamIndex, inputType, nullptr);
    inputType->Release();

    return SUCCEEDED(hr);
}

IMFSample* VideoEncoder::CreateSampleFromTexture(ID3D11Texture2D* texture) {
    // 1. Get device and context from texture
    ID3D11Device* device = nullptr;
    texture->GetDevice(&device);
    if (!device) {
        return nullptr;
    }

    ID3D11DeviceContext* context = nullptr;
    device->GetImmediateContext(&context);
    if (!context) {
        device->Release();
        return nullptr;
    }

    // 2. Create staging texture
    ID3D11Texture2D* stagingTexture = nullptr;
    if (!FrameBuffer::CreateStagingTexture(device, texture, &stagingTexture)) {
        context->Release();
        device->Release();
        return nullptr;
    }

    // 3. Copy GPU texture to staging
    context->CopyResource(stagingTexture, texture);

    // 4. Map staging texture
    D3D11_MAPPED_SUBRESOURCE mapped;
    if (!FrameBuffer::MapTexture(context, stagingTexture, mapped)) {
        stagingTexture->Release();
        context->Release();
        device->Release();
        return nullptr;
    }

    // 5. Create IMFMediaBuffer from mapped data
    IMFMediaBuffer* buffer = nullptr;
    DWORD bufferSize = width * height * 4;  // RGBA32
    HRESULT hr = MFCreateMemoryBuffer(bufferSize, &buffer);
    if (FAILED(hr)) {
        FrameBuffer::UnmapTexture(context, stagingTexture);
        stagingTexture->Release();
        context->Release();
        device->Release();
        return nullptr;
    }

    // 6. Lock buffer and copy pixels
    BYTE* bufferData = nullptr;
    buffer->Lock(&bufferData, nullptr, nullptr);

    // Copy row by row (handle pitch difference), flip vertically
    // D3D11 textures are top-down, but Media Foundation RGB expects bottom-up
    for (int y = 0; y < height; y++) {
        memcpy(
            bufferData + (y * width * 4),
            (BYTE*)mapped.pData + ((height - 1 - y) * mapped.RowPitch),
            width * 4
        );
    }

    buffer->Unlock();
    buffer->SetCurrentLength(bufferSize);

    // 7. Create IMFSample
    IMFSample* sample = nullptr;
    hr = MFCreateSample(&sample);
    if (FAILED(hr)) {
        buffer->Release();
        FrameBuffer::UnmapTexture(context, stagingTexture);
        stagingTexture->Release();
        context->Release();
        device->Release();
        return nullptr;
    }

    sample->AddBuffer(buffer);
    buffer->Release();

    // 8. Cleanup
    FrameBuffer::UnmapTexture(context, stagingTexture);
    stagingTexture->Release();
    context->Release();
    device->Release();

    return sample;
}

IMFSample* VideoEncoder::CreateSampleFromPixels(void* pixels, int w, int h, int pitch, GUID format) {
    // 1. Create IMFMediaBuffer
    DWORD bufferSize = w * h * 4;  // RGBA32
    IMFMediaBuffer* buffer = nullptr;
    HRESULT hr = MFCreateMemoryBuffer(bufferSize, &buffer);
    if (FAILED(hr)) {
        return nullptr;
    }

    // 2. Lock buffer
    BYTE* bufferData = nullptr;
    buffer->Lock(&bufferData, nullptr, nullptr);

    // 3. Copy pixel data (handle pitch), flip vertically
    // D3D11 textures are top-down, but Media Foundation RGB expects bottom-up
    for (int y = 0; y < h; y++) {
        memcpy(
            bufferData + (y * w * 4),
            (BYTE*)pixels + ((h - 1 - y) * pitch),
            w * 4
        );
    }

    // 4. Unlock buffer
    buffer->Unlock();
    buffer->SetCurrentLength(bufferSize);

    // 5. Create IMFSample
    IMFSample* sample = nullptr;
    hr = MFCreateSample(&sample);
    if (FAILED(hr)) {
        buffer->Release();
        return nullptr;
    }

    // 6. Add buffer to sample
    sample->AddBuffer(buffer);
    buffer->Release();

    return sample;
}

ID3D11Texture2D* VideoEncoder::ResizeTexture(ID3D11Texture2D* source, int targetWidth, int targetHeight) {
    if (!source) {
        DEBUG_LOG("VideoEncoder", "ResizeTexture: null source");
        return nullptr;
    }

    // Get source texture dimensions
    D3D11_TEXTURE2D_DESC srcDesc;
    source->GetDesc(&srcDesc);

    DEBUG_LOG_FMT("VideoEncoder", "ResizeTexture: source=%dx%d, target=%dx%d",
        srcDesc.Width, srcDesc.Height, targetWidth, targetHeight);

    // Get device and context
    ID3D11Device* device = nullptr;
    source->GetDevice(&device);
    if (!device) {
        DEBUG_LOG("VideoEncoder", "ResizeTexture: failed to get device");
        return nullptr;
    }

    ID3D11DeviceContext* context = nullptr;
    device->GetImmediateContext(&context);
    if (!context) {
        device->Release();
        DEBUG_LOG("VideoEncoder", "ResizeTexture: failed to get context");
        return nullptr;
    }

    // If dimensions match, no resize needed - return clone
    if ((int)srcDesc.Width == targetWidth && (int)srcDesc.Height == targetHeight) {
        DEBUG_LOG("VideoEncoder", "ResizeTexture: dimensions match, no resize needed");

        ID3D11Texture2D* cloned = nullptr;
        HRESULT hr = device->CreateTexture2D(&srcDesc, nullptr, &cloned);
        if (SUCCEEDED(hr)) {
            context->CopyResource(cloned, source);
        }

        context->Release();
        device->Release();
        return cloned;
    }

    // GPU-BASED RESIZE using render target and shader resource view
    // This uses D3D11's built-in bilinear filtering for high-quality scaling

    // 1. Create render target texture at target resolution
    D3D11_TEXTURE2D_DESC targetDesc = {};
    targetDesc.Width = targetWidth;
    targetDesc.Height = targetHeight;
    targetDesc.MipLevels = 1;
    targetDesc.ArraySize = 1;
    targetDesc.Format = srcDesc.Format;
    targetDesc.SampleDesc.Count = 1;
    targetDesc.SampleDesc.Quality = 0;
    targetDesc.Usage = D3D11_USAGE_DEFAULT;
    targetDesc.BindFlags = D3D11_BIND_RENDER_TARGET | D3D11_BIND_SHADER_RESOURCE;
    targetDesc.CPUAccessFlags = 0;
    targetDesc.MiscFlags = 0;

    ID3D11Texture2D* targetTexture = nullptr;
    HRESULT hr = device->CreateTexture2D(&targetDesc, nullptr, &targetTexture);
    if (FAILED(hr)) {
        DEBUG_LOG_HR("VideoEncoder", "CreateTexture2D (render target)", hr);
        context->Release();
        device->Release();
        return nullptr;
    }

    // 2. Create render target view
    ID3D11RenderTargetView* rtv = nullptr;
    hr = device->CreateRenderTargetView(targetTexture, nullptr, &rtv);
    if (FAILED(hr)) {
        DEBUG_LOG_HR("VideoEncoder", "CreateRenderTargetView", hr);
        targetTexture->Release();
        context->Release();
        device->Release();
        return nullptr;
    }

    // 3. Create shader resource view from source texture
    D3D11_TEXTURE2D_DESC tempSourceDesc = srcDesc;
    tempSourceDesc.BindFlags = D3D11_BIND_SHADER_RESOURCE;
    tempSourceDesc.Usage = D3D11_USAGE_DEFAULT;
    tempSourceDesc.CPUAccessFlags = 0;

    ID3D11Texture2D* tempSource = nullptr;
    hr = device->CreateTexture2D(&tempSourceDesc, nullptr, &tempSource);
    if (FAILED(hr)) {
        DEBUG_LOG_HR("VideoEncoder", "CreateTexture2D (temp source)", hr);
        rtv->Release();
        targetTexture->Release();
        context->Release();
        device->Release();
        return nullptr;
    }

    context->CopyResource(tempSource, source);

    ID3D11ShaderResourceView* srv = nullptr;
    hr = device->CreateShaderResourceView(tempSource, nullptr, &srv);
    if (FAILED(hr)) {
        DEBUG_LOG_HR("VideoEncoder", "CreateShaderResourceView", hr);
        tempSource->Release();
        rtv->Release();
        targetTexture->Release();
        context->Release();
        device->Release();
        return nullptr;
    }

    // 4. Create sampler state with LINEAR filtering (bilinear interpolation)
    D3D11_SAMPLER_DESC samplerDesc = {};
    samplerDesc.Filter = D3D11_FILTER_MIN_MAG_MIP_LINEAR;  // Bilinear filtering
    samplerDesc.AddressU = D3D11_TEXTURE_ADDRESS_CLAMP;
    samplerDesc.AddressV = D3D11_TEXTURE_ADDRESS_CLAMP;
    samplerDesc.AddressW = D3D11_TEXTURE_ADDRESS_CLAMP;
    samplerDesc.MipLODBias = 0.0f;
    samplerDesc.MaxAnisotropy = 1;
    samplerDesc.ComparisonFunc = D3D11_COMPARISON_NEVER;
    samplerDesc.MinLOD = 0;
    samplerDesc.MaxLOD = D3D11_FLOAT32_MAX;

    ID3D11SamplerState* samplerState = nullptr;
    hr = device->CreateSamplerState(&samplerDesc, &samplerState);
    if (FAILED(hr)) {
        DEBUG_LOG_HR("VideoEncoder", "CreateSamplerState", hr);
        srv->Release();
        tempSource->Release();
        rtv->Release();
        targetTexture->Release();
        context->Release();
        device->Release();
        return nullptr;
    }

    // 5. Use D3D11 StretchRect equivalent: Copy with automatic scaling
    // D3D11 doesn't have StretchRect, so we use ResolveSubresource which performs scaling
    // However, ResolveSubresource only works for MSAA textures
    // The correct approach is to use a full-screen quad with a pixel shader
    // For now, we'll use a simpler approach: CopySubresourceRegion with Box

    // Since full pixel shader setup is complex, use a practical GPU-accelerated approach:
    // Create an intermediate staging texture and use GDI+ hardware acceleration
    // OR use ID3D11DeviceContext::CopySubresourceRegion with different sized textures

    // Actually, the cleanest GPU approach without pixel shaders is:
    // Use ID3D11VideoProcessor which has built-in scaling support

    // For production: Use ID3D11VideoDevice and ID3D11VideoProcessor for hardware-accelerated scaling
    // This requires more setup but gives best performance and quality

    // TEMPORARY: Use CopyResource (will work if sizes match) + fallback to staging
    // TODO: Implement ID3D11VideoProcessor for proper hardware scaling

    // For now, use a hybrid approach: GPU copy + CPU resize for small textures
    // This is still better than pure CPU as the texture stays on GPU until the final copy

    // Cleanup temporary resources
    samplerState->Release();
    srv->Release();
    tempSource->Release();
    rtv->Release();

    // Create final output texture (DEFAULT usage)
    D3D11_TEXTURE2D_DESC finalDesc = targetDesc;
    finalDesc.BindFlags = 0;  // No binding needed for encoder input
    finalDesc.Usage = D3D11_USAGE_DEFAULT;

    ID3D11Texture2D* finalTexture = nullptr;
    hr = device->CreateTexture2D(&finalDesc, nullptr, &finalTexture);

    if (FAILED(hr)) {
        DEBUG_LOG_HR("VideoEncoder", "CreateTexture2D (final)", hr);
        targetTexture->Release();
        context->Release();
        device->Release();
        return nullptr;
    }

    // FALLBACK: Use staging textures + CPU resize
    // TODO: Replace with ID3D11VideoProcessor implementation

    // Create staging source
    D3D11_TEXTURE2D_DESC stagingSrcDesc = srcDesc;
    stagingSrcDesc.Usage = D3D11_USAGE_STAGING;
    stagingSrcDesc.BindFlags = 0;
    stagingSrcDesc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;

    ID3D11Texture2D* stagingSrc = nullptr;
    hr = device->CreateTexture2D(&stagingSrcDesc, nullptr, &stagingSrc);
    if (FAILED(hr)) {
        DEBUG_LOG_HR("VideoEncoder", "CreateTexture2D (staging src)", hr);
        finalTexture->Release();
        targetTexture->Release();
        context->Release();
        device->Release();
        return nullptr;
    }

    context->CopyResource(stagingSrc, source);

    // Create staging target
    D3D11_TEXTURE2D_DESC stagingDstDesc = finalDesc;
    stagingDstDesc.Usage = D3D11_USAGE_STAGING;
    stagingDstDesc.BindFlags = 0;
    stagingDstDesc.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE;

    ID3D11Texture2D* stagingDst = nullptr;
    hr = device->CreateTexture2D(&stagingDstDesc, nullptr, &stagingDst);
    if (FAILED(hr)) {
        DEBUG_LOG_HR("VideoEncoder", "CreateTexture2D (staging dst)", hr);
        stagingSrc->Release();
        finalTexture->Release();
        targetTexture->Release();
        context->Release();
        device->Release();
        return nullptr;
    }

    // Map both textures
    D3D11_MAPPED_SUBRESOURCE srcMapped, dstMapped;
    hr = context->Map(stagingSrc, 0, D3D11_MAP_READ, 0, &srcMapped);
    if (FAILED(hr)) {
        DEBUG_LOG_HR("VideoEncoder", "Map (staging src)", hr);
        stagingDst->Release();
        stagingSrc->Release();
        finalTexture->Release();
        targetTexture->Release();
        context->Release();
        device->Release();
        return nullptr;
    }

    hr = context->Map(stagingDst, 0, D3D11_MAP_WRITE, 0, &dstMapped);
    if (FAILED(hr)) {
        DEBUG_LOG_HR("VideoEncoder", "Map (staging dst)", hr);
        context->Unmap(stagingSrc, 0);
        stagingDst->Release();
        stagingSrc->Release();
        finalTexture->Release();
        targetTexture->Release();
        context->Release();
        device->Release();
        return nullptr;
    }

    // Bilinear interpolation resize (CPU, but fast for typical resolutions)
    BYTE* srcPixels = (BYTE*)srcMapped.pData;
    BYTE* dstPixels = (BYTE*)dstMapped.pData;

    float scaleX = (float)srcDesc.Width / targetWidth;
    float scaleY = (float)srcDesc.Height / targetHeight;

    for (int y = 0; y < targetHeight; y++) {
        for (int x = 0; x < targetWidth; x++) {
            float srcX = x * scaleX;
            float srcY = y * scaleY;

            int x0 = (int)srcX;
            int y0 = (int)srcY;
            int x1 = (x0 + 1 < (int)srcDesc.Width) ? x0 + 1 : x0;
            int y1 = (y0 + 1 < (int)srcDesc.Height) ? y0 + 1 : y0;

            float fx = srcX - x0;
            float fy = srcY - y0;

            // Get 4 neighboring pixels
            BYTE* p00 = srcPixels + (y0 * srcMapped.RowPitch) + (x0 * 4);
            BYTE* p10 = srcPixels + (y0 * srcMapped.RowPitch) + (x1 * 4);
            BYTE* p01 = srcPixels + (y1 * srcMapped.RowPitch) + (x0 * 4);
            BYTE* p11 = srcPixels + (y1 * srcMapped.RowPitch) + (x1 * 4);

            BYTE* dst = dstPixels + (y * dstMapped.RowPitch) + (x * 4);

            // Bilinear interpolation for each channel
            for (int c = 0; c < 4; c++) {
                float v0 = p00[c] * (1 - fx) + p10[c] * fx;
                float v1 = p01[c] * (1 - fx) + p11[c] * fx;
                dst[c] = (BYTE)(v0 * (1 - fy) + v1 * fy);
            }
        }
    }

    // Unmap
    context->Unmap(stagingDst, 0);
    context->Unmap(stagingSrc, 0);

    // Copy to final GPU texture
    context->CopyResource(finalTexture, stagingDst);

    // Cleanup
    stagingDst->Release();
    stagingSrc->Release();
    targetTexture->Release();
    context->Release();
    device->Release();

    DEBUG_LOG("VideoEncoder", "ResizeTexture: success (bilinear interpolation)");
    return finalTexture;
}
