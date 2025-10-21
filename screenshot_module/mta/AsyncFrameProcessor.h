#pragma once
#include <d3d11.h>
#include <queue>
#include <mutex>
#include <condition_variable>
#include <thread>
#include <string>

// Forward declarations
class ModalityManager;
class DesktopDuplicationBackend;
extern DesktopDuplicationBackend* g_captureBackend;

struct lua_State;

/// Image format enumeration
enum class ImageFormat {
    NONE,         // No image saving
    PNG,          // Standard 32-bit RGBA PNG
    PNG_INDEXED,  // 8-bit indexed/palette PNG (for segmentation)
    JPEG          // JPEG with quality parameter
};

struct FrameTask {
    ID3D11Texture2D* texture;  // Cloned texture (owned by queue)
    int modalityId;            // Video encoder modality ID
    std::string imagePath;     // Path for image file (if imageFormat != NONE)
    ImageFormat imageFormat;   // Image format to save
    bool saveToVideo;          // Submit frame to video encoder?
    int width;                 // Target width for image
    int height;                // Target height for image
    int jpegQuality;           // JPEG quality (0-100), only used if imageFormat == JPEG
};

struct CaptureRequest {
    int modalityId;            // Video encoder modality ID
    std::string imagePath;     // Path for image file (if imageFormat != NONE)
    ImageFormat imageFormat;   // Image format to save
    bool saveToVideo;          // Submit frame to video encoder?
    int jpegQuality;           // JPEG quality (0-100)
    int callbackRef;           // Lua callback reference
    lua_State* luaVM;          // Lua state
};

/// AsyncFrameProcessor: Background thread for video encoding and PNG saving
/// Decouples frame capture from expensive encoding/disk operations
class AsyncFrameProcessor {
public:
    AsyncFrameProcessor(ModalityManager* modalityManager);
    ~AsyncFrameProcessor();

    /// Submit frame for async processing (clones texture internally)
    /// Returns immediately after cloning
    bool SubmitFrame(ID3D11Texture2D* texture, int modalityId, const std::string& imagePath,
                     ImageFormat imageFormat, bool saveToVideo, int width, int height, int jpegQuality = 95);

    /// Submit capture request for async processing
    /// Returns immediately, capture happens on background thread
    void SubmitCaptureRequest(CaptureRequest req);

    /// Start background worker thread
    void Start();

    /// Stop background worker thread and wait for completion
    void Stop();

private:
    void WorkerThread();
    ID3D11Texture2D* CloneTexture(ID3D11Texture2D* source);
    void ProcessFrame(const FrameTask& task);
    void ProcessCaptureRequest(const CaptureRequest& req);
    void SaveTextureToPNG(ID3D11Texture2D* texture, const std::string& path, int width, int height);
    void SaveTextureToIndexedPNG(ID3D11Texture2D* texture, const std::string& path, int width, int height);
    void SaveTextureToJPEG(ID3D11Texture2D* texture, const std::string& path, int width, int height, int quality);

    ModalityManager* modalityManager;
    std::queue<FrameTask> taskQueue;
    std::mutex queueMutex;
    std::condition_variable queueCV;
    std::thread* workerThread;
    bool running;

    // Async capture queue
    std::queue<CaptureRequest> captureQueue;
    std::mutex captureMutex;

    // D3D11 device for texture cloning (created on first use)
    ID3D11Device* device;
    ID3D11DeviceContext* context;
};
