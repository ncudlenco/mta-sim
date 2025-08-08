# GraphStory.lua

## Purpose
This is the core graph processing engine that loads JSON story graphs and translates them into executable 3D game scenarios. It handles episode validation, object-action mapping, temporal constraint processing, and coordinates the entire story simulation workflow.

## Key Functions/Classes

### Core Class: GraphStory
Inherits from `StoryBase` and orchestrates the entire graph-to-simulation translation process.

### Primary Methods

**Graph Loading & Initialization:**
- **`init()`** - Loads JSON graph from `LOAD_FROM_GRAPH` global, parses temporal constraints
- **`Play()`** - Main execution method that validates episodes and starts story simulation
- **`End()`** - Cleanup and disposal of story resources

**Episode Validation & Selection:**
- **`GetValidEpisodes(requiredActors)`** - Finds episodes that can satisfy all graph requirements
- **`ExploreValidEpisodesSubset()`** - Recursive episode validation with linked episode exploration
- **`GetMaxCoveringEpisode()`** - Greedy selection of episode covering maximum requirements
- **`ValidateEpisode()`** - Checks if episode contains required locations, objects, and actions

**Graph-to-Action Mapping:**
- **`MapObjectsActionsAndPoi()`** - Maps abstract graph objects to concrete 3D game objects
- **`FindAllValidActionsAndPois()`** - Finds POI chains that match graph event sequences
- **`MatchEventAndAction()`** - Verifies action/event compatibility and creates mappings
- **`AggregatePoiData()`** - Consolidates mapping data from multiple POIs

**Temporal Navigation:**
- **`GetNextEvent(eventId, actorId)`** - Traverses temporal graph forward
- **`FindPreviousEventId(eventId, actorId)`** - Traverses temporal graph backward
- **`IsEventInNextTemporal()`** - Checks temporal relationship existence

**Action Processing:**
- **`ProcessActions(graphActors)`** - Creates action queues and spawns actors at starting locations

## Dependencies
- **StoryBase** - Base story functionality
- **MetaEpisode** - Multi-episode wrapper for complex stories
- **DynamicEpisode** - JSON-based episode loading
- **Logger** - Story execution logging
- **ActionsOrchestrator** (used by episodes) - Action coordination

## Data Flow

1. **Graph Loading** → JSON parsing → Temporal constraint extraction
2. **Actor Requirements** → Extract required actors from 'Exists' events
3. **Episode Validation** → Test each episode against requirements
4. **Episode Selection** → Choose valid episode subset (with linking support)
5. **Object-Action Mapping** → Map graph entities to 3D game objects
6. **Story Execution** → Initialize MetaEpisode and start simulation

## Key Globals
- **`LOAD_FROM_GRAPH`** - Path to input JSON story graph
- **`MAX_STORY_TIME`** - Maximum simulation duration
- **`DEBUG_VALIDATION`** - Detailed validation logging
- **`WIDTH_RESOLUTION`** / **`HEIGHT_RESOLUTION`** - Video output settings

## Architecture Notes

### Graph Structure
- **Events**: Represent actions (`Move`, `Drink`, `Sleep`) or existence (`Exists`)
- **Entities**: [ActorId, ObjectId] pairs defining who does what with what
- **Temporal**: Defines event sequencing with `next`, `after`, `before`, `starts_with`, `concurrent`
- **Properties**: Actor attributes (gender, name) and object types

### Episode Validation Strategy
Uses recursive exploration with backtracking:
1. Extract requirements from graph (locations, objects, actions)
2. For each episode, calculate coverage score
3. Select maximum covering episode
4. Recursively explore linked episodes
5. Return first valid episode subset that covers all requirements

### Object-Action Mapping Algorithm
Critical for graph-to-simulation translation:
1. **Object-Centric**: Start with required objects, find events using them
2. **Chain Mapping**: Map sequential actions/events in same location until `Move`
3. **Bidirectional**: Map both forward and backward temporal chains
4. **One-to-Many**: Each graph object maps to multiple simulator objects for flexibility

### Chain ID System
Prevents object conflicts by tracking action sequences:
- Each mapped POI gets unique `chainId`
- Ensures consistent object usage across action chains
- Supports multiple actors using same object types in different locations

### Spawnable vs Fixed Objects
- **SpawnableObjects**: Created at runtime (`Cigarette`, `MobilePhone`)
- **PickUpableObjects**: Can be moved between locations
- **Fixed Objects**: Permanent scene objects (`Bed`, `Chair`)

### Meta-Episode Architecture
Supports multi-location stories through episode linking:
- POIs can specify `episodeLinks` to other episodes
- System automatically includes linked episodes in validation
- MetaEpisode wrapper provides unified interface

### Temporal Constraint Processing
- Extracts `temporal` section from graph
- Supports complex relationships: `after`, `before`, `starts_with`, `concurrent`
- Creates action queues for each actor
- Delegates constraint satisfaction to ActionsOrchestrator

### Critical Validation Points
1. **Actor Requirements**: Must have `Exists` events with gender/name
2. **Location Matching**: Graph locations must exist in episode regions
3. **Object Availability**: Required objects must exist or be spawnable
4. **Action Chains**: Sequential actions must form valid chains without breaks
5. **Temporal Consistency**: All temporal constraints must be satisfiable

This system represents a sophisticated graph-to-3D-simulation translation engine with advanced temporal synchronization, object mapping, and multi-episode story support.