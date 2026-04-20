#include "ModalityManager.h"
#include "DebugLog.h"

ModalityManager::ModalityManager() {
    DEBUG_LOG("ModalityManager", "Constructor called");
}

ModalityManager::~ModalityManager() {
    DEBUG_LOG("ModalityManager", "Destructor called");
    StopAll();
}

bool ModalityManager::StartRecording(int modalityId, const std::string& path, int w, int h, int fps, int bitrate) {
    DEBUG_LOG_FMT("ModalityManager", "StartRecording: modalityId=%d, path=%s, dims=%dx%d, fps=%d, bitrate=%d",
        modalityId, path.c_str(), w, h, fps, bitrate);

    std::lock_guard<std::mutex> lock(encoderMutex);

    // Check if already recording for this modality
    if (encoders.find(modalityId) != encoders.end()) {
        DEBUG_LOG_FMT("ModalityManager", "StartRecording: modality %d already recording", modalityId);
        return false;  // Already recording
    }

    // Create new encoder
    VideoEncoder* encoder = new VideoEncoder();
    if (!encoder->Start(path, w, h, fps, bitrate)) {
        DEBUG_LOG_FMT("ModalityManager", "StartRecording: failed to start encoder for modality %d", modalityId);
        delete encoder;
        return false;
    }

    encoders[modalityId] = encoder;
    targetDimensions[modalityId] = std::make_pair(w, h);  // Store target dimensions
    DEBUG_LOG_FMT("ModalityManager", "StartRecording: success for modality %d, stored target dims %dx%d", modalityId, w, h);
    return true;
}

bool ModalityManager::AddFrame(int modalityId, ID3D11Texture2D* texture) {
    DEBUG_LOG_FMT("ModalityManager", "AddFrame (texture): modalityId=%d", modalityId);

    std::lock_guard<std::mutex> lock(encoderMutex);

    auto it = encoders.find(modalityId);
    if (it == encoders.end()) {
        DEBUG_LOG_FMT("ModalityManager", "AddFrame: no encoder for modality %d", modalityId);
        return false;  // No encoder for this modality
    }

    bool success = it->second->AddFrame(texture);
    DEBUG_LOG_FMT("ModalityManager", "AddFrame (texture): modalityId=%d, success=%d", modalityId, success);
    return success;
}

bool ModalityManager::AddFrame(int modalityId, void* pixels, int w, int h, int pitch, GUID format) {
    DEBUG_LOG_FMT("ModalityManager", "AddFrame (pixels): modalityId=%d, dims=%dx%d, pitch=%d", modalityId, w, h, pitch);

    std::lock_guard<std::mutex> lock(encoderMutex);

    auto it = encoders.find(modalityId);
    if (it == encoders.end()) {
        DEBUG_LOG_FMT("ModalityManager", "AddFrame: no encoder for modality %d", modalityId);
        return false;  // No encoder for this modality
    }

    bool success = it->second->AddFrame(pixels, w, h, pitch, format);
    DEBUG_LOG_FMT("ModalityManager", "AddFrame (pixels): modalityId=%d, success=%d", modalityId, success);
    return success;
}

bool ModalityManager::StopRecording(int modalityId) {
    DEBUG_LOG_FMT("ModalityManager", "StopRecording: modalityId=%d", modalityId);

    std::lock_guard<std::mutex> lock(encoderMutex);

    auto it = encoders.find(modalityId);
    if (it == encoders.end()) {
        DEBUG_LOG_FMT("ModalityManager", "StopRecording: no encoder for modality %d", modalityId);
        return false;  // No encoder for this modality
    }

    it->second->Stop();
    delete it->second;
    encoders.erase(it);
    targetDimensions.erase(modalityId);  // Clean up dimensions

    DEBUG_LOG_FMT("ModalityManager", "StopRecording: success for modality %d", modalityId);
    return true;
}

bool ModalityManager::IsRecording(int modalityId) const {
    std::lock_guard<std::mutex> lock(encoderMutex);
    bool recording = encoders.find(modalityId) != encoders.end();
    DEBUG_LOG_FMT("ModalityManager", "IsRecording: modalityId=%d, recording=%d", modalityId, recording);
    return recording;
}

void ModalityManager::StopAll() {
    DEBUG_LOG_FMT("ModalityManager", "StopAll: stopping %zu encoder(s)", encoders.size());

    std::lock_guard<std::mutex> lock(encoderMutex);

    for (auto& pair : encoders) {
        DEBUG_LOG_FMT("ModalityManager", "StopAll: stopping modality %d", pair.first);
        pair.second->Stop();
        delete pair.second;
    }
    encoders.clear();
    targetDimensions.clear();  // Clean up all dimensions

    DEBUG_LOG("ModalityManager", "StopAll: complete");
}

bool ModalityManager::GetTargetDimensions(int modalityId, int& outWidth, int& outHeight) const {
    std::lock_guard<std::mutex> lock(encoderMutex);

    auto it = targetDimensions.find(modalityId);
    if (it == targetDimensions.end()) {
        outWidth = 0;
        outHeight = 0;
        DEBUG_LOG_FMT("ModalityManager", "GetTargetDimensions: no dimensions for modality %d", modalityId);
        return false;
    }

    outWidth = it->second.first;
    outHeight = it->second.second;
    DEBUG_LOG_FMT("ModalityManager", "GetTargetDimensions: modality %d -> %dx%d", modalityId, outWidth, outHeight);
    return true;
}

std::map<int, std::pair<int, int>> ModalityManager::GetAllTargetDimensions() const {
    std::lock_guard<std::mutex> lock(encoderMutex);
    return targetDimensions;
}
