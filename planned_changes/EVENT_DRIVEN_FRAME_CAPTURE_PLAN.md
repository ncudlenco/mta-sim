# Event-Driven Frame Capture System - Implementation Plan

**Status**: Planning Phase - Awaiting Architecture Decisions
**Last Updated**: 2025-10-19

---

## Context

### Goal
Add frame captures at action/event start and end boundaries, in addition to regular scheduled 30 FPS captures.

### Purpose
Enable precise event-to-frame mapping for ML pipelines.

---

## Key Requirements

### 1. Frame Numbering
- **Sequential frame IDs** for all captures (scheduled + event-driven)
- **Naming convention**: `frame_0014_screenshot.jpg`, `frame_0014_segmentation.png` (same as current)
- **Note**: Multiple events can share same frame ID if they start/end simultaneously

### 2. All Artifacts
- Event boundary captures run **full collection pipeline**:
  - Raw JPEG
  - Raw video frame
  - Segmentation PNG
  - Depth (if enabled)
- Same collectors as scheduled captures

### 3. Deduplication
- **Threshold**: 100ms (default, configurable)
- **Rules**:
  - Skip if recent scheduled frame captured within threshold
  - Skip if upcoming scheduled frame will capture within threshold
  - If skipped, annotate the nearby scheduled frame as event boundary

### 4. Freeze Coordination
Event captures use same freeze/collect/unfreeze cycle as scheduled:

