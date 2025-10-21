#include "AsyncFrameProcessor.h"
#include "../core/ModalityManager.h"
#include "../core/DebugLog.h"
#include "DesktopDuplicationBackend.h"
#include "LuaBindings.h"
#include <gdiplus.h>

using namespace Gdiplus;

// Helper function declarations
extern int GetEncoderClsid(const WCHAR* format, CLSID* pClsid);
extern bool CreateDirectoryRecursive(const std::string& path);

AsyncFrameProcessor::AsyncFrameProcessor(ModalityManager* mgr)
    : modalityManager(mgr)
    , workerThread(nullptr)
    , running(false)
    , device(nullptr)
    , context(nullptr)
{
}

AsyncFrameProcessor::~AsyncFrameProcessor() {
    Stop();

    if (context) {
        context->Release();
        context = nullptr;
    }

    if (device) {
        device->Release();
        device = nullptr;
    }
}

void AsyncFrameProcessor::Start() {
    if (running) return;

    running = true;
    workerThread = new std::thread(&AsyncFrameProcessor::WorkerThread, this);
}

void AsyncFrameProcessor::Stop() {
    if (!running) return;

    running = false;
    queueCV.notify_all();

    if (workerThread) {
        workerThread->join();
        delete workerThread;
        workerThread = nullptr;
    }

    // Clean up remaining tasks
    std::lock_guard<std::mutex> lock(queueMutex);
    while (!taskQueue.empty()) {
        FrameTask task = taskQueue.front();
        if (task.texture) {
            task.texture->Release();
        }
        taskQueue.pop();
    }
}

bool AsyncFrameProcessor::SubmitFrame(ID3D11Texture2D* texture, int modalityId, const std::string& imagePath,
                                      ImageFormat imageFormat, bool saveToVideo, int width, int height, int jpegQuality) {
    if (!texture) return false;

    // Clone texture (fast GPU operation)
    ID3D11Texture2D* clonedTexture = CloneTexture(texture);
    if (!clonedTexture) {
        return false;
    }

    // Queue task
    FrameTask task;
    task.texture = clonedTexture;
    task.modalityId = modalityId;
    task.imagePath = imagePath;
    task.imageFormat = imageFormat;
    task.saveToVideo = saveToVideo;
    task.width = width;
    task.height = height;
    task.jpegQuality = jpegQuality;

    {
        std::lock_guard<std::mutex> lock(queueMutex);
        taskQueue.push(task);
    }

    queueCV.notify_one();
    return true;
}

void AsyncFrameProcessor::SubmitCaptureRequest(CaptureRequest req) {
    std::lock_guard<std::mutex> lock(captureMutex);
    captureQueue.push(req);
    queueCV.notify_one();
}

ID3D11Texture2D* AsyncFrameProcessor::CloneTexture(ID3D11Texture2D* source) {
    // Get device from source texture
    ID3D11Device* srcDevice = nullptr;
    source->GetDevice(&srcDevice);
    if (!srcDevice) return nullptr;

    ID3D11DeviceContext* srcContext = nullptr;
    srcDevice->GetImmediateContext(&srcContext);
    if (!srcContext) {
        srcDevice->Release();
        return nullptr;
    }

    // Get source texture description
    D3D11_TEXTURE2D_DESC desc;
    source->GetDesc(&desc);

    // Create cloned texture with same properties
    ID3D11Texture2D* cloned = nullptr;
    HRESULT hr = srcDevice->CreateTexture2D(&desc, nullptr, &cloned);

    if (SUCCEEDED(hr)) {
        // Copy GPU texture data
        srcContext->CopyResource(cloned, source);
    }

    srcContext->Release();
    srcDevice->Release();

    return cloned;
}

void AsyncFrameProcessor::WorkerThread() {
    while (running) {
        // Check for capture requests first (higher priority)
        CaptureRequest captureReq;
        bool hasCaptureRequest = false;
        {
            std::lock_guard<std::mutex> lock(captureMutex);
            if (!captureQueue.empty()) {
                captureReq = captureQueue.front();
                captureQueue.pop();
                hasCaptureRequest = true;
            }
        }

        if (hasCaptureRequest) {
            ProcessCaptureRequest(captureReq);
            continue;
        }

        // Process frame tasks
        FrameTask task;
        bool hasTask = false;
        {
            std::unique_lock<std::mutex> lock(queueMutex);
            queueCV.wait(lock, [this] {
                bool hasCaptureReq = false;
                {
                    std::lock_guard<std::mutex> capLock(captureMutex);
                    hasCaptureReq = !captureQueue.empty();
                }
                return !taskQueue.empty() || hasCaptureReq || !running;
            });

            if (!running && taskQueue.empty()) {
                break;
            }

            if (!taskQueue.empty()) {
                task = taskQueue.front();
                taskQueue.pop();
                hasTask = true;
            }
        }

        if (hasTask) {
            ProcessFrame(task);
            if (task.texture) {
                task.texture->Release();
            }
        }
    }
}

