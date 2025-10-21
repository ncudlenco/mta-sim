#pragma once

#include <mfapi.h>
#include <mfidl.h>
#include <string>

/// MediaFoundationUtils: Media Foundation helpers and utilities
/// Core reusable component (game-agnostic)
namespace MediaFoundationUtils {
    /// Initialize Media Foundation library
    /// @return Success
    bool Initialize();

    /// Shutdown Media Foundation library
    void Shutdown();

    /// Convert HRESULT to error string
    /// @param hr HRESULT code
    /// @return Error description
    std::string HResultToString(HRESULT hr);

    /// Convert GUID to string
    /// @param guid GUID to convert
    /// @return String representation
    std::string GuidToString(const GUID& guid);
}
