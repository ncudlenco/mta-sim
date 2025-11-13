# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This project represents a pioneering effort to bridge the gap between text-to-video and video-to-text generation by introducing graph-like structures for objects, actors, and their interactions. Initiated 5-7 years ago (before the current LLM and video generation era), the project tackles the fundamental challenge of creating structured interaction data for deep learning applications.

### The Core Challenge

The absence of structured multi-agent interaction data led to the creation of this comprehensive system using GTA San Andreas as a simulation environment. The project involves two primary workflows:

1. **Data Collection**: Automating scenarios where NPCs interact with objects and each other, logging these interactions as structured graphs
2. **Graph-to-Video Generation**: Starting from predefined graphs and mapping them to executable scenarios in the 3D game world

### Technical Complexity

The implementation revealed extraordinary complexity across multiple domains:

- **Geometry and Pathfinding**: Custom libraries for spatial reasoning and NPC navigation
- **Temporal Synchronization**: Complex async orchestration to precisely time when NPCs reach locations and perform actions
- **World Mapping**: Converting existing game locations to JSON structures without native API support (see `EpisodeCommands.lua`, `MappingCommands.lua`)
- **Template Systems**: Abstraction layers for objects and actions through Template and Supertemplate systems
- **Action Orchestration**: Sophisticated scheduling system for coordinating when actions begin and end
- **Object Mapping**: Dynamic mapping between abstract graph objects and concrete game objects

### Development Challenges

The project faces unique development constraints:
- **Lua Development**: Limited debugging capabilities without proper debugger support
- **MTA Engine Limitations**: Difficulty mocking the MTA engine for unit testing
- **Integration Testing**: Manual testing requiring 10+ minute cycles to start the engine and observe full scenario execution
- **Async Complexity**: Managing timing-dependent interactions in a game engine environment

This system represents one of the first attempts at creating a comprehensive graph-based narrative simulation engine for research into multi-agent story generation and video synthesis.

**For detailed technical development guidance, see the sections below.**

## Development Commands

**Testing:**
- In general, the testing framework doesn't work. It is incomplete and does not fully mock all the functionalities from MTA. I am testing now manually by running the game, connecting, using a specific graph (JSON file), and visual verification + reviewing the clientscript.log and server.log. The information below is true but in practice it is never used.
- `lua run_tests_standalone.lua` - Run all tests with standalone Lua interpreter - this doesn't work
- `run_tests.bat` (Windows) or `./run_tests.sh` (Linux/macOS) - Run tests with wrapper scripts that check for Lua availability
- Tests are located in `test_framework/` and use mock MTA functions for standalone testing

**Story Generation (Python):**
- `python story_generator/main.py` - Generate synthetic story graphs for testing

## Project Architecture

This is an **MTA San Andreas story simulation system** that generates and executes complex multi-actor interactive narratives in a 3D game environment.

### Core Components

**Graph-Based Story Engine (`story/GraphStory.lua`):**
- Processes JSON story graphs containing events, actors, objects, and temporal constraints
- Maps graph events to 3D simulator actions through episode validation
- Supports complex temporal relationships: after, before, starts_with, concurrent
- Handles multi-episode stories with location transitions

**Actions Orchestrator (`api/ActionsOrchestrator.lua`):**
- Coordinates multi-actor action execution with temporal constraints
- Manages context switching between different episodes/locations
- Handles concurrent and synchronized actions between multiple actors
- Queues actions awaiting constraint satisfaction

**Episode System:**
- Episodes define 3D environments with POIs (Points of Interest), objects, and available actions
- Dynamic episodes loaded from JSON files in `files/episodes/`
- Meta-episodes combine multiple connected episodes for complex stories
- Template system for reusable object interaction patterns

**Object and Action Mapping:**
- Maps abstract story objects to concrete 3D game objects
- Chain ID system ensures consistent object usage across actions
- Supports spawnable objects (cigarettes, phones) and fixed objects (furniture)
- Template-based object / possible actions definitions in `files/supertemplates/`

### Key Patterns

**Story Loading Flow:**
1. `GraphStory` loads JSON graph from `LOAD_FROM_GRAPH` global variable
2. Validates required actors, locations, objects against available episodes
3. Creates `MetaEpisode` wrapper for multi-episode stories
4. Maps graph events to simulator actions via `MapObjectsActionsAndPoi()`
5. Processes actions through `ActionsOrchestrator` with temporal constraints
6. Plans at runtime the choice of locations and actions through `Location`

**Action Execution:**
1. Actions enqueued with temporal constraints extracted from graph
2. Constraints validated (after, before, starts_with, concurrent)
3. Context switches handled for cross-episode actions
4. Camera management for spectator recording

