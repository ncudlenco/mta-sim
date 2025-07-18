-- Test Runner
-- Main entry point for running tests

print("=== MTA Story Simulation Test Runner ===")
print("Testing chain ID functionality and object consistency...")

-- Load the test framework
local success, error = pcall(function()
    dofile("test_framework/test_chain_id.lua")
end)

if not success then
    print("ERROR: Test execution failed!")
    print("Error details: " .. tostring(error))
    return false
else
    print("Tests completed successfully!")
    return true
end