void AsyncFrameProcessor::ProcessFrame(const FrameTask& task) {
    // Conditionally submit to video encoder
    if (task.saveToVideo && task.modalityId >= 0 && modalityManager) {
        modalityManager->AddFrame(task.modalityId, task.texture);
    }

    // Save image if requested (blocking operation)
    if (task.imageFormat != ImageFormat::NONE && !task.imagePath.empty()) {
        // Get target dimensions from ModalityManager
        // For consistency, images should match video resolution even if not saving to video
        int targetWidth = task.width;
        int targetHeight = task.height;

        if (task.modalityId >= 0 && modalityManager) {
            if (modalityManager->GetTargetDimensions(task.modalityId, targetWidth, targetHeight)) {
                // Use target dimensions from modality manager
                DEBUG_LOG_FMT("AsyncFrameProcessor", "ProcessFrame: using modality target dims %dx%d (native: %dx%d)",
                    targetWidth, targetHeight, task.width, task.height);
            } else {
                // Fallback to native capture dimensions
                targetWidth = task.width;
                targetHeight = task.height;
            }
        }

        // Save based on image format
        switch (task.imageFormat) {
            case ImageFormat::PNG:
                SaveTextureToPNG(task.texture, task.imagePath, targetWidth, targetHeight);
                break;

            case ImageFormat::PNG_INDEXED:
                SaveTextureToIndexedPNG(task.texture, task.imagePath, targetWidth, targetHeight);
                break;

            case ImageFormat::JPEG:
                SaveTextureToJPEG(task.texture, task.imagePath, targetWidth, targetHeight, task.jpegQuality);
                break;

            default:
                break;
        }
    }
}

void AsyncFrameProcessor::ProcessCaptureRequest(const CaptureRequest& req) {
    ID3D11Texture2D* frame = nullptr;
    ID3D11Texture2D* cloned = nullptr;
    int width = 0;
    int height = 0;

    try {
        if (!g_captureBackend) {
            throw std::runtime_error("Capture backend not available");
        }

        frame = g_captureBackend->CaptureFrame();
        if (!frame) {
            throw std::runtime_error("CaptureFrame returned null");
        }

        width = g_captureBackend->GetWidth();
        height = g_captureBackend->GetHeight();

        cloned = CloneTexture(frame);

        g_captureBackend->ReleaseFrame();
        frame->Release();
        frame = nullptr;

        if (!cloned) {
            throw std::runtime_error("CloneTexture failed");
        }

        LuaBindings::QueueLuaCallback(req.luaVM, req.callbackRef, true, width, height);

        FrameTask task;
        task.texture = cloned;
        task.modalityId = req.modalityId;
        task.imagePath = req.imagePath;
        task.imageFormat = req.imageFormat;
        task.saveToVideo = req.saveToVideo;
        task.jpegQuality = req.jpegQuality;
        task.width = width;
        task.height = height;

        ProcessFrame(task);
        cloned->Release();

    } catch (const std::exception& e) {
        DEBUG_LOG_FMT("AsyncFrameProcessor", "ProcessCaptureRequest exception: %s", e.what());

        if (frame) {
            g_captureBackend->ReleaseFrame();
            frame->Release();
        }
        if (cloned) {
            cloned->Release();
        }

        LuaBindings::QueueLuaCallback(req.luaVM, req.callbackRef, false, 0, 0);
    } catch (...) {
        DEBUG_LOG("AsyncFrameProcessor", "ProcessCaptureRequest unknown exception");

        if (frame) {
            g_captureBackend->ReleaseFrame();
            frame->Release();
        }
        if (cloned) {
            cloned->Release();
        }

        LuaBindings::QueueLuaCallback(req.luaVM, req.callbackRef, false, 0, 0);
    }
}

