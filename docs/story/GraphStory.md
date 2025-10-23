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
- **Spatial**: Defines object positional relationships with `on`, `near`, `left`, `right`, `in_front`, `behind`
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

### Chain ID System (Updated)
**Unique Chain ID Generation:** Each POI gets a globally unique, meaningful chain ID:
- **Format**: `"POI_Description_Region_LocationId_GlobalCounter"`
- **Examples**: `"bedroom bed right_bedroom_14_house9_3"`, `"next to armchair_bedroom_38_house9_86"`
- **Global Counter**: Ensures absolute uniqueness across all POIs (`globalChainCounter`)

**Chain ID Assignment Process:**
1. **FindAllValidActionsAndPois()** - Captures POI metadata (Description, Region, LocationId)
2. **AggregatePoiData()** - Creates unique chain IDs using POI data + global counter
3. **Location.lua** - Assigns actors to chain IDs based on selected POI

**Conflict Prevention:**
- Prevents multiple actors from using the same POI simultaneously
- Supports multiple actors using different POIs of the same object type
- Enables proper distribution across dual-POI objects (e.g., left/right bed sides)

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

### Spatial Constraint Processing
**Purpose:** Enforce positional relationships between objects to synchronize multi-actor scenarios.

**Graph Schema:**
```json
"spatial": {
  "laptop": {
    "relations": [
      {"target": "Desk", "type": "on"}
    ]
  },
  "officeChair": {
    "relations": [
      {"target": "Desk", "type": "behind"}
    ]
  }
}
```

**Parsing ([GraphStory.lua:121-127](../src/story/GraphStory.lua#L121-L127)):**
- Loads `spatial` section during graph initialization
- Stores in `CURRENT_STORY.spatial`
- Initializes `CURRENT_STORY.materializedObjects = {}` for runtime tracking

**Supported Relation Types (Global Coordinate System):**
- **`on`** - Source on top of target (vertical + horizontal proximity)
- **`near`** - Source near target (3D Euclidean distance ≤ 5.0 units)
- **`left`** - Source to the left of target (45° to 135°)
- **`right`** - Source to the right of target (-135° to -45°)
- **`in_front`** - Source in front of target (-45° to 45°)
- **`behind`** - Source behind target (beyond ±135°)

**Runtime Enforcement:**
1. **Object Materialization** - When actor selects location, object positions recorded
2. **Constraint Validation** - Subsequent actors validate candidates against materialized objects
3. **Multi-Actor Synchronization** - Ensures objects satisfy spatial relations (e.g., "3 chairs at same desk")

**Implementation:**
- Validation logic in [SpatialCoordinator.lua](../utils/SpatialCoordinator.md)
- Integrated into [Location.lua](Locations/Location.md) candidate selection
- Lazy enforcement - constraints only checked when target objects materialized

### Critical Validation Points
1. **Actor Requirements**: Must have `Exists` events with gender/name
2. **Location Matching**: Graph locations must exist in episode regions
3. **Object Availability**: Required objects must exist or be spawnable
4. **Action Chains**: Sequential actions must form valid chains without breaks
5. **Temporal Consistency**: All temporal constraints must be satisfiable
6. **Spatial Consistency**: Object positions must satisfy spatial relations when materialized

This system represents a sophisticated graph-to-3D-simulation translation engine with advanced temporal synchronization, object mapping, and multi-episode story support.