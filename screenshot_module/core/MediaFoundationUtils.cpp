#include "MediaFoundationUtils.h"
#include "DebugLog.h"
#include <sstream>
#include <iomanip>

namespace MediaFoundationUtils {

static bool g_mfInitialized = false;

bool Initialize() {
    DEBUG_LOG_FMT("MediaFoundationUtils", "Initialize: already initialized=%d", g_mfInitialized);

    if (g_mfInitialized) {
        DEBUG_LOG("MediaFoundationUtils", "Initialize: skipping, already initialized");
        return true;
    }

    HRESULT hr = MFStartup(MF_VERSION);
    if (SUCCEEDED(hr)) {
        g_mfInitialized = true;
        DEBUG_LOG("MediaFoundationUtils", "Initialize: MFStartup success");
        return true;
    }

    DEBUG_LOG_HR("MediaFoundationUtils", "MFStartup", hr);
    return false;
}

void Shutdown() {
    DEBUG_LOG_FMT("MediaFoundationUtils", "Shutdown: initialized=%d", g_mfInitialized);

    if (g_mfInitialized) {
        MFShutdown();
        g_mfInitialized = false;
        DEBUG_LOG("MediaFoundationUtils", "Shutdown: MFShutdown complete");
    } else {
        DEBUG_LOG("MediaFoundationUtils", "Shutdown: skipping, not initialized");
    }
}

std::string HResultToString(HRESULT hr) {
    std::ostringstream oss;
    oss << "0x" << std::hex << std::setw(8) << std::setfill('0') << hr;
    return oss.str();
}

std::string GuidToString(const GUID& guid) {
    std::ostringstream oss;
    oss << std::hex << std::setfill('0')
        << std::setw(8) << guid.Data1 << "-"
        << std::setw(4) << guid.Data2 << "-"
        << std::setw(4) << guid.Data3 << "-"
        << std::setw(2) << (int)guid.Data4[0]
        << std::setw(2) << (int)guid.Data4[1] << "-"
        << std::setw(2) << (int)guid.Data4[2]
        << std::setw(2) << (int)guid.Data4[3]
        << std::setw(2) << (int)guid.Data4[4]
        << std::setw(2) << (int)guid.Data4[5]
        << std::setw(2) << (int)guid.Data4[6]
        << std::setw(2) << (int)guid.Data4[7];
    return oss.str();
}

} // namespace MediaFoundationUtils