void AsyncFrameProcessor::SaveTextureToPNG(ID3D11Texture2D* texture, const std::string& path, int width, int height) {
    // Get device context from texture
    ID3D11Device* device = nullptr;
    texture->GetDevice(&device);
    if (!device) return;

    ID3D11DeviceContext* context = nullptr;
    device->GetImmediateContext(&context);
    if (!context) {
        device->Release();
        return;
    }

    // Create staging texture
    D3D11_TEXTURE2D_DESC desc;
    texture->GetDesc(&desc);
    desc.Usage = D3D11_USAGE_STAGING;
    desc.BindFlags = 0;
    desc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
    desc.MiscFlags = 0;

    ID3D11Texture2D* stagingTexture = nullptr;
    device->CreateTexture2D(&desc, nullptr, &stagingTexture);
    if (!stagingTexture) {
        context->Release();
        device->Release();
        return;
    }

    context->CopyResource(stagingTexture, texture);

    // Map staging texture
    D3D11_MAPPED_SUBRESOURCE mapped;
    HRESULT hr = context->Map(stagingTexture, 0, D3D11_MAP_READ, 0, &mapped);

    if (SUCCEEDED(hr)) {
        // Create GDI+ bitmap from mapped pixels (source texture dimensions)
        D3D11_TEXTURE2D_DESC texDesc;
        texture->GetDesc(&texDesc);

        Bitmap sourceBitmap(texDesc.Width, texDesc.Height, mapped.RowPitch, PixelFormat32bppRGB, (BYTE*)mapped.pData);

        // Check if we need to resize
        if ((int)texDesc.Width != width || (int)texDesc.Height != height) {
            // Create target bitmap at desired resolution
            Bitmap targetBitmap(width, height, PixelFormat32bppARGB);

            // Use GDI+ Graphics for hardware-accelerated bilinear scaling
            Graphics graphics(&targetBitmap);
            graphics.SetInterpolationMode(InterpolationModeHighQualityBilinear);
            graphics.SetPixelOffsetMode(PixelOffsetModeHighQuality);
            graphics.SetSmoothingMode(SmoothingModeHighQuality);

            // Draw source bitmap scaled to target dimensions
            graphics.DrawImage(&sourceBitmap, 0, 0, width, height);

            // Save resized bitmap to PNG
            CreateDirectoryRecursive(path);
            CLSID pngClsid;
            if (GetEncoderClsid(L"image/png", &pngClsid) >= 0) {
                std::wstring wPath(path.begin(), path.end());
                targetBitmap.Save(wPath.c_str(), &pngClsid, nullptr);
            }
        } else {
            // No resize needed, save directly
            CreateDirectoryRecursive(path);
            CLSID pngClsid;
            if (GetEncoderClsid(L"image/png", &pngClsid) >= 0) {
                std::wstring wPath(path.begin(), path.end());
                sourceBitmap.Save(wPath.c_str(), &pngClsid, nullptr);
            }
        }

        // Unmap
        context->Unmap(stagingTexture, 0);
    }

    stagingTexture->Release();
    context->Release();
    device->Release();
}

