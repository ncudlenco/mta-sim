# SpatialCoordinator.lua

## Purpose
Utility module for validating spatial relations between objects in the global coordinate system. Enforces spatial constraints during actor chain selection to synchronize multi-actor scenarios where objects must satisfy positional relationships (e.g., "3 chairs at same desk").

## Key Functions

### Spatial Relation Validation

**`SpatialCoordinator.ValidateRelation(sourcePos, targetPos, targetRotation, relationType)`**
- Validates a single spatial relation between source and target objects
- **Parameters**:
  - `sourcePos` (Vector3): Position of source object
  - `targetPos` (Vector3): Position of target object
  - `targetRotation` (table): Rotation of target object `{x, y, z}` (required for directional relations)
  - `relationType` (string): Type of relation - "on", "left", "right", "in_front", "behind"
- **Returns**: `boolean, string` - Validation result and error message if failed

**`SpatialCoordinator.ValidateAllConstraints(objectId, candidatePos, candidateRotation, materializedObjects)`**
- Validates all spatial constraints for an object against the materialized world
- **Parameters**:
  - `objectId` (string): Source object ID from graph (e.g., "laptop", "officeChair")
  - `candidatePos` (Vector3): Candidate position for object
  - `candidateRotation` (table): Rotation of candidate object
  - `materializedObjects` (table): Map of `objectId -> {pos, rotation, chainId, actorId}`
- **Returns**: `boolean, string` - Validation result and reason if failed

### Object Materialization

**`SpatialCoordinator.MaterializeObject(objectId, position, rotation, chainId, actorId)`**
- Records an object's materialization in the world
- Called when an actor selects a chain and object positions are determined
- **Parameters**:
  - `objectId` (string): Object ID from graph
  - `position` (Vector3): Position of object
  - `rotation` (table): Rotation of object
  - `chainId` (string): Chain ID that materialized this object
  - `actorId` (string): Actor ID who materialized this object

**`SpatialCoordinator.ClearMaterializedObjects()`**
- Clears all materialized objects (used when restarting story)

### Constraint Retrieval

**`SpatialCoordinator.GetSpatialConstraints(objectId)`**
- Gets spatial constraints for an object from the graph
- **Parameters**: `objectId` (string) - Object ID from graph
- **Returns**: `table|nil` - Array of `{target, type}` relations or nil

## Supported Spatial Relations

All relations are evaluated in the **global coordinate system** relative to the target object's position and rotation.

### Positional Relations

**`on`** - Source positioned on top of target
- Validates vertical proximity (Z-axis) within threshold
- Validates horizontal proximity (XY-plane) within threshold
- Default thresholds:
  - Vertical: 0.8 units
  - Horizontal: 2.0 units
- **Example**: Laptop on desk

**`near`** - Source positioned near target
- Validates 3D Euclidean distance within threshold
- Direction-independent (no rotation required)
- **Dynamic threshold calculation**:
  - **Primary approach**: Attempts to get radius from MTA element using `getElementRadius()` or `getElementBoundingBox()` (client-side functions, may fail server-side)
  - **Fallback approach**: Uses object type-based radius lookup from `OBJECT_TYPE_RADII` table
  - Threshold = `sourceRadius + targetRadius + 1.0` (buffer)
  - If no type information available, uses default threshold: 5.0 units
- **Example**: Chair near table, actors near objects

### Directional Relations

All directional relations use the target object's forward direction (derived from rotation.z).

**`in_front`** - Source positioned in front of target
- Angle: -45° to +45° from target's forward direction
- **Example**: Monitor in front of desk

**`behind`** - Source positioned behind target
- Angle: Beyond ±135° (either >135° or <-135°)
- **Example**: Wall behind desk

**`left`** - Source positioned to the left of target
- Angle: 45° to 135° (counter-clockwise from forward)
- **Example**: Lamp to the left of desk

**`right`** - Source positioned to the right of target
- Angle: -135° to -45° (clockwise from forward)
- **Example**: Drawer to the right of desk

