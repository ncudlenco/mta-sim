# Location.lua

## Purpose
This is the core location management class that represents Points of Interest (POI) in the 3D world. It handles actor spawning, action selection, graph event processing, location candidate evaluation, and complex multi-actor synchronization for story execution.

## Key Functions/Classes

### Core Class: Location
Inherits from `StoryLocationBase` and represents a specific point in 3D space where actions can be performed.

### Primary Methods

**Core Functionality:**
- **`init(x, y, z, angle, interior, description, region, compact, log, episodeLinks)`** - Constructor with 3D coordinates and episode linking
- **`SpawnPlayerHere(player, spectate)`** - Spawns actor at location with optional spectator mode
- **`GetNextValidAction(player)`** - Main action selection logic with graph processing
- **`ProcessNextAction(player)`** - Processes graph events and creates action chains

**Graph Processing:**
- **`GetMappedEventObjectId(eventObjectId, playerChainId)`** - Maps graph objects to simulator objects using chain IDs
- **`InstantiateAction(event, player, location, object)`** - Creates specific action instances from graph events

**Action Selection:**
- **`GetNextRandomValidAction(player)`** - Legacy random action selection for non-graph stories
- Location candidate evaluation with complex multi-constraint validation

**Serialization:**
- **`Serialize(episode, relativePosition, objects, locations, mainPOI, saveMainPoiRelative)`** - Converts location to JSON with dependency tracking

**Data Management:**
- **`getData(key)`** / **`setData(key, value)`** - Key-value metadata storage

## Dependencies
- **StoryLocationBase** - Base location functionality
- **CURRENT_STORY** - Global story instance
- **Vector3** - 3D coordinate system
- Various action classes (Move, Wait, HandShake, Kiss, etc.)
- Episode and region systems

## Data Flow

1. **Graph Event Processing** → Extract next event for actor
2. **Location Candidate Evaluation** → Find valid POIs for event
3. **Object Mapping** → Map graph objects to simulator objects
4. **Action Instantiation** → Create concrete action instances  
5. **Queue Management** → Add actions to actor's execution queue
6. **Synchronization** → Handle multi-actor interactions and constraints

## Key Data Structures

### Location Properties
- **`X, Y, Z, Angle, Interior`** - 3D positioning and orientation
- **`Region`** - Associated region for location matching
- **`isBusy`** - Occupancy state for conflict resolution
- **`allActions`** - All possible actions at this location
- **`PossibleActions`** - Currently available actions
- **`episodeLinks`** - Cross-episode connection points
- **`History`** - Per-actor action history at this location

### Action Queues
- **`CURRENT_STORY.actionsQueues[actorId]`** - Pending actions per actor
- **`CURRENT_STORY.nextEvents[actorId]`** - Next graph event per actor
- **`CURRENT_STORY.nextLocations[actorId]`** - Next location per actor

## Architecture Notes

### Graph Event Processing Algorithm
Complex multi-step process for converting graph events to actions:

1. **Event Extraction**: Get next event from temporal graph
2. **Movement Insertion**: Add Move actions for location changes
3. **Interaction Handling**: Create Wait/Interaction action pairs
4. **Object Resolution**: Map graph objects to simulator objects
5. **Action Chain Building**: Create prerequisite action sequences

### Location Candidate Selection
Sophisticated location selection with multiple constraints:

**Mapped Locations (Primary):**
- Use pre-computed location mappings from graph validation
- Respect chain ID assignments for object consistency
- Fallback to unmapped locations if needed

**Dynamic Candidates (Fallback):**
- Region name matching with fuzzy search
- Action availability verification
- Object type and instance matching
- Interaction-specific location constraints

### Multi-Actor Synchronization
Complex synchronization mechanisms:

**Interaction Processing:**
- Only initiating actor creates interaction actions
- Target actor gets Wait action with `doNothing=true`
- Shared interaction relation IDs prevent duplication
- Location cloning for proper positioning

**Chain ID System:**
- Ensures multiple actors use same object instances
- Prevents object conflicts in multi-actor scenarios
- Maintains consistency across action sequences

**Occupancy Management:**
- Locations marked as busy during use
- Waiting mechanism for occupied locations
- Random relocation of finished actors

### Object Mapping System
Critical for graph-to-simulation translation:

**Chain-Based Mapping:**
- Objects mapped with unique chain IDs
- Players assigned to specific chains for consistency
- Spawnable objects handled specially
- Picked-up object state tracking

### Action Queue Management
- Actions queued per actor with temporal ordering
- Move actions inserted automatically for location changes
- Prerequisite actions processed recursively
- Queue exhaustion triggers story end

### Interaction Processing
Special handling for multi-actor social interactions:

1. **Detection**: Identify interaction events via action name
2. **Relation Mapping**: Extract interaction relation from temporal constraints
3. **Wait Action**: Create synchronized waiting action
4. **Action Creation**: Instantiate specific interaction (HandShake, Kiss, etc.)
5. **Position Coordination**: Clone locations with offsets for proper positioning

### Waiting and Conflict Resolution
Sophisticated conflict resolution for location occupancy:

- Busy location detection and waiting
- Random movement of finished actors
- Pause/resume mechanism for blocked actions
- Deadlock prevention through timeout

### Debug Integration
Extensive debugging support:
- Location candidate evaluation logging
- Action selection decision tracking
- Object mapping validation
- Interaction processing details

### Error Handling
Robust error handling for complex edge cases:
- Missing objects or actions
- Invalid location candidates
- Unmappable graph events
- Story termination conditions

This system represents one of the most sophisticated parts of the story simulation engine, handling the complex translation from abstract graph events to concrete 3D world actions while managing multi-actor synchronization and conflict resolution.