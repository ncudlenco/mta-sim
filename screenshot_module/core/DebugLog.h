#ifndef DEBUG_LOG_H
#define DEBUG_LOG_H

#include <cstdio>
#include <cstdarg>
#include <windows.h>

// Feature flag to enable/disable debug tracing
// Set to true to enable comprehensive debug logging
extern bool ENABLE_SCREENSHOT_MODULE_DEBUG;

namespace DebugLog {

inline void Log(const char* component, const char* message) {
    if (!ENABLE_SCREENSHOT_MODULE_DEBUG) return;

    // Thread-safe file logging
    FILE* f = fopen("screenshot_module_debug.log", "a");
    if (f) {
        fprintf(f, "[%s] %s\n", component, message);
        fclose(f);
    }

    // Console output
    printf("[%s] %s\n", component, message);

    // OutputDebugString for VS debugger
    char buffer[1024];
    snprintf(buffer, sizeof(buffer), "[%s] %s\n", component, message);
    OutputDebugStringA(buffer);
}

inline void LogFormat(const char* component, const char* format, ...) {
    if (!ENABLE_SCREENSHOT_MODULE_DEBUG) return;

    char buffer[512];
    va_list args;
    va_start(args, format);
    vsnprintf(buffer, sizeof(buffer), format, args);
    va_end(args);

    Log(component, buffer);
}

inline void LogHResult(const char* component, const char* operation, HRESULT hr) {
    if (!ENABLE_SCREENSHOT_MODULE_DEBUG) return;

    LogFormat(component, "%s failed: HRESULT=0x%08X", operation, hr);
}

} // namespace DebugLog

// Convenience macros
#define DEBUG_LOG(component, message) DebugLog::Log(component, message)
#define DEBUG_LOG_FMT(component, format, ...) DebugLog::LogFormat(component, format, __VA_ARGS__)
#define DEBUG_LOG_HR(component, operation, hr) DebugLog::LogHResult(component, operation, hr)

#endif // DEBUG_LOG_H
