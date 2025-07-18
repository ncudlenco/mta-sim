# MTA Story Simulation Test Framework

This test framework allows you to test your MTA story simulation logic without requiring the actual MTA San Andreas game to be running.

## Features

- **Mock MTA Functions**: Complete mock implementations of MTA functions like `Timer`, `player:spawn`, `player:setAnimation`, etc. [incomplete]
- **Object Consistency Testing**: Specifically designed to test chain ID functionality and object consistency
- **Scenario Testing**: Pre-built test scenarios for common use cases
- **Standalone Execution**: Can be run with just a Lua interpreter, no game required

## Quick Start

### Prerequisites
- Lua 5.1 or higher (download from [lua.org](https://www.lua.org/download.html))

### Running Tests

**Windows:**
```batch
run_tests.bat
```

**Linux/macOS:**
```bash
chmod +x run_tests.sh
./run_tests.sh
```

**Manual (any platform):**
```bash
lua run_tests_standalone.lua
```

## Test Scenarios

### 1. Single Sofa Test
Tests the scenario where one sofa exists in a room and two actors must sit on the same sofa.

- **Expected Behavior**: Both actors should be assigned to the same chain ID, ensuring they use the same sofa object
- **Tests**: Chain ID consistency, object mapping, location selection

### 2. Multiple Chairs Kitchen Test
Tests the scenario where multiple chairs exist next to a table and two people must sit, eat, then stand up using different chairs simultaneously.

- **Expected Behavior**: Each actor gets assigned to a different chair but maintains consistency within their action chain
- **Tests**: Different chain IDs for different objects, simultaneous actions, temporal consistency

### 3. Chain ID Propagation Test
Tests the mechanism that propagates chain IDs from locations to players.

- **Expected Behavior**: Once a player is assigned a chain ID, they should consistently use objects from that chain
- **Tests**: Chain ID assignment, object selection logic, consistency across actions

## Architecture

### Core Components

1. **`mta_mocks.lua`**: Mock implementations of all MTA functions
2. **`test_framework.lua`**: Core testing framework with assertions and utilities
3. **`test_loader.lua`**: Loads all required dependencies for testing
4. **`test_chain_id.lua`**: Specific tests for chain ID functionality

### Mock System

The mock system provides:
- Mock players with all required methods (`spawn`, `setAnimation`, `setData`, etc.)
- Mock objects with collision and data management
- Mock timers that execute immediately for testing
- Mock Vector3 math operations
- Console output capture

### Test Framework

The test framework provides:
- Assertion methods (`assertEqual`, `assertNotNil`, `assertGreater`, etc.)
- Test organization and execution
- Detailed logging and error reporting
- Test scenario builders for common objects and locations

## Adding New Tests

### Basic Test Structure

```lua
TEST:test("My Test Name", function()
    -- Setup
    local player = createTestPlayer("actor1", "TestActor")
    local location = TEST:createTestLocation(0, 0, 0, 0, 0, "TestLocation")

    -- Execute
    location:SpawnPlayerHere(player, false)

    -- Verify
    TEST:assertEqual(location.LocationId, player:getData('locationId'), "Player should be at location")
    TEST:assert(location.isBusy, "Location should be busy")
end)
```

### Creating Test Objects

```lua
-- Create a test episode
local episode = TEST:createTestEpisode("MyEpisode", 0)

-- Create a test region
local region = TEST:createTestRegion("MyRegion", episode)

-- Create a test location
local location = TEST:createTestLocation(x, y, z, angle, interior, "Description", region)

-- Create a test object
local object = TEST:createTestObject("id", "name", "type", {x=0, y=0, z=0})

-- Create a test action
local action = TEST:createTestAction("ActionName", player, object, location)
```

## Understanding the Output

The test framework provides detailed output:

```
[TEST] === Testing Single Sofa with Two Actors ===
[TEST] ✓ Mapping should succeed
[TEST] ✓ Sofa should be mapped in eventObjectMap
[TEST] ✓ Event1 should be mapped in poiMap
[TEST] Chain ID for sofa: 1
[TEST] ✓ All sofa mappings should have same chain ID
[SUCCESS] PASSED: Single Sofa Two Actors
```

## Troubleshooting

### Common Issues

1. **"attempt to call a nil value"**: Usually means a dependency wasn't loaded properly. Check that all required files exist and are being loaded in the correct order.

2. **"Lua interpreter not found"**: Install Lua and ensure it's in your system PATH.

3. **"No such file or directory"**: Ensure you're running the tests from the correct directory (the sv2l folder).

### Debug Mode

Set `TEST.verbose = true` in your test files to get more detailed output about what's happening during test execution.

## Current Limitations

1. **Pathfinding**: The mock system doesn't implement complex pathfinding logic
2. **Timing**: All timers execute immediately rather than respecting actual time intervals
3. **Physics**: No collision detection or physics simulation
4. **Graphics**: No visual representation of objects or actions

## Contributing

When adding new tests:

1. Follow the existing naming conventions
2. Include both positive and negative test cases
3. Add detailed assertions with meaningful messages
4. Test edge cases and error conditions
5. Update this README if adding new test scenarios

## Integration with Main Code

The test framework is designed to work with your existing codebase without modification. It:

- Loads all your actual game logic files
- Provides mock implementations only for MTA-specific functions
- Preserves all your business logic and algorithms
- Allows testing of complex scenarios without game dependencies

This means you can be confident that if your tests pass, your logic will work correctly in the actual game environment.
