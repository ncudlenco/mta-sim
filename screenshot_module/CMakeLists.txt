cmake_minimum_required(VERSION 3.16)
project(screenshot_module)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Set output directory to MTA modules folder
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/../../../modules")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/../../../modules")

find_path(LUA_INCLUDE_DIR lua.h
    PATHS
    "C:/Program Files (x86)/Lua/include"
    "C:/lua/include"
    "${CMAKE_CURRENT_SOURCE_DIR}/lua/include"
    PATH_SUFFIXES 5.1 lua lua5.1 lua51
)

find_library(LUA_LIBRARY
    NAMES 5.1 lua lua5.1 lua51
    PATHS
    "C:/Program Files (x86)/Lua/lib"
    "C:/lua/lib"
    "${CMAKE_CURRENT_SOURCE_DIR}/lua/lib"
)

# Create the module
add_library(screenshot_module SHARED main.cpp)

# Set proper output name for MTA module
set_target_properties(screenshot_module PROPERTIES
    OUTPUT_NAME "screenshot_win32"
    PREFIX ""
    SUFFIX ".dll"
)

# Include directories
target_include_directories(screenshot_module PRIVATE ${LUA_INCLUDE_DIR})

# Link libraries
target_link_libraries(screenshot_module
    ${LUA_LIBRARY}
    gdiplus
    user32
    gdi32
)

# Compiler definitions
target_compile_definitions(screenshot_module PRIVATE
    WIN32_LEAN_AND_MEAN
    NOMINMAX
)

# Compiler flags
if(MSVC)
    target_compile_options(screenshot_module PRIVATE /W4)
else()
    target_compile_options(screenshot_module PRIVATE -Wall -Wextra)
endif()

# Post-build: copy to MTA modules directory if different
add_custom_command(TARGET screenshot_module POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E echo "Screenshot module built successfully"
    COMMAND ${CMAKE_COMMAND} -E echo "Copy screenshot_win32.dll to your MTA modules directory"
)