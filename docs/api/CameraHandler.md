# CameraHandler.lua

## Purpose

The CameraHandler is a sophisticated camera synchronization system designed to manage multi-actor video capture in complex multi-episode scenarios. It handles automatic camera switching, context transitions between episodes, and spectator management for video generation.

## Key Functionality

### Core Camera Management
- **Focus Request Queue**: First-come-first-served camera assignment with minimum focus times
- **Multi-Actor Coordination**: Manages camera focus across multiple actors performing simultaneous actions
- **Context Switching**: Handles seamless transitions between different episodes/locations
- **Spectator Management**: Controls fade effects and camera states for video capture spectators

### Advanced Features
- **Automatic Region Detection**: Finds closest POI when actor region data is missing
- **Cross-Episode Synchronization**: Pauses/resumes actions when switching between episodes
- **Interior Management**: Switches object interiors during context changes
- **Temporal Focus Management**: Configurable focus durations (2s normal, 5s for context changes)

## Class Structure

```lua
CameraHandler = class(function(o)
    o.FocusRequests = {}      -- Queue of player IDs requesting camera focus
    o.isFocused = false       -- Whether camera is currently focused on any actor
    o.isSwitchingContext = false  -- Prevents concurrent context switches
end)
```

## Key Functions

### Focus Management
- **`requestFocus(playerId)`** - Adds player to focus queue, triggers initial camera setup
- **`freeFocus(playerId)`** - Removes player from queue, triggers next focus assignment
- **`autoFocus()`** - Processes focus queue and assigns camera to next actor
- **`clearFocusRequests(playerId)`** - Removes all focus requests for specific player

### Context Switching
- **`assignFocusToRegion(actor, region, contextChanged)`** - Core focus assignment with context handling
- **`WaitUntilEpisodePausedThenAssignFocusToRegion(...)`** - Manages episode pause/resume during context switches
- **`getCurrentRegionAndEpisode(actor)`** - Retrieves/fixes actor's current location context

### Visual Effects
- **`FadeForAll(fade, time)`** - Controls fade in/out for all spectators with timing
- **`focusTimeReached(playerId, contextChanged, time)`** - Handles focus duration timeouts

## Dependencies

- **CURRENT_STORY** - Global story instance containing episodes, spectators, actors
- **DEBUG_CAMERA** - Debug flag for camera operation logging
- **Timer** - Async timing system for focus duration and context switching
- **Region system** - Episode regions for spatial camera management

## Data Flow

### Focus Request Flow
1. Action system calls `requestFocus(playerId)` when actor begins action
2. Player added to `FocusRequests` queue if not already present
3. If first focus request, triggers `autoFocus()` and fades in spectators
4. `autoFocus()` processes queue, assigns focus to first player
5. After focus duration (2s/5s), `focusTimeReached()` calls `freeFocus()`

### Context Switching Flow
1. `autoFocus()` detects context change (different episode than current focus)
2. Calls `RequestPause()` on current focused episode
3. `WaitUntilEpisodePausedThenAssignFocusToRegion()` waits for all actions to pause
4. Fades out spectators during transition
5. Assigns focus to new region/episode
6. Resumes actions in new episode and fades in spectators

### Region Detection Flow
1. `getCurrentRegionAndEpisode()` checks actor's region data
2. If missing, finds closest POI with region
3. Triggers `Region:OnPlayerHit()` to update actor's region data
4. Returns updated region/episode information

## Architecture Notes

### Complex Context Management
The system implements sophisticated multi-episode camera management:
- **Episode Pause System**: All actors in old episode pause move actions during context switch
- **Action Resumption**: New episode actors resume from paused state
- **Chain Consistency**: Maintains object chain IDs across episode transitions
- **Interior Synchronization**: Updates picked objects to match new episode interior

### Video Generation Integration
- **Spectator Control**: Manages multiple spectator cameras for video capture
- **Fade Coordination**: Synchronized fade effects during transitions
- **Timing Precision**: Configurable focus durations for video pacing
- **Multi-angle Support**: Supports multiple spectators for different camera angles

### Debug and Monitoring
- **Comprehensive Logging**: Detailed debug output for focus operations
- **State Inspection**: `__tostring()` provides full state visibility
- **Error Recovery**: Automatic region fixing when actor data is corrupted
- **Performance Monitoring**: Tracks context switch timing and episode pause states

## Critical Globals

- **`CURRENT_STORY.Spectators`** - Array of spectator players for video capture
- **`CURRENT_STORY.CurrentEpisode`** - Currently active episode with actors and POIs
- **`CURRENT_STORY.CurrentFocusedEpisode`** - Episode currently in camera focus
- **`CURRENT_STORY.CameraHandler`** - Global camera handler instance

## Integration Points

- **ActionsOrchestrator**: Requests focus when actions begin execution
- **Episode System**: Manages pause/resume during context switches
- **Region System**: Provides spatial context for camera positioning
- **PedHandler**: Coordinates actor state during camera transitions
- **Template System**: Handles interior switching for context changes

## Video Generation Workflow

1. **Story Begins**: First action triggers `requestFocus()`, initializes spectator cameras
2. **Action Execution**: Each actor action requests focus, added to queue
3. **Focus Assignment**: Camera assigned to actors based on queue order and timing
4. **Context Detection**: System detects when focus needs to switch episodes
5. **Smooth Transitions**: Pause old episode, fade out, switch context, resume new episode, fade in
6. **Continuous Capture**: Process continues until story completion

This system represents a breakthrough in automated multi-actor video generation, providing seamless camera choreography for complex interactive narratives across multiple 3D environments.