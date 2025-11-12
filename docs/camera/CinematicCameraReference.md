# Cinematic Camera System Reference

Complete reference for the GEST cinematic camera system.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Camera Modes](#camera-modes)
3. [Complete Schema](#complete-schema)
4. [Shot Types](#shot-types)
5. [Framing Types](#framing-types)
6. [Subject Types](#subject-types)
7. [Recording Control](#recording-control)
8. [Complete Examples](#complete-examples)

---

## Quick Start

### Minimal Example

```json
{
  "camera": {
    "mode": "cinematic",
    "action0": {
      "shot": {
        "type": "follow",
        "subject": "actor0"
      }
    }
  }
}
```

### With Recording Control

```json
{
  "camera": {
    "mode": "cinematic",
    "action0": {
      "recording": "start",
      "shot": {
        "type": "follow",
        "subject": "actor0"
      }
    },
    "action3": {
      "recording": "stop"
    }
  }
}
```

---

## Camera Modes

### Static Mode (default)

Automatic focus switching with 2-second timer (preserves existing behavior).

```json
{
  "camera": {
    "mode": "static"
  }
}
```

- Camera switches between actors every 2 seconds
- Uses region's predefined static cameras
- **No manual camera control**

### Cinematic Mode

Graph-driven camera control using semantic commands.

```json
{
  "camera": {
    "mode": "cinematic",
    "action0": {...}
  }
}
```

- Camera controlled explicitly by graph events
- No automatic focus switching
- Full manual control

---

## Complete Schema

```json
{
  "camera": {
    "mode": "<static|cinematic>",

    "<event_id>": {
      "recording": "<start|stop>",
      "shot": {
        "type": "<shot_type>",
        "subject": "<entity_id>",
        "target": "<entity_id>",
        "subjects": ["<id1>", "<id2>"],
        "framing": "<framing_type>"
      }
    }
  }
}
```

### Fields

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `mode` | No | string | Camera mode (`static` or `cinematic`, default: `static`) |
| `recording` | No | string | Recording control (`start` or `stop`) |
| `shot` | No | object | Camera shot specification |
| `shot.type` | Yes* | string | Shot type (see [Shot Types](#shot-types)) |
| `shot.subject` | Varies | string | Primary target entity/region |
| `shot.target` | No | string | Secondary target (for `over_shoulder`) |
| `shot.subjects` | No | array | Multiple targets (for `two_shot`) |
| `shot.framing` | No | string | Override default framing |

*Required if `shot` is specified

---

## Shot Types

### 1. follow

Track subject continuously as they move (50ms updates).

**Required**: `subject`
**Optional**: `framing`

```json
{
  "shot": {
    "type": "follow",
    "subject": "actor0"
  }
}
```

**With framing**:
```json
{
  "shot": {
    "type": "follow",
    "subject": "actor0",
    "framing": "wide"
  }
}
```

**Behavior**: Camera updates every 50ms to track subject movement, continues through intermediary regions.

---

### 2. static

Use region's predefined static camera.

**Required**: None

```json
{
  "shot": {
    "type": "static"
  }
}
```

**Behavior**: Uses `Region:SetStaticCameraWhereActorIsInFOVOrRandom()`.

---

### 3. free

Don't change camera position.

**Required**: None

```json
{
  "shot": {
    "type": "free"
  }
}
```

**Behavior**: Camera stays at previous position.

---

### 4. show

Medium shot of subject.

**Required**: `subject`
**Optional**: `framing`

```json
{
  "shot": {
    "type": "show",
    "subject": "actor0"
  }
}
```

**With region**:
```json
{
  "shot": {
    "type": "show",
    "subject": "living",
    "framing": "wide"
  }
}
```

---

### 5. close_up

Close-up shot of subject.

**Required**: `subject`

```json
{
  "shot": {
    "type": "close_up",
    "subject": "object0"
  }
}
```

---

### 6. wide

Wide shot of subject or region.

**Required**: None (can frame current region)
**Optional**: `subject`, `framing`

```json
{
  "shot": {
    "type": "wide"
  }
}
```

**With specific region**:
```json
{
  "shot": {
    "type": "wide",
    "subject": "kitchen"
  }
}
```

---

### 7. extreme_wide

Extreme wide establishing shot.

**Required**: None
**Optional**: `subject`

```json
{
  "shot": {
    "type": "extreme_wide",
    "subject": "living"
  }
}
```

---

### 8. extreme_close_up

Extreme close-up detail shot.

**Required**: `subject`

```json
{
  "shot": {
    "type": "extreme_close_up",
    "subject": "object0"
  }
}
```

---

### 9. two_shot

Frame two or more subjects together.

**Required**: `subjects` (array, minimum 2)
**Optional**: `framing`

```json
{
  "shot": {
    "type": "two_shot",
    "subjects": ["actor0", "actor1"]
  }
}
```

**With custom framing**:
```json
{
  "shot": {
    "type": "two_shot",
    "subjects": ["actor0", "actor1", "actor2"],
    "framing": "wide"
  }
}
```

**Behavior**: Calculates center point between all subjects, positions camera to frame all.

---

### 10. over_shoulder

Behind subject's shoulder looking at target.

**Required**: `subject`, `target`
**Optional**: `framing`

```json
{
  "shot": {
    "type": "over_shoulder",
    "subject": "actor0",
    "target": "actor1"
  }
}
```

**Behavior**: Camera positioned behind and to side of subject, looking at target.

---

## Framing Types

| Framing | Distance | FOV | Height | Use Case |
|---------|----------|-----|--------|----------|
| `extreme_wide` | 20 | 90° | 2.5 | Establishing shots, full environment |
| `wide` | 10 | 80° | 1.7 | Full scene, multiple actors |
| `medium` | 5 | 70° | 1.7 | Waist up (default) |
| `close_up` | 1.5 | 50° | 1.7 | Face, object detail |
| `extreme_close_up` | 0.8 | 40° | 1.7 | Eyes, small details |

**Default framing**: `medium` (unless shot type specifies otherwise)

---

## Subject Types

### Actors

**Format**: `"actor0"`, `"actor1"`, etc.
**Resolved by**: Actor `id` field from graph

```json
{"type": "follow", "subject": "actor0"}
```

### Objects

**Format**: `"object0"`, `"cigarette"`, etc.
**Resolved by**: Object `ObjectId` or `id` field

```json
{"type": "close_up", "subject": "object0"}
```

### Regions

**Format**: `"living"`, `"kitchen"`, `"bedroom"`, etc.
**Resolved by**: Fuzzy match on `Region.name` field (case-insensitive substring)

```json
{"type": "wide", "subject": "living"}
```

**Matching logic** (same as action location matching):
- Subject: `"living"` → Matches region: `"living_room"` ✅
- Subject: `"kitchen"` → Matches region: `"kitchen_area"` ✅
- Subject: `"bed"` → Matches region: `"bedroom"` ✅

---

## Recording Control

### Independent from Shot Control

Recording (artifact collection) and shot (camera positioning) are **separate concerns**:

- **Recording**: When to collect artifacts (screenshots, depth, segmentation)
- **Shot**: Where to position camera

### Start Recording

```json
{
  "recording": "start"
}
```

Can be combined with shot:
```json
{
  "recording": "start",
  "shot": {"type": "follow", "subject": "actor0"}
}
```

### Stop Recording

```json
{
  "recording": "stop"
}
```

Can be used alone (camera unchanged):
```json
{
  "recording": "stop"
}
```

### Legacy Format (backward compatible)

```json
{"action": "record"}  // Equivalent to {"recording": "start"}
{"action": "stop"}    // Equivalent to {"recording": "stop"}
```

### Use Cases

**Record entire story with different shots**:
```json
{
  "action0": {"recording": "start", "shot": {...}},
  "action1": {"shot": {...}},
  "action2": {"shot": {...}},
  "action5": {"recording": "stop"}
}
```

**Test camera without recording**:
```json
{
  "action0": {"shot": {...}},
  "action1": {"shot": {...}}
}
```

**Record specific portion**:
```json
{
  "action0": {"shot": {...}},
  "action1": {"recording": "start", "shot": {...}},
  "action2": {"recording": "stop"}
}
```

---

## Complete Examples

### Example 1: Basic Features

Tests: Follow, close-up, static camera, recording control

```json
{
  "actor0": {
    "Action": "Exists",
    "Entities": ["actor0"],
    "Properties": {"Gender": 1, "Name": "John"},
    "id": "actor0"
  },
  "object0": {
    "Action": "Exists",
    "id": "object0",
    "Target": {"id": "object0", "Name": "Cigarette"}
  },
  "action0": {
    "Action": "Move",
    "Entities": ["actor0"],
    "Location": ["bedroom", "living"],
    "id": "action0"
  },
  "action1": {
    "Action": "PickUp",
    "Entities": ["actor0", "object0"],
    "Location": ["living"],
    "id": "action1"
  },
  "action2": {
    "Action": "Smoke",
    "Entities": ["actor0", "object0"],
    "Location": ["living"],
    "id": "action2"
  },
  "temporal": {
    "starting_actions": {"actor0": "action0"},
    "action0": {"next": "action1"},
    "action1": {"next": "action2"},
    "action2": {"next": null}
  },
  "camera": {
    "mode": "cinematic",

    "action0": {
      "recording": "start",
      "shot": {"type": "follow", "subject": "actor0"}
    },

    "action1": {
      "shot": {"type": "close_up", "subject": "object0"}
    },

    "action2": {
      "shot": {"type": "static"},
      "recording": "stop"
    }
  }
}
```

### Example 2: Region Targeting

Tests: Wide shot of region, extreme wide establishing

```json
{
  "camera": {
    "mode": "cinematic",

    "action0": {
      "recording": "start",
      "shot": {"type": "extreme_wide", "subject": "bedroom"}
    },

    "action1": {
      "shot": {"type": "wide", "subject": "living"},
      "recording": "stop"
    }
  }
}
```

### Example 3: Multi-Actor Shots

Tests: Two-shot, over-shoulder, follow different actors

```json
{
  "camera": {
    "mode": "cinematic",

    "action0": {
      "recording": "start",
      "shot": {"type": "follow", "subject": "actor0", "framing": "medium"}
    },

    "action1": {
      "shot": {"type": "follow", "subject": "actor1", "framing": "wide"}
    },

    "action2": {
      "shot": {"type": "two_shot", "subjects": ["actor0", "actor1"]},
      "recording": "stop"
    }
  }
}
```

### Example 4: Recording Control

Tests: Multiple shot changes within one recording session

```json
{
  "camera": {
    "mode": "cinematic",

    "action0": {
      "shot": {"type": "follow", "subject": "actor0"}
    },

    "action1": {
      "recording": "start",
      "shot": {"type": "close_up", "subject": "object0"}
    },

    "action2": {
      "shot": {"type": "show", "subject": "actor0"}
    },

    "action3": {
      "recording": "stop",
      "shot": {"type": "static"}
    }
  }
}
```

---

## Migration Guide

### From String Format (OLD)

```json
{
  "camera": {
    "action0": "follow actor0",
    "action1": "close up on object0",
    "action2": "static"
  }
}
```

### To Structured Format (NEW)

```json
{
  "camera": {
    "action0": {
      "shot": {"type": "follow", "subject": "actor0"}
    },
    "action1": {
      "shot": {"type": "close_up", "subject": "object0"}
    },
    "action2": {
      "shot": {"type": "static"}
    }
  }
}
```

---

## Technical Details

### Continuous Tracking

- Uses MTA Timer with 50ms update frequency
- Calculates position relative to actor's rotation
- Automatically cleans up timer on event end
- Continues through intermediary regions during Move actions

### Region Resolution

Uses same fuzzy matching logic as action location mapping:
```lua
Region.name:lower():find(subject:lower())
```

### Context Switching

Both modes handle cross-episode transitions:
- Detects when actors move to different episodes
- Pauses old episode, fades camera
- Switches context, resumes new episode
- Cinematic mode: camera position controlled by current event command

---

## Breaking Changes

⚠️ **String commands no longer supported**

Old format will cause errors:
- `"follow actor0"` → Error
- `"close up on object0"` → Error
- `"static"` → Error

Must use structured format:
- `{"shot": {"type": "follow", "subject": "actor0"}}`
- `{"shot": {"type": "close_up", "subject": "object0"}}`
- `{"shot": {"type": "static"}}`

✅ **Legacy recording commands still work**:
- `{"action": "record"}` ✅
- `{"action": "stop"}` ✅

---

## Troubleshooting

### Camera not moving

- Check that `mode: "cinematic"` is set
- Verify shot commands are in correct format
- Check actor/object/region IDs match graph entities
- Enable `DEBUG_CAMERA` for detailed logging

### Subject not found

- Actors: Check `id` field matches
- Objects: Check `ObjectId` or `id` field matches
- Regions: Use substring of `Region.name` (case-insensitive)

### Recording not working

- Ensure `recording: "start"` is specified
- Check `recording: "stop"` is called when done
- Recording is independent of shot control
- Legacy `{action: "record"}` still supported

---

## Wall-Aware Camera Positioning

### Overview

The cinematic camera system includes intelligent position validation to ensure:
- ✅ Camera never clips through walls or obstacles
- ✅ Camera stays within region polygon bounds
- ✅ Camera maintains line-of-sight to subject
- ✅ Smooth adjustments when position becomes invalid

### Validation System

**Powered by MTA raycasting functions:**
- `isLineOfSightClear()` - Fast line-of-sight checks
- `processLineOfSight()` - Detailed collision information
- `Region:IsPointInside2()` - Polygon bounds checking

**Validation frequency:**
- **Static shots** (`show`, `close_up`, `wide`, etc.): Once when shot executes
- **Continuous tracking** (`follow`): Every 50ms (20 times per second)
- **Region changes**: Full revalidation when actor moves to new region

### Configuration

**In [ServerGlobals.lua](src/ServerGlobals.lua:85):**

```lua
ENABLE_CAMERA_VALIDATION = true   -- Toggle validation system
CAMERA_WALL_OFFSET = 0.5           -- Distance from walls (units)
DEBUG_CAMERA_VALIDATION = false    -- Detailed logging
```

### How It Works

**1. Position Calculation**
- Calculate ideal camera position based on shot type and framing

**2. Validation**
- Check if position is inside region polygon
- Check if camera has clear line-of-sight to subject
- Check for walls/obstacles in the way

**3. Adjustment (if invalid)**
- **Incremental Strategy**: Move camera toward subject until clear
- **Slide Strategy**: Place camera along wall surface using surface normal
- **Rotate Strategy**: Rotate around subject to find clear angle
- **Region Center**: Last resort - move toward region center

**4. Fallback**
- If no valid position found: Use region's static camera

### Continuous Tracking

For `follow` shots, validation runs every 50ms:

```lua
-- Every timer tick:
1. Detect if actor changed region
2. Calculate ideal camera position
3. Validate position (line-of-sight + region bounds)
4. Adjust if invalid using incremental strategy
5. Update camera with validated position
```

**Region change detection:**
- Tracks actor's `currentRegionId`
- Triggers full revalidation when region changes
- Ensures camera adapts to new environment

### Performance

**Cost per validation:**
- Line-of-sight check: ~0.1ms (MTA native function)
- Polygon bounds check: ~0.05ms (ray-casting algorithm)
- **Total: <0.2ms per validation**

**Validation frequency:**
- 50ms intervals = 20 validations/second
- Much lower than frame rate (60fps)
- Negligible performance impact

### Examples

**Camera outside region (adjust toward center):**
```
Ideal position: Outside room polygon
→ Validation fails: camera_outside_region
→ Adjustment: Move 70% toward region center
→ Result: Camera now inside room bounds
```

**Wall blocking line-of-sight (slide along wall):**
```
Ideal position: Behind wall from subject
→ Validation fails: line_of_sight_blocked
→ Raycast finds wall hit point + surface normal
→ Adjustment: Place camera along wall (hit + normal * 0.5 units)
→ Result: Camera can see subject
```

**Actor crosses region (full revalidation):**
```
Follow shot tracking actor
→ Actor moves living_room → hallway
→ Region change detected
→ Full revalidation triggered
→ Camera adjusted for new region polygon
→ Tracking continues smoothly
```

### Debugging

Enable detailed logging:

```lua
DEBUG_CAMERA_VALIDATION = true
```

**Output examples:**
```
[CameraValidation] Camera outside region: bedroom
[CameraValidation] Finding valid position using strategy: incremental
[CameraValidation] Found valid position at 60% of original distance

[CinematicCameraHandler] Actor changed region during tracking: hallway
[CinematicCameraHandler] Tracking camera invalid, adjusting... Reasons: line_of_sight_blocked
```

### Technical Details

**Validation happens in:**
- `CinematicCameraHandler:focusOnSubject()` - Static shots
- `CinematicCameraHandler:overShoulderShot()` - Static shots
- `CinematicCameraHandler:frameTwoShot()` - Static shots
- `CinematicCameraHandler:startContinuousTracking()` - Every 50ms for follow shots

**Adjustment strategies:**
- **Incremental**: Tests positions at 90%, 80%, 70%... of distance (best for follow)
- **Slide**: Uses wall hit point + surface normal (best for over-shoulder)
- **Rotate**: Tests positions around subject in 30° increments (best for two-shot)

**MTA raycasting parameters:**
```lua
isLineOfSightClear(
    cameraX, cameraY, cameraZ,
    subjectX, subjectY, subjectZ,
    true,  -- checkBuildings (walls, floors, ceilings)
    false, -- checkVehicles (ignore, they move)
    false, -- checkPeds (ignore, they move)
    true,  -- checkObjects (furniture, props)
    true,  -- checkDummies
    false, -- seeThroughStuff
    true   -- ignoreSomeObjectsForCamera (ignore barrels, boxes)
)
```

### Limitations

- No obstacle prediction (only reacts when position becomes invalid)
- Small rooms may have limited valid camera positions
- Extreme camera distances may always be outside region bounds
- Continuous tracking may have slight camera "jumps" when adjusting

---

## API Reference

### CameraSpecParser

Parses structured camera commands:
- Input: `{shot: {type: "...", ...}}`
- Output: Normalized semantic specification
- **No string parsing** (throws error for strings)

### CameraParameters

Translates semantic to technical parameters:
- Maps shot types to behaviors
- Maps framings to distance/FOV
- Provides default values

### CinematicCameraHandler

Executes camera shots:
- `executeShot()` - Handle shot commands
- `startContinuousTracking()` - Follow subjects
- `focusOnSubject()` - One-time positioning
- `getEntity()` - Resolve actors/objects/regions

### CameraHandlerBase

Common functionality:
- `executeCommand()` - Separates recording/shot control
- `isCurrentlyRecording()` - Check recording state
- `FadeForAll()` - Camera fade effects
- Context switching logic

### CameraValidation

Position validation and adjustment:
- `validateCameraPosition()` - Check if position is valid (line-of-sight + region bounds)
- `findValidCameraPosition()` - Find nearest valid position using adjustment strategies
- `adjustIncremental()` - Move camera toward subject incrementally
- `adjustSlideAlongWall()` - Slide camera along wall surface
- `adjustRotateAroundSubject()` - Rotate around subject to find clear angle
- `hasActorChangedRegion()` - Detect region changes for revalidation

---

## See Also

- [System Architecture Overview](../arch/system-overview.md)
- [CameraHandler Documentation](../docs/api/CameraHandler.md)
- Test graphs in `input_graphs/cinematic_*.json`
