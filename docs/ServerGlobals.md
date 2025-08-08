# ServerGlobals.lua

## Purpose
This file defines the global configuration and state variables for the MTA San Andreas story simulation system. It serves as the central configuration hub that controls debugging, simulation parameters, and story graph input sources.

## Key Configuration Variables

### Core System State
- **`CURRENT_STORY`** - References the currently active story instance
- **`SCREENSHOTS`** - Table storing screenshot data during simulation
- **`MAX_ACTIONS`** - Maximum number of actions allowed (10,000)
- **`MAX_STORY_TIME`** - Maximum simulation time in seconds (1,200 = 20 minutes)
- **`ANIMATION_SPEED`** - Controls animation playback speed (1.0 = normal)
- **`LOG_FREQUENCY`** - Screenshot/logging frequency based on animation speed
- **`WIDTH_RESOLUTION`** / **`HEIGHT_RESOLUTION`** - Video output resolution (1920x1080)

### Debug Configuration
Extensive debugging flags for different subsystems:
- **`DEBUG`** - Master debug flag (currently true)
- **`DEBUG_VALIDATION`** - Story graph validation debugging
- **`DEBUG_ACTIONS_ORCHESTRATOR`** - Action coordination debugging
- **`DEBUG_METAEPISODE`** - Multi-episode story debugging
- **`DEBUG_LOCATION_CANDIDATES`** - Location selection debugging
- **`DEBUG_PATHFINDING`** - Movement and navigation debugging
- **`DEBUG_CAMERA`** - Camera control debugging
- And many more subsystem-specific flags

### Simulation Modes
- **`SIMULATION_MODE`** - Controls whether system runs in automated simulation mode (true)
- **`LOG_DATA`** - Whether to save images and logs (false in simulation mode)
- **`STATIC_CAMERA`** - Uses fixed camera positions for consistent recording
- **`FREE_ROAM`** - Allows manual camera control (opposite of simulation mode)
- **`DEFINING_EPISODES`** - Development mode for creating new episodes

### Story Input Configuration
- **`LOAD_FROM_GRAPH`** - Whether to load stories from JSON graph files (true)
- **`INPUT_GRAPHS`** - Array of story graph file paths to process
- **`SPECTATORS`** - Table for managing spectator/camera entities

## Data Flow
This file is loaded first and provides configuration to all other system components:
1. Core story engine (`GraphStory.lua`) reads `LOAD_FROM_GRAPH` and `INPUT_GRAPHS`
2. Debug flags control logging verbosity across all modules
3. Simulation parameters affect action execution timing and camera behavior
4. Resolution settings determine video output format

## Architecture Notes

### Graph Selection Strategy
The `INPUT_GRAPHS` array contains hundreds of commented-out test cases with success/failure annotations. This indicates:
- Systematic testing of different story patterns
- Documentation of known limitations (missing objects, unsupported interactions)
- Active development focus on complex temporal synchronization (`c10_sync.json`)

### Debug Granularity
The extensive debug flag system allows fine-grained control over logging for different subsystems, essential for debugging complex multi-agent temporal synchronization issues.

### Development vs. Production Modes
The system supports multiple operational modes:
- **Simulation Mode**: Automated story execution with fixed cameras for video generation
- **Free Roam Mode**: Manual exploration and episode development
- **Defining Episodes Mode**: Content creation workflow

### Commented TODO Items
The file contains extensive TODO comments documenting:
- Known issues with specific story graphs
- Missing object templates and supertemplates
- Episode compatibility problems
- Temporal synchronization challenges

This serves as both configuration and development documentation, showing the system's evolution and current limitations.