void AsyncFrameProcessor::SaveTextureToIndexedPNG(ID3D11Texture2D* texture, const std::string& path, int width, int height) {
    // Get device context from texture
    ID3D11Device* device = nullptr;
    texture->GetDevice(&device);
    if (!device) return;

    ID3D11DeviceContext* context = nullptr;
    device->GetImmediateContext(&context);
    if (!context) {
        device->Release();
        return;
    }

    // Create staging texture
    D3D11_TEXTURE2D_DESC desc;
    texture->GetDesc(&desc);
    desc.Usage = D3D11_USAGE_STAGING;
    desc.BindFlags = 0;
    desc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
    desc.MiscFlags = 0;

    ID3D11Texture2D* stagingTexture = nullptr;
    device->CreateTexture2D(&desc, nullptr, &stagingTexture);
    if (!stagingTexture) {
        context->Release();
        device->Release();
        return;
    }

    context->CopyResource(stagingTexture, texture);

    // Map staging texture
    D3D11_MAPPED_SUBRESOURCE mapped;
    HRESULT hr = context->Map(stagingTexture, 0, D3D11_MAP_READ, 0, &mapped);

    if (SUCCEEDED(hr)) {
        // Create GDI+ source bitmap from mapped pixels
        D3D11_TEXTURE2D_DESC texDesc;
        texture->GetDesc(&texDesc);
        Bitmap sourceBitmap(texDesc.Width, texDesc.Height, mapped.RowPitch, PixelFormat32bppRGB, (BYTE*)mapped.pData);

        // Resize to target dimensions if needed (BEFORE indexing)
        Bitmap* workingBitmap = &sourceBitmap;
        Bitmap* resizedBitmap = nullptr;

        if ((int)texDesc.Width != width || (int)texDesc.Height != height) {
            resizedBitmap = new Bitmap(width, height, PixelFormat32bppRGB);
            Graphics graphics(resizedBitmap);
            graphics.SetInterpolationMode(InterpolationModeNearestNeighbor);  // Use nearest-neighbor to preserve exact colors
            graphics.SetPixelOffsetMode(PixelOffsetModeHalf);
            graphics.DrawImage(&sourceBitmap, 0, 0, width, height);
            workingBitmap = resizedBitmap;

            DEBUG_LOG_FMT("AsyncFrameProcessor", "SaveTextureToIndexedPNG: resized %dx%d -> %dx%d",
                texDesc.Width, texDesc.Height, width, height);
        }

        // Lock the working bitmap to scan pixels
        BitmapData srcData;
        Rect rect(0, 0, workingBitmap->GetWidth(), workingBitmap->GetHeight());
        workingBitmap->LockBits(&rect, ImageLockModeRead, PixelFormat32bppRGB, &srcData);

        // Build color palette by scanning pixels
        std::map<DWORD, BYTE> colorToPaletteIndex;
        std::vector<Color> palette;

        BYTE* pixels = (BYTE*)srcData.Scan0;
        for (UINT y = 0; y < (UINT)srcData.Height; y++) {
            DWORD* row = (DWORD*)(pixels + y * srcData.Stride);
            for (UINT x = 0; x < (UINT)srcData.Width; x++) {
                DWORD color = row[x] & 0x00FFFFFF;  // Mask out alpha

                if (colorToPaletteIndex.find(color) == colorToPaletteIndex.end()) {
                    if (palette.size() < 256) {
                        BYTE r = (color >> 16) & 0xFF;
                        BYTE g = (color >> 8) & 0xFF;
                        BYTE b = color & 0xFF;

                        palette.push_back(Color(255, r, g, b));
                        colorToPaletteIndex[color] = (BYTE)(palette.size() - 1);
                    } else {
                        // More than 256 colors - fall back to regular PNG
                        workingBitmap->UnlockBits(&srcData);
                        if (resizedBitmap) delete resizedBitmap;
                        context->Unmap(stagingTexture, 0);
                        stagingTexture->Release();
                        context->Release();
                        device->Release();

                        DEBUG_LOG("AsyncFrameProcessor", "SaveTextureToIndexedPNG: >256 colors, falling back to RGB PNG");
                        SaveTextureToPNG(texture, path, width, height);
                        return;
                    }
                }
            }
        }

        // Create indexed bitmap at target dimensions
        Bitmap indexedBitmap(srcData.Width, srcData.Height, PixelFormat8bppIndexed);

        // Set palette
        ColorPalette* pal = (ColorPalette*)malloc(sizeof(ColorPalette) + sizeof(ARGB) * 256);
        pal->Flags = 0;
        pal->Count = palette.size();
        for (size_t i = 0; i < palette.size(); i++) {
            pal->Entries[i] = palette[i].GetValue();
        }
        indexedBitmap.SetPalette(pal);
        free(pal);

        // Convert pixels to indices
        BitmapData bmpData;
        Rect dstRect(0, 0, srcData.Width, srcData.Height);
        indexedBitmap.LockBits(&dstRect, ImageLockModeWrite, PixelFormat8bppIndexed, &bmpData);

        BYTE* dstPixels = (BYTE*)bmpData.Scan0;
        for (UINT y = 0; y < (UINT)srcData.Height; y++) {
            DWORD* srcRow = (DWORD*)(pixels + y * srcData.Stride);
            BYTE* dstRow = dstPixels + y * bmpData.Stride;

            for (UINT x = 0; x < (UINT)srcData.Width; x++) {
                DWORD color = srcRow[x] & 0x00FFFFFF;
                dstRow[x] = colorToPaletteIndex[color];
            }
        }

        indexedBitmap.UnlockBits(&bmpData);
        workingBitmap->UnlockBits(&srcData);
        context->Unmap(stagingTexture, 0);

        // Clean up resized bitmap if created
        if (resizedBitmap) {
            delete resizedBitmap;
        }

        // Save PNG
        CreateDirectoryRecursive(path);
        CLSID pngClsid;
        if (GetEncoderClsid(L"image/png", &pngClsid) >= 0) {
            std::wstring wPath(path.begin(), path.end());
            Status status = indexedBitmap.Save(wPath.c_str(), &pngClsid, nullptr);

            if (status == Ok) {
                DEBUG_LOG_FMT("AsyncFrameProcessor", "SaveTextureToIndexedPNG: saved %dx%d, %d unique colors",
                    width, height, (int)palette.size());
            } else {
                DEBUG_LOG_FMT("AsyncFrameProcessor", "SaveTextureToIndexedPNG: save failed with status %d", status);
            }
        }
    }

    stagingTexture->Release();
    context->Release();
    device->Release();
}

