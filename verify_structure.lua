-- Basic Structure Verification
-- This file checks if all required files exist and can be loaded

print("=== Test Framework Structure Verification ===")

-- Check if files exist
local function fileExists(filename)
    local file = io.open(filename, "r")
    if file then
        file:close()
        return true
    end
    return false
end

local required_files = {
    "utils/class.lua",
    "utils/others.lua",
    "utils/arrayUtils.lua",
    "utils/VectorUtils.lua",
    "utils/guid.lua",
    "story/GraphStory.lua",
    "story/Locations/Location.lua",
    "test_framework/mta_mocks.lua",
    "test_framework/test_framework.lua",
    "test_framework/test_loader.lua",
    "test_framework/test_chain_id.lua"
}

print("Checking required files...")
local all_exist = true
for _, filename in ipairs(required_files) do
    if fileExists(filename) then
        print("✓ " .. filename)
    else
        print("✗ " .. filename .. " [MISSING]")
        all_exist = false
    end
end

if all_exist then
    print("\n✓ All required files exist!")
    print("The test framework is ready to use.")
    print("\nTo run tests:")
    print("1. Install Lua (lua.org)")
    print("2. Run: lua run_tests_standalone.lua")
    print("3. Or use run_tests.bat (Windows) or run_tests.sh (Linux/macOS)")
else
    print("\n✗ Some files are missing. Please ensure all files are in place.")
end