### Angle Calculation

Directional relations use `CalculateRelativeAngle()`:
1. Computes target's forward vector from `rotation.z` (yaw)
2. Computes vector from target to source
3. Calculates signed angle using atan2
4. Returns angle in degrees (-180 to 180)

## Integration with Graph System

### JSON Schema

Spatial constraints are defined in the graph JSON's `spatial` section:

```json
{
  "spatial": {
    "laptop": {
      "relations": [
        {
          "target": "Desk",
          "type": "on"
        }
      ]
    },
    "officeChair": {
      "relations": [
        {
          "target": "Desk",
          "type": "behind"
        }
      ]
    }
  }
}
```

### Parsing and Storage

- Parsed in [GraphStory.lua:121-127](../story/GraphStory.md#spatial-parsing)
- Stored in `CURRENT_STORY.spatial`
- Structure: `{ objectId = { relations = [ {target, type}, ... ] } }`

### Materialized Objects Tracking

- Stored in `CURRENT_STORY.materializedObjects`
- Structure: `{ objectId = { pos, rotation, chainId, actorId } }`
- Initialized as empty table in GraphStory constructor
- Populated when actors select locations with objects

## Runtime Flow

### Location Candidate Selection

Integration in [Location:ProcessNextAction()](../story/Locations/Location.md):

1. **Initial candidate filtering** - Region, action, object type matching
2. **Spatial constraint validation** ([Location.lua:849-899](../../src/story/Locations/Location.lua#L849-L899)):
   - Check if event involves an object with spatial constraints
   - For each candidate location:
     - Get object instance position
     - Validate against materialized objects
     - Filter out candidates violating constraints
3. **Candidate selection** - Pick from spatially-valid candidates
4. **Object materialization** ([Location.lua:994-1018](../../src/story/Locations/Location.lua#L994-L1018)):
   - Record selected object position
   - Store in materializedObjects map
   - Available for subsequent actors' validation

### Multi-Actor Synchronization

**Scenario: 2 actors, 6 chairs, 2 desks**

1. **Actor 1** needs chair:
   - All 6 chair chains are valid
   - No spatial constraints enforced yet (desk not materialized)
   - Selects chair1 at desk1
   - **Materializes**: chair1, desk1

2. **Actor 2** needs chair with constraint "at desk":
   - Gets 6 chair candidates initially
   - Validates each against materialized desk1
   - Filters to chairs near desk1 only
   - Selects chair2 at desk1
   - **Result**: Both actors synchronized to same desk

## Configuration

### Thresholds (modifiable in [SpatialCoordinator.lua](../../src/utils/SpatialCoordinator.lua))

```lua
SpatialCoordinator.ON_VERTICAL_THRESHOLD = 0.8
SpatialCoordinator.ON_HORIZONTAL_THRESHOLD = 2.0
SpatialCoordinator.NEAR_THRESHOLD = 5.0
SpatialCoordinator.DIRECTIONAL_DISTANCE_THRESHOLD = 5.0
SpatialCoordinator.DIRECTIONAL_ANGLE_TOLERANCE = 45
```

### Object Type Radii (for dynamic "near" threshold calculation)

The system uses a two-tier approach for calculating object radii:

1. **Element-based (Primary)**: Attempts to use MTA's `getElementRadius()` or `getElementBoundingBox()` if element reference is available (client-side only)
2. **Type-based (Fallback)**: Uses approximate radii from `OBJECT_TYPE_RADII` lookup table

```lua
SpatialCoordinator.OBJECT_TYPE_RADII = {
    -- Furniture
    ["Chair"] = 0.7,
    ["Desk"] = 1.5,
    ["Table"] = 1.2,
    ["Bed"] = 1.5,
    ["Sofa"] = 1.5,
    ["Armchair"] = 0.9,

    -- Small objects
    ["Laptop"] = 0.3,
    ["Phone"] = 0.1,
    ["Cigarette"] = 0.05,
    ["Drinks"] = 0.15,
    ["Food"] = 0.2,

    -- Default for unknown types
    ["default"] = 1.0
}
```

**Adding new object types**: Simply add entries to this table with appropriate radius values in GTA units. The radius represents the approximate bounding sphere of the object.

### Debug Logging

Enable detailed spatial validation logging:
```lua
local DEBUG_SPATIAL = DEBUG and true or false
```

Logs include:
- Constraint validation attempts
- Angle calculations
- Candidate filtering results
- Object materialization events
- Element-based vs. type-based radius calculation results
- Dynamic threshold calculations for "near" relation

## Dependencies

- **Vector3** - 3D coordinate system ([VectorUtils.lua](../../src/utils/VectorUtils.lua))
- **CURRENT_STORY** - Global story instance for spatial/materialized data
- **FirstOrDefault, Where** - Collection utilities ([functional.lua](../../src/utils/functional.lua))
- **DEBUG** - Global debug flag

## Related Documentation

- **[GraphStory.md](../story/GraphStory.md)** - Spatial constraint parsing
- **[Location.md](../story/Locations/Location.md)** - Candidate selection with spatial validation
- **[Region.md](../story/Locations/Region.md)** - Camera-relative positioning (different from spatial relations)

## Architecture Notes

### Chain Semantics Preservation

Spatial constraints **do not modify chain semantics**:
- Chains remain sequences of events in same location with some objects
- Each actor independently selects chains
- Spatial constraints only **filter** which chains are valid at runtime

### Lazy Materialization

Objects are materialized **on-demand**:
- Not materialized during graph validation
- Materialized when actor selects location with object
- Enables dynamic synchronization between actors

### Validation Skipping

Constraints are skipped when:
- Target object not yet materialized
- Object is spawnable (no fixed position)
- Event is an interaction (handled separately)
- No spatial constraints defined for object

This allows flexible constraint enforcement - early actors aren't constrained, later actors are synchronized to early actors' choices.

## Usage Example

### Graph Definition

```json
{
  "Desk": {
    "Action": "Exists",
    "Entities": ["Desk"],
    "Location": ["office"],
    "Properties": {"Type": "Desk"}
  },
  "chair1": {
    "Action": "Exists",
    "Entities": ["chair1"],
    "Location": ["office"],
    "Properties": {"Type": "Chair"}
  },
  "chair2": {
    "Action": "Exists",
    "Entities": ["chair2"],
    "Location": ["office"],
    "Properties": {"Type": "Chair"}
  },
  "actor1_sit": {
    "Action": "SitDown",
    "Entities": ["actor1", "chair1"],
    "Location": ["office"]
  },
  "actor2_sit": {
    "Action": "SitDown",
    "Entities": ["actor2", "chair2"],
    "Location": ["office"]
  },
  "spatial": {
    "chair1": {
      "relations": [
        {"target": "Desk", "type": "behind"}
      ]
    },
    "chair2": {
      "relations": [
        {"target": "Desk", "type": "behind"}
      ]
    }
  }
}
```

### Runtime Execution

1. Actor1 executes `actor1_sit`:
   - Selects chair1 instance
   - Desk instance automatically materialized (spatial constraint)
   - Both recorded in materializedObjects

2. Actor2 executes `actor2_sit`:
   - Gets chair2 candidates
   - Validates "behind Desk" constraint against materialized Desk
   - Selects chair2 instance that satisfies constraint
   - Both actors now using chairs behind same desk

## Testing

Spatial constraints can be tested by:

1. Creating graphs with spatial relations
2. Verifying debug logs show constraint validation
3. Checking materialization events
4. Observing multi-actor synchronization
5. Validating visual results in game

Test cases should cover:
- Simple positional constraints (on)
- Directional constraints (left, right, in_front, behind)
- Multi-actor synchronization
- Constraint skipping (spawnable objects, unmaterialized targets)
- Invalid constraint handling