| Scenario | Behavior |
|----------|----------|
| No collection active | Event-driven collector triggers freeze → collect → unfreeze |
| Collection ongoing (already frozen) | Force ongoing scheduled collection to count as event boundary<br>(frozen time doesn't count for simulation) |
| Upcoming scheduled within threshold | Skip event capture, annotate scheduled frame as event boundary |

### 5. Video Separation
- **Event boundary frames**:
  - `saveToVideo = false`
  - `saveImage = true`
  - Saved as images only, NOT added to video encoder

- **Scheduled frames**:
  - `saveToVideo = true`
  - `saveImage = true`
  - Go to both video and image files

- **Benefit**: Maintains perfect 30 FPS video timing regardless of event captures

### 6. Incremental Mapping
- **Format**: `eventFrameMappings[eventId] = {startFrame: N, endFrame: M}`
- **Filename**: `event_frame_mapping.json`
- **Write frequency**: After each event start/end annotation (crash-safe)

---

## Architecture Options

### Option A: Separate Collectors (RECOMMENDED)

**Reason**: Cleaner architecture, easier to debug, performance impact unknown

#### Collectors

**RGBVideoCollector**
- Trigger: Scheduled only (30 FPS)
- `saveToVideo = true`, `saveImage = false`
- Registration: scheduled at 30 FPS

**RGBImageCollector**
- Trigger: Event-driven only
- `saveToVideo = false`, `saveImage = true` (JPEG)
- Registration: event-driven
- Logic: Start internal scheduler at event start, stop at event end
- FPS: Must match video FPS (30) between boundaries

**SegmentationCollector**
- Trigger: Event-driven only
- Same scheduler behavior as RGBImageCollector
- **Must perfectly align with RGBImageCollector frames**
- FPS: Configurable (e.g., 10 FPS), but frames must be subset of raw frames

**DepthCollector**
- Trigger: Event-driven only
- Same scheduler behavior as RGBImageCollector
- **Must perfectly align with RGBImageCollector frames**

**EventMappingCollector**
- Trigger: Event-driven only
- `saveToVideo = false`, `saveImage = false`
- Purpose: Only tracks event→frame mappings
- Dedup logic: Decides internally based on timing parameters
- Output: `event_frame_mapping.json` (incremental writes)

#### Benefits
- ✅ Clean separation of concerns
- ✅ Video timing 100% independent and predictable
- ✅ Event frames explicitly managed
- ✅ Easy to debug and reason about

#### Drawbacks
- ⚠️ Desktop Duplication called twice per event frame (once for video, once for images)
- ⚠️ Potential performance bottleneck if capture is expensive

---

### Option B: Unified RawCollector

**Reason**: Only if Desktop Duplication capture is expensive (>20% of total time)

#### Collectors

**RawCollector** (enhanced)
- Trigger: **Both** scheduled AND event-driven
- Parameters on trigger:
  - `triggerType`: `"scheduled"` | `"event-driven"`
  - `timeSinceLastCapture`: number (ms)
  - `timeUntilNextScheduled`: number | nil
- Internal logic:
  - `saveToVideo = true` if scheduled, `false` if event-driven
  - `saveImage` based on config + dedup logic
  - **Optimization**: Reuse same pixel buffer for video+image if both needed
- Registration: scheduled at 30 FPS + event-driven

**SegmentationCollector**
- Trigger: Event-driven only
- Must align with RawCollector event captures

**DepthCollector**
- Trigger: Event-driven only
- Must align with RawCollector event captures

**EventMappingCollector**
- Same as Option A

#### Benefits
- ✅ Desktop Duplication called once per frame
- ✅ Reuse pixel buffer for video + JPEG encoding
- ✅ Better performance if capture is expensive

#### Drawbacks
- ⚠️ RawCollector has more complex logic
- ⚠️ Harder to reason about video vs. image timing
- ⚠️ Mixed responsibilities (video + image + event-driven)

---

## Outstanding Questions

### Q1: Desktop Duplication Performance
**Question**: Is Desktop Duplication capture expensive enough to warrant Option B?

**Test Needed**: Run simulation and measure CPU/time cost of capture vs. encoding

**Decision Criteria**:
- If capture is <5% of total time → **Option A is fine**
- If capture is >20% of total time → **Option B is necessary**

**Status**: ⏳ Needs testing

---

### Q2: Event→Action Mapping
**Question**: How to detect event start/end when one event maps to multiple actions?

**Problem**: One event can be mapped to more than one action due to inserted Move actions

**Example**:
```
Graph event: actor_1_event_5 = "Go to kitchen and get water"

Orchestrator breaks into:
1. Move(actor_1, current_location, kitchen) - INSERTED
2. PickUp(actor_1, water_bottle) - ORIGINAL EVENT ACTION

Question: When does event_5 start?
- When Move starts? (orchestrator inserts it)
- When PickUp starts? (original graph action)
```

**Proposed Solution**:
```lua
-- Track first action start = event start, last action end = event end
eventActionMapping = {
    ["event_5"] = {
        actions = {"Move_123", "PickUp_456"},
        firstActionStarted = false,
        lastActionFinished = false
    }
}

-- When Move_123 starts:
if eventActionMapping["event_5"].firstActionStarted == false then
    eventActionMapping["event_5"].firstActionStarted = true
    publishEvent("onEventStart", "event_5", actor_1)
end

-- When PickUp_456 finishes (last action in event):
if isLastActionForEvent("PickUp_456", "event_5") then
    publishEvent("onEventEnd", "event_5", actor_1)
end
```

**Location**: ActionsOrchestrator or GraphStory

**Alternative**: Event boundaries explicitly defined in graph JSON?

**Status**: ⏳ Awaiting decision

---

### Q3: Event-Driven Scheduler Behavior
**Question**: How do event-driven collectors schedule their captures between event start and end?

**Option A: Reuse Global Schedule** (RECOMMENDED)
- Event-driven collectors use the SAME 30 FPS global schedule
- Just start/stop subscribing to it
- **Benefit**: Perfect frame alignment between global video and event images

**Option B: Independent Timer**
- Event-driven collectors start their OWN independent 30 FPS timer at event start
- **Drawback**: Frame alignment might drift due to timer start offset

**Status**: ⏳ Awaiting decision

---

### Q4: Collector Registration API
**Question**: What API should ArtifactCollectionManager expose for collector registration?

**Proposed API**:
```lua
function ArtifactCollectionManager:registerCollector(collector, triggers)
    -- triggers = {
    --     scheduled = true/false,
    --     eventDriven = true/false,
    --     fps = 30 (only used if scheduled = true)
    -- }
end

-- Example registrations:
manager:registerCollector(rawVideoCollector, {
    scheduled = true,
    eventDriven = false,
    fps = 30
})

manager:registerCollector(rawImageCollector, {
    scheduled = false,
    eventDriven = true,
    fps = 30
})

manager:registerCollector(segmentationCollector, {
    scheduled = false,
    eventDriven = true,
    fps = 10
})

manager:registerCollector(eventMappingCollector, {
    scheduled = false,
    eventDriven = true
})
```

**Status**: ⏳ Awaiting confirmation

---

### Q5: Dedup Decision Flow
**Question**: How to annotate "future" scheduled frame ID when deduping event capture?

**Problem**: If event start happens and we dedup (wait for upcoming scheduled frame), we don't know the future frame ID yet.

**Proposed Solution**: Pending annotations that resolve when scheduled frame captures

**Flow**:
```lua
-- Step 1: Event start triggers, dedup logic detects upcoming scheduled frame
function EventMappingCollector:onEventStart(eventId)
    local timeUntilNext = artifactManager:getTimeUntilNextScheduled()

    if timeUntilNext and timeUntilNext < self.dedupThreshold then
        -- Step 2: Set pending annotation flag
        self.pendingEventAnnotations[eventId] = {
            type = "start",
            waitingForScheduled = true
        }
        -- Step 3: Don't trigger collection
        return
    end

    -- Otherwise trigger collection normally
    artifactManager:triggerEventCollection(eventId, "start")
end

-- Step 4: When scheduled frame captures
function EventMappingCollector:onScheduledCaptureComplete(frameId)
    -- Step 5: Resolve pending annotations
    for eventId, pending in pairs(self.pendingEventAnnotations) do
        if pending.waitingForScheduled then
            self.eventFrameMappings[eventId].startFrame = frameId
            self.pendingEventAnnotations[eventId] = nil
            -- Step 6: Write mapping incrementally
            self:_saveMapping()
        end
    end
end
```

**Implementation Location**: `EventMappingCollector:onScheduledCaptureComplete(frameId)`

**Status**: ⏳ Awaiting confirmation

---

## Implementation Files

### New Files to Create

1. **`src/features/artifact_collection/collectors/EventMappingCollector.lua`**
   - Tracks event→frame mappings
   - Decides dedup logic
   - Writes JSON incrementally

2. **`src/features/artifact_collection/collectors/RawImageCollector.lua`** (Option A only)
   - Event-driven raw JPEG capture

3. **`src/features/artifact_collection/collectors/RawVideoCollector.lua`** (Option A only)
   - Scheduled raw video capture

### Files to Modify

#### `src/features/artifact_collection/ArtifactCollectionManager.lua`
- Add `registerCollector(collector, triggers)` API
- Add `triggerEventCollection(eventId, boundaryType)` method
- Add `getTimeUntilNextScheduled()` method
- Track `lastCapturedFrameId` and `lastCaptureTime`
- Handle both scheduled and event-driven collection triggers
- Coordinate freeze/unfreeze with multiple trigger sources

#### `src/features/artifact_collection/collectors/NativeScreenshotCollector.lua` (Option B only)
- Accept `timeSinceLastCapture` and `timeUntilNextScheduled` parameters
- Internal dedup logic

#### `src/features/artifact_collection/collectors/SegmentationCollector.lua`
- Support event-driven trigger
- Accept timing parameters for dedup

#### `src/api/ActionsOrchestrator.lua`
- Track `eventActionMapping` to detect first/last action per event
- Publish `onEventStart` when first action of event starts
- Publish `onEventEnd` when last action of event finishes
- Get `eventId` from `CURRENT_STORY.lastEvents[actorId]`

#### `src/story/GraphStory.lua`
- Subscribe to `onEventStart` and `onEventEnd` events
- Export annotated graph with frame mappings on completion
- Alternative: Delegate to EventMappingCollector entirely

#### `src/story/Actions/ActionsGlobals.lua`
- Publish `onEventEnd` in `OnGlobalActionFinished` (if applicable)
- Coordinate with ActionsOrchestrator for event tracking

---

## Timeline

### Phase 1: Testing (CURRENT)
**Status**: ✅ Ready for testing

**Tests**:
- [ ] Verify `raw_0014.jpg` matches `segmentation_0014.png` (same frame number)
- [ ] Verify no segmentation contamination in `raw.mp4`
- [ ] **CRITICAL**: Verify `dxDrawText()` doesn't advance animations during `setGameSpeed(0)`

---

### Phase 2: Architecture Decision
**Status**: ⏳ Awaiting user input

**Tasks**:
- [ ] Test Desktop Duplication performance (Q1)
- [ ] Decide event→action mapping approach (Q2)
- [ ] Confirm scheduler reuse strategy (Q3)
- [ ] Approve registration API design (Q4)
- [ ] Confirm dedup flow with pending annotations (Q5)

---

### Phase 3: Implementation
**Status**: 🚫 Blocked on Phase 2

**Tasks**:
- [ ] Create `EventMappingCollector`
- [ ] Create `RawVideoCollector` + `RawImageCollector` (Option A) OR enhance `NativeScreenshotCollector` (Option B)
- [ ] Enhance `ArtifactCollectionManager` with dual-trigger support
- [ ] Add event tracking to `ActionsOrchestrator`
- [ ] Add event publishing logic
- [ ] Implement dedup logic with timing parameters
- [ ] Add incremental JSON writing
- [ ] Export annotated graph on completion

---

### Phase 4: End-to-End Testing
**Status**: 🚫 Blocked on Phase 3

**Tests**:
- [ ] Verify event boundary frames captured at start/end
- [ ] Verify dedup works (no captures within threshold)
- [ ] Verify `event_frame_mapping.json` accuracy
- [ ] Verify video remains 30 FPS (no event frames in video)
- [ ] Verify frame alignment across all modalities
- [ ] Verify incremental JSON writes (crash-safe)

---

## Notes

### Performance Considerations
- Desktop Duplication capture cost is **unknown** - needs testing
- Encoding (H264) is likely the bottleneck, not capture
- Start with **Option A** (cleaner), optimize to Option B if needed

### Frame Alignment Critical
- Raw images, segmentation, and depth must capture at **EXACTLY same frames**
- If using separate schedulers, alignment will drift
- **Recommend**: Single global scheduler, collectors subscribe/unsubscribe

### Dedup Complexity
- Need to track both past (last capture time) and future (next scheduled time)
- Pending annotations add state management complexity
- **Consider**: Should dedup threshold be per-collector or global?

### Event Definition Ambiguity
- Graph defines events, but orchestrator inserts Move actions
- Need clear definition: Does Move action count as part of the event?
- **Current proposal**: Yes, first action (including Move) = event start

---

## Summary

This plan outlines a comprehensive event-driven frame capture system that:
1. Captures frames at event boundaries (start/end) in addition to scheduled captures
2. Maintains perfect 30 FPS video timing by excluding event frames from video
3. Provides crash-safe incremental mapping between events and frame IDs
4. Implements intelligent deduplication to avoid redundant captures
5. Supports multiple architecture options based on performance requirements

**Next Steps**: Address outstanding questions Q1-Q5, then proceed with implementation.