**Testing Framework: incomplete and does not work**
- Mock MTA functions allow testing without game engine
- Chain ID consistency testing for object mappings
- Scenario-based tests for common story patterns

### File Organization

- `story/` - Core story execution engine and episode definitions
- `api/` - Interface classes and action orchestration
- `files/episodes/` - Episode definitions with POIs and object layouts
- `files/supertemplates/` - Reusable interaction templates
- `story_generator/` - Python tools for generating synthetic test stories
- `test_framework/` - Standalone testing infrastructure with MTA mocks - not working

### Critical Globals

- `CURRENT_STORY` - Active story instance
- `LOAD_FROM_GRAPH` - Path to input story graph JSON
- `DEBUG` - Enables detailed logging output
- Various debug flags for specific subsystems (e.g., `DEBUG_VALIDATION`, `DEBUG_ACTIONS_ORCHESTRATOR`)

The system is designed for research into multi-agent story simulation and supports both linear random stories and complex graph-based narratives with precise temporal control.

## Documentation Structure

This repository includes comprehensive documentation of the system architecture and implementation:

### Architecture Documentation
- **[System Architecture Overview](arch/system-overview.md)** - High-level system architecture with Mermaid diagrams
- **[Component Details](arch/component-details.md)** - Detailed component architecture and state machines
- **[Data Flow Architecture](arch/data-flow.md)** - Data flow patterns and processing pipelines

### Component Documentation
- **[Core System Files](docs/)** - Detailed documentation of all major system components:
  - **[ServerGlobals.md](docs/ServerGlobals.md)** - Global configuration and debug settings
  - **[ServerCommands.md](docs/ServerCommands.md)** - Development and debugging commands
  - **[story/GraphStory.md](docs/story/GraphStory.md)** - Main graph processing engine
  - **[api/ActionsOrchestrator.md](docs/api/ActionsOrchestrator.md)** - Action coordination and temporal synchronization
  - **[api/CameraHandler.md](docs/api/CameraHandler.md)** - Advanced camera synchronization and video capture management
  - **[story/Episodes/MetaEpisode.md](docs/story/Episodes/MetaEpisode.md)** - Multi-episode wrapper system
  - **[story/Locations/Location.md](docs/story/Locations/Location.md)** - Complex location management and action selection
  - **[client/EpisodeCommands.md](docs/client/EpisodeCommands.md)** - Interactive 3D episode development toolkit
  - **[client/MappingCommands.md](docs/client/MappingCommands.md)** - Pathfinding graph creation tools
  - **[client/Template.md](docs/client/Template.md)** - Modular content templates
  - **[client/Supertemplate.md](docs/client/Supertemplate.md)** - Template collection coordination
  - **[utils/README.md](docs/utils/README.md)** - Utility functions overview

### Key System Features

**Temporal Synchronization Engine**: The ActionsOrchestrator implements sophisticated multi-actor coordination with support for after/before relationships, concurrent execution, starts_with synchronization, and cross-episode context switching.

**Graph-to-Action Translation**: The GraphStory engine performs complex mapping from abstract story graphs to concrete 3D actions through chain-based object mapping, episode validation, and constraint extraction.

**Multi-Episode System**: MetaEpisode enables seamless transitions between different 3D environments with automatic cross-episode movement generation and unified actor distribution.

**Interactive Development Tools**: Real-time 3D editing capabilities for episodes, templates, and pathfinding networks with visual feedback and immediate JSON serialization.

**Advanced Object Mapping**: Chain ID system ensures consistent object usage across multiple actors while preventing conflicts and managing spawnable vs. fixed objects.

**Camera Synchronization Engine**: Sophisticated multi-spectator camera management with automatic focus switching, cross-episode context transitions, and coordinated fade effects for seamless video generation.

## Development guidelines
Any new development should follow best engineering practices as DRY, YAGNI, and SOLID principles. The functions must be documented in an LDoc compliant style [https://stevedonovan.github.io/ldoc/manual/doc.md.html].

We are using a custom class-like function located in utils/class.lua.

The overarching architecture should be designed in a way that makes it easy to isolate the core-engine logic from the simulation related business logic. With the idea in mind that this system is to be extended for other games as well. The very next milestone after the idea is fully proved for GTA:SA is to extend it for GTA V through FiveM.

Whenever you make a new change, do not reference anything from the previous state. Always document and write your code as if this is the solution and do not explain how it compares with a previous implementation or how it was previously implemented.

When doing ROOT CAUSE ANALYSIS: always look at the server logs, line by line, then ground the answers in code as well. Never make assumptions.