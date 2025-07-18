-- Lua Test Runner Script
-- This script can be run directly with a Lua interpreter

-- Set up the path to find modules
package.path = package.path .. ";./?.lua"

-- Change to the correct directory
local current_dir = debug.getinfo(1).source:match("@?(.*[/\\])")
if current_dir then
    package.path = current_dir .. "?.lua;" .. package.path
end

-- Load and run the tests
print("Starting Lua test runner...")
local success, result = pcall(function()
    return dofile("test_framework/run_tests.lua")
end)

if success then
    print("Test runner completed successfully!")
    os.exit(result and 0 or 1)
else
    print("Test runner failed with error: " .. tostring(result))
    os.exit(1)
end