void AsyncFrameProcessor::SaveTextureToJPEG(ID3D11Texture2D* texture, const std::string& path, int width, int height, int quality) {
    // Get device context from texture
    ID3D11Device* device = nullptr;
    texture->GetDevice(&device);
    if (!device) return;

    ID3D11DeviceContext* context = nullptr;
    device->GetImmediateContext(&context);
    if (!context) {
        device->Release();
        return;
    }

    // Create staging texture
    D3D11_TEXTURE2D_DESC desc;
    texture->GetDesc(&desc);
    desc.Usage = D3D11_USAGE_STAGING;
    desc.BindFlags = 0;
    desc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
    desc.MiscFlags = 0;

    ID3D11Texture2D* stagingTexture = nullptr;
    device->CreateTexture2D(&desc, nullptr, &stagingTexture);
    if (!stagingTexture) {
        context->Release();
        device->Release();
        return;
    }

    context->CopyResource(stagingTexture, texture);

    // Map staging texture
    D3D11_MAPPED_SUBRESOURCE mapped;
    HRESULT hr = context->Map(stagingTexture, 0, D3D11_MAP_READ, 0, &mapped);

    if (SUCCEEDED(hr)) {
        // Create GDI+ bitmap from mapped pixels (source texture dimensions)
        D3D11_TEXTURE2D_DESC texDesc;
        texture->GetDesc(&texDesc);

        Bitmap sourceBitmap(texDesc.Width, texDesc.Height, mapped.RowPitch, PixelFormat32bppRGB, (BYTE*)mapped.pData);

        // Check if we need to resize
        if ((int)texDesc.Width != width || (int)texDesc.Height != height) {
            // Create target bitmap at desired resolution
            Bitmap targetBitmap(width, height, PixelFormat32bppRGB);

            // Use GDI+ Graphics for hardware-accelerated bilinear scaling
            Graphics graphics(&targetBitmap);
            graphics.SetInterpolationMode(InterpolationModeHighQualityBilinear);
            graphics.SetPixelOffsetMode(PixelOffsetModeHighQuality);
            graphics.SetSmoothingMode(SmoothingModeHighQuality);

            // Draw source bitmap scaled to target dimensions
            graphics.DrawImage(&sourceBitmap, 0, 0, width, height);

            // Save resized bitmap as JPEG
            CreateDirectoryRecursive(path);
            CLSID jpegClsid;
            if (GetEncoderClsid(L"image/jpeg", &jpegClsid) >= 0) {
                // Set JPEG quality
                EncoderParameters encoderParams;
                encoderParams.Count = 1;
                encoderParams.Parameter[0].Guid = EncoderQuality;
                encoderParams.Parameter[0].Type = EncoderParameterValueTypeLong;
                encoderParams.Parameter[0].NumberOfValues = 1;
                ULONG qualityValue = quality;
                encoderParams.Parameter[0].Value = &qualityValue;

                std::wstring wPath(path.begin(), path.end());
                Status status = targetBitmap.Save(wPath.c_str(), &jpegClsid, &encoderParams);

                if (status == Ok) {
                    DEBUG_LOG_FMT("AsyncFrameProcessor", "SaveTextureToJPEG: saved %dx%d, quality=%d",
                        width, height, quality);
                } else {
                    DEBUG_LOG_FMT("AsyncFrameProcessor", "SaveTextureToJPEG: save failed with status %d", status);
                }
            }
        } else {
            // No resize needed, save directly
            CreateDirectoryRecursive(path);
            CLSID jpegClsid;
            if (GetEncoderClsid(L"image/jpeg", &jpegClsid) >= 0) {
                // Set JPEG quality
                EncoderParameters encoderParams;
                encoderParams.Count = 1;
                encoderParams.Parameter[0].Guid = EncoderQuality;
                encoderParams.Parameter[0].Type = EncoderParameterValueTypeLong;
                encoderParams.Parameter[0].NumberOfValues = 1;
                ULONG qualityValue = quality;
                encoderParams.Parameter[0].Value = &qualityValue;

                std::wstring wPath(path.begin(), path.end());
                Status status = sourceBitmap.Save(wPath.c_str(), &jpegClsid, &encoderParams);

                if (status == Ok) {
                    DEBUG_LOG_FMT("AsyncFrameProcessor", "SaveTextureToJPEG: saved %dx%d (no resize), quality=%d",
                        (int)texDesc.Width, (int)texDesc.Height, quality);
                } else {
                    DEBUG_LOG_FMT("AsyncFrameProcessor", "SaveTextureToJPEG: save failed with status %d", status);
                }
            }
        }

        // Unmap
        context->Unmap(stagingTexture, 0);
    }

    stagingTexture->Release();
    context->Release();
    device->Release();
}
