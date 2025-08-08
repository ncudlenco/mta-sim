# ServerCommands.lua

## Purpose
This file provides MTA server-side command handlers for development, debugging, and testing of the story simulation system. It includes manual animation controls, spatial debugging tools, and pathfinding testing commands.

## Key Functions/Classes

### Animation Commands
- **`sit`** - Toggles sitting animation (`int_office.off_sit_in`)
- **`animation <lib> <name> <loop>`** - Sets custom animation with library/name parameters  
- **`clearanims`** - Removes all active animations
- **`eat`** - Toggles eating animation (`INT_OFFICE.OFF_Sit_Type_Loop`)
- **`getInBed`** - Toggles bed sleep animations (`INT_HOUSE.BED_In_L` / `BED_Out_L`)

### Development Utilities
- **`getCar`** - Spawns a test vehicle (ID 411) near player
- **`position`** - Outputs player's current world coordinates
- **`interior <id>`** - Changes player's interior dimension
- **`teleport <x> <y> <z> [interior]`** - Teleports player to coordinates

### Spatial Analysis Tools
- **`setTarget`** - Marks current position as reference point
- **`angle`** - Calculates rotation angle between player and target point
- **`marker <x> <y> <z>`** - Creates visual marker at coordinates
- **`projectPoint [x y z]`** - Projects point onto region plane, outputs distance calculations
- **`isPointInside [x y z]`** - Tests if point is inside current region boundaries

### Pathfinding System
- **`pathfinding settarget`** - Sets current position as pathfinding destination
- **`pathfinding start`** - Executes pathfinding from current position to target
- **`destinationReached()`** - Callback for waypoint navigation

## Dependencies
- **Timer** - For delayed execution and animation timing
- **Guid** - For unique identifier generation
- **Team** - For team/faction management
- **Location** class - For player positioning and teleportation
- **GetStory()** - Retrieves current story instance
- **loadPathGraph()** / **findShortestPathBetween()** - Pathfinding module functions

## Data Flow
1. **Animation Commands** → Direct MTA animation API calls with state tracking
2. **Spatial Commands** → Region system integration for boundary testing
3. **Pathfinding Commands** → External pathfinding module → Marker-based navigation
4. **Debug Output** → Console logging for development feedback

## Key Globals
- **`targetPoint`** - Stores reference position for angle calculations
- **`path`** - Array of waypoints for pathfinding navigation
- **`debugMarkers`** - Collection of visual debugging markers
- **`pathFindingTarget`** - Destination point for pathfinding tests
- **`DEBUG`** - Controls debug output verbosity

## Architecture Notes

### Manual Testing Integration
This command system serves as a bridge between automated story execution and manual testing:
- Animation commands allow developers to test individual actor behaviors
- Spatial commands help debug region boundaries and positioning
- Pathfinding commands test navigation between story locations

### Region System Integration
The spatial analysis commands (`projectPoint`, `isPointInside`) directly interface with the story's region system:
- Access current story through `GetStory(thePlayer)`
- Query region boundaries using `IsPointInside()` and plane projection
- Calculate distances to region planes for collision detection

### Pathfinding Development
The pathfinding commands demonstrate the system's navigation capabilities:
- Loads graph data from JSON files (`files/paths/house8.json`)
- Uses external pathfinding module for route calculation
- Creates marker-based waypoint navigation with collision detection
- Includes visual debugging markers for path visualization

### State Management
Commands track player states using MTA's data system:
- `sitting`, `eating`, `sleeping` flags prevent animation conflicts
- `currentRegionId` links players to story regions
- Interior settings maintain spatial consistency

This file represents a comprehensive debugging and development toolkit that provides manual control over all aspects of the automated story simulation system.