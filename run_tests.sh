#!/bin/bash

echo "=== MTA Story Simulation Test Runner ==="
echo

# Check if Lua is available
if ! command -v lua &> /dev/null; then
    echo "ERROR: Lua interpreter not found in PATH"
    echo "Please install Lua. On Ubuntu/Debian: sudo apt-get install lua5.3"
    echo "On macOS with Homebrew: brew install lua"
    exit 1
fi

# Change to the script directory
cd "$(dirname "$0")"

# Run the tests
echo "Running tests..."
echo
lua run_tests_standalone.lua

if [ $? -eq 0 ]; then
    echo "=== ALL TESTS PASSED ==="
else
    echo "=== SOME TESTS FAILED ==="
fi
