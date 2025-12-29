# Complete Action Planning and Execution Flow

## Overview

The story system orchestrates actor actions through a multi-stage pipeline involving graph processing, location-based action selection, temporal constraint validation, POI queue coordination, and final execution. This document traces the complete flow from `GraphStory.ProcessActions` through action completion.

---

## 1. Initial Action Planning (GraphStory.ProcessActions)

**File:** `src/story/GraphStory.lua:1833-1945`

### Entry Point
`GraphStory:ProcessActions(graphActors)` is called during story initialization after valid episodes are selected. It establishes initial actor positions and prepares action chains.

### Key Responsibilities

1. **Object Mapping**: Maps all required graph objects to simulator objects via `MapObjectsActionsAndPoi()` (line 1855)
   - Creates `eventObjectMap`: `{[graphObjectId] = [{value, chainId}, ...]}`
   - Creates `poiMap`: `{[graphEventId] = [{value=locationId, chainId}, ...]}`
   - Creates `eventMap`: `{[graphEventId] = [{value=actionId, chainId}, ...]}`
   - Each mapping includes `chainId` for conflict resolution

2. **Actor Initialization** (line 1879-1942):
   - For each actor, finds their `starting_actions` event from temporal graph
   - Uses `poiMap[firstEvent.id]` to resolve initial POI location (handles duplicate location names across episodes)
   - Spawns actor at resolved POI: `firstLocation.isBusy = true`
   - Sets actor data:
     - `startingPoiIdx`: Index in episode.POI array
     - `locationId`: The POI's LocationId
     - `position`, `rotation`, `interior`: Physical spawn point
   - Stores initial state:
     - `nextEvents[actorId] = firstEvent` (with `isStartingEvent = true`)
     - `nextLocations[actorId] = firstLocation`
   - Initializes `interactionPoiMap` and `interactionProcessedMap` (shared across all actors)

### Critical Data Structures Created

```lua
-- Maps graph event IDs to POI locations (one-to-many with chain IDs)
self.poiMap = {
    [eventId] = {
        {value = locationId, chainId = "living_room_1_123"},
        {value = locationId2, chainId = "living_room_2_124"}
    }
}

-- Maps graph object IDs to simulator objects (one-to-many with chain IDs)
self.eventObjectMap = {
    [graphObjectId] = {
        {value = "sofa_01", chainId = "living_room_1_123"},
        {value = "sofa_02", chainId = "living_room_2_124"},
        {value = "spawnable", chainId = -1}  -- For cigarettes, phones
    }
}

-- Tracks which interaction POI was claimed by which actor pair
self.interactionPoiMap = {
    [interactionRelation] = locationId  -- First actor claims POI
}

-- Prevents duplicate interaction processing
self.interactionProcessedMap = {
    [interactionRelation] = true  -- Only first actor executes interaction
}
```

---

## 2. Action Queuing and POI Selection (Location.ProcessNextAction)

**File:** `src/story/Locations/Location.lua:685-1490`

### Entry Point
Called from `Location:GetNextValidAction()` (line 1544) when actor needs next action. This is triggered by:
- Initial spawn: `OnGlobalActionFinished()` after all spectators spawn (Player.lua:159)
- Action completion: `OnGlobalActionFinished()` callback loop

### Flow Overview

1. **Retrieve Current State** (line 686-694)
   - `event = CURRENT_STORY.nextEvents[actorId]` (set by previous ProcessNextAction or initialization)
   - `location = CURRENT_STORY.nextLocations[actorId]` (current POI)
   - `previousLocation = CURRENT_STORY.lastLocations[actorId]` (previous POI)
   - If `event == nil`, returns (story ended for this actor)

2. **Determine Next Event** (line 718-740)
   - If `event.isStartingEvent`: `nextEvent = event` (first action)
   - Else: `nextEvent = CURRENT_STORY:GetNextEvent(event.id, actorId)` from temporal graph
   - Mark if interaction: `nextEvent.isInteraction = Any(CURRENT_STORY.Interactions, ...)`
   - For interactions, extract:
     - `interactionRelation`: The constraint ID linking both actors
     - `interactionEvent`: The paired actor's event

### 2.1 Artificial Move Insertion (line 742-821)

**When**: If `previousLocation ~= location` (actor needs to change POI)

**Process**:

1. **Detect Entity-Based Moves** (line 746-793):
   - If `event.Action == 'Move'` and `#event.Entities == 2`:
     - Target is `event.Entities[2]` (actor or object entity)
     - **Actor target**: `entityType = 'actor'`, Move tracks actor dynamically
     - **Object target** (line 764-789):
       - Check if object is held by another actor (`pickedObjects` data)
       - If held: redirect to `actor` move (`entityType = 'actor'`)
       - If not held: resolve to POI via `FindPOIForObject()` (`entityType = 'object'`)

2. **Create Move Action** (line 795-810):
   - Find Move template: `FirstOrDefault(previousLocation.allActions, ...)`
   - Determine `interactionOffset` if moving toward interaction POI
   - Call `CreateMoveAction(targetLocation, nextEvent, moveTemplate, interactionOffset, targetEntityId, entityType, isArtificial)`
     - **Artificial flag**: `isArtificial = not isMoveEvent` (line 808)
     - Artificial moves skip temporal constraint validation in ActionsOrchestrator
   - **Interaction POI Handling** (line 586-596 in CreateMoveAction):
     - First actor: claims POI via `interactionPoiMap[relation] = locationId`
     - Second actor: creates clone with offset `CreateInteractionClone()`
   - Insert Move into `actionsQueues[actorId]`

3. **Set nextTargetLocation** (line 812-820):
   - Critical for interaction synchronization
   - `player:setData('nextTargetLocation', moveClone.NextLocation.LocationId)`
   - Used by Wait actions to detect when both actors are heading to same POI

### 2.2 Event Action Instantiation (line 823-1012)

**Skip if**: `event.isStartingEvent` or `event.Action == 'Move'` (Move already handled)

#### 2.2.1 Interaction Actions (line 833-884)

**When**: `event.isInteraction == true`

**Process**:

1. Find both actors: `ped1 = event.Entities[1]`, `ped2 = event.Entities[2]`

2. **Check Processing Status**:
   - If `interactionProcessedMap[event.interactionRelation]` exists:
     - **Second actor path**: Create Wait with `doNothing=true` (passive wait)
     - This actor won't execute interaction, just waits for completion
   - Else:
     - **First actor path** (line 843-883):
       - Create Wait with `doNothing=false` (active wait)
       - Create interaction action (HandShake, Kiss, Hug, Give, INV-Give, Laugh, Talk)
       - Chain: `wait.NextAction = interactionAction`
       - Store action: `CURRENT_STORY.interactionActionMap[relation] = eventAction` (for offset retrieval)
       - Mark processed: `interactionProcessedMap[relation] = true`

3. **Insert Wait Action**: `table.insert(actionsChain, wait)`
   - Wait action monitors `targetInteraction` relation
   - Completes when both actors reach target POI and constraints satisfied

#### 2.2.2 Non-Interaction Actions (line 885-1011)

**Instantiation Priority** (each step returns if successful):

1. **Picked Object Actions** (line 904-942):
   - Check if `pickedObjects[1][1] == GetMappedEventObjectId(event.Entities[2])`
   - Find object in `CurrentEpisode.Objects` by `ObjectId`
   - Call `InstantiateAction(event, player, location, object)`
   - Creates: Drink, LookAt, Wave, TakeOut, Stash, AnswerPhone, TalkPhone, HangUp, SmokeIn, Smoke, SmokeOut

2. **Spawnable Object Actions** (line 945-962):
   - Call `GetOrCreateSpawnableObject(event, player)`
     - Checks `eventObjectMap[event.Entities[2]] == 'spawnable'`
     - Looks up inventory slot via `PedHandler:HasInInventory()`
     - Returns existing instance or creates new one for TakeOut
     - Assigns `ObjectId = 'spawnable_<type>_<actorId>'`
   - Call `InstantiateAction()` with spawnable instance

3. **LookAt/Wave with Actor Target** (line 964-983):
   - Check if `target.Properties.Gender` exists (it's an actor)
   - Find target ped: `FirstOrDefault(CurrentEpisode.peds, ...)`
   - Call `InstantiateAction(event, player, location, targetActor)`

4. **Fallback to Template Actions** (line 984-998):
   - `FirstOrDefault(location.allActions, function(a) return a.Name:lower() == event.Action:lower() end)`
   - Uses pre-defined POI actions from templates

**Insert into Chain**: `table.insert(actionsChain, eventAction)` (line 1010)

### 2.3 Next Location Selection (line 1056-1476)

**Determines** where the `nextEvent` should execute.

#### 2.3.1 Build Candidate List

**If POI Mapped** (line 1123-1170):
- Use `poiMap[nextEvent.id]` to filter `CurrentEpisode.POI`
- Each POI gets metadata: `poi:setData("mappedChainId_"..nextEvent.id, chainId)`
- **Chain Filtering**:
  - If actor has `mappedChainId`: only use POIs with matching chain
  - Else: exclude chains assigned to other actors (via `getOtherActorChainIds()`)
  - Fallback: use any mapped POI if no matches

**Else (No Mapping)** (line 1172-1241):
- **Interaction POIs**: `poi.interactionsOnly` and relation not claimed OR matches claimed POI
- **Region Match**: `poi.Region.name:lower():find(targetLocation:lower())`
  - For entity-based Move: resolve entity to region first
  - For location-based Move: use `event.Location[2]`
- **Action Match**: POI has action with matching name and object type
  - Special handling: `GetMappedEventObjectId()` checks for spawnable or matching object

**Special Overrides** (line 1243-1254):
- Picked object actions: only region match required
- LookAt/Wave/Middle actions with picked object: use current `location`

#### 2.3.2 Spatial Constraint Filtering (line 1263)

`FilterCandidatesBySpatialConstraints(candidates, nextEvent, materializedObjects)`:
- Only applies to non-interaction events with objects
- Validates each POI's object position against materialized objects
- Calls `SpatialCoordinator:ValidateAllConstraints()`
- Returns filtered list

#### 2.3.3 Selection Logic (line 1275-1328)

**Get Conflict Data**:
- `otherActorChainIds`: chains assigned to other actors
- `occupiedPOIs`: POIs currently occupied or reserved by other actors

**Selection Priority**:

1. **No candidates**: Use current location as fallback
2. **All busy**:
   - Filter for non-conflicting chains: `not otherActorChainIds[poiChainId]` and `not occupiedPOIs[poi.LocationId]`
   - If found: `chainSelectionSucceeded = true`, pick random
   - Else: pick random busy POI
3. **Available candidates**:
   - Filter available (not busy)
   - Apply chain conflict filtering
   - If found: `chainSelectionSucceeded = true`, pick random
   - Else: pick random available POI

**Current Location Override** (line 1331-1356):
- **Only if** chain selection failed
- **Only if** current location is in candidates
- **Skip for interactions** unless current location matches claimed POI
- Purpose: Keep actor at same POI for sequential actions (SitDown, PickUp, Eat, GetUp)

#### 2.3.4 Interaction POI Correction (line 1362-1400)

**For interactions**:
1. Verify `nextLocation.LocationId == interactionPoiMap[relation]`
2. If mismatch: force correct POI (line 1365-1377)
3. Check if should clone (line 1379-1392):
   - `ShouldCloneForInteraction()`: POI is `interactionsOnly` and already claimed
   - Retrieve `interactionOffset` from stored `interactionActionMap[relation]`
   - Create clone: `CreateInteractionClone(nextLocation, offset)`
4. First actor claims POI: `interactionPoiMap[relation] = nextLocation.LocationId`

### 2.4 Chain Assignment and Materialization (line 1407-1456)

1. **Assign Chain ID** (line 1407-1418):
   - Extract: `newChainId = nextLocation:getData("mappedChainId_"..nextEvent.id)`
   - Set: `player:setData('mappedChainId', newChainId)`
   - This locks actor to specific object instances for event chain

2. **Reserve Location** (line 1421-1426):
   - If changing locations: `player:setData('reservedLocationId', nextLocation.LocationId)`
   - Prevents other actors from selecting during look-ahead

3. **Materialize Object** (line 1429-1455):
   - For non-interaction events with objects
   - Get object via `GetMappedEventObjectId(eventObjectId, chainId)`
   - Find instance: `FirstOrDefault(CurrentEpisode.Objects, ...)`
   - Call `SpatialCoordinator:MaterializeObject()`:
     - Records position, rotation, element reference
     - Used for future spatial constraint validation
     - Tracks which actor claimed which object instance

### 2.5 Update Story State (line 1476-1478)

```lua
CURRENT_STORY.nextEvents[actorId] = nextEvent
CURRENT_STORY.nextLocations[actorId] = nextLocation
CURRENT_STORY.lastLocations[actorId] = location
```

### 2.6 Queue Actions (line 1047-1049)

All actions in `actionsChain` added to `CURRENT_STORY.actionsQueues[actorId]`:
- Artificial Move (if location changed)
- Wait (if interaction)
- Event action
- NextAction chain actions (not currently processed)

---

## 3. Action Orchestration (ActionsOrchestrator)

**File:** `src/api/ActionsOrchestrator.lua`

### Entry Point: EnqueueAction (line 23-30)

Called from:
- `OnGlobalActionFinished()` (ActionsGlobals.lua:169,171)
- Routes to `EnqueueActionGraph()` or `EnqueueActionLinear()`

### 3.1 EnqueueActionGraph (line 36-85)

**Purpose**: Extract and validate temporal constraints from graph.

**Process**:

1. **Find Last Event** (line 52-63):
   - Retrieve: `lastEvents = CURRENT_STORY.lastEvents[actorId]`
   - Get: `lastEvent = actorEvents[#actorEvents]`
   - Use provided `eventId` or fallback to `lastEvent.id`
   - Mark previous event as fulfilled: `table.insert(self.fulfilled, previousEvent.id)`

2. **Extract Constraints** (line 76): `GetTemporalConstraints(actor, action, lastEvent)` (line 106-167)

   **Returns constraints array**: `{actorId, eventId, constraint}[]`

   **Constraint Types**:

   a. **starts_with** (line 126-148):
      - **Skip for artificial actions** (navigation moves)
      - Find linked events via `CURRENT_STORY.temporal[constraintId].relations`
      - For each linked event with different actor:
        - Add starts_with constraint: `{actorId=linkedActor, eventId=linkedEvent, constraint}`
        - Add implicit after constraint for event before linked starts_with

   b. **concurrent/after** (line 149-152):
      - Always extracted (even for artificial actions)
      - Target event must be fulfilled

   c. **before** (line 158-163):
      - Find all constraints where `target == lastEvent.id`
      - Source events must be fulfilled before current can start

3. **Store Request** (line 77):
   ```lua
   self.actionRequests[actorId] = {
       eventId = effectiveEventId,
       actor = actor,
       action = action,
       constraints = constraints
   }
   ```

4. **Process Requests** (line 84): `ProcessActionRequests()`

### 3.2 ProcessActionRequests (line 270-296)

**Validation Pipeline**:

1. **ValidateSingularConstraints** (line 169-203):
   - For each constraint:
     - **after**: satisfied if `inList(constraintEventId, self.fulfilled)`
     - **before**: satisfied if `inList(constraintEventId, self.fulfilled)`
   - Remove satisfied constraints from request
   - If `#request.constraints == 0`: `request.isValid = true`

2. **ValidateConcurrentConstraints** (line 205-259):
   - For requests with concurrent/starts_with constraints
   - **Check**: All after/before constraints satisfied for this request
   - **AND**: All after/before constraints satisfied for linked concurrent requests
   - If valid: mark all concurrent requests as valid together

**Execution Order**:

3. **ExecuteStartsWithRequests** (line 363-390):
   - Find all requests with `starts_with` constraints
   - Collect all linked requests: `concat({request}, linkedRequests)`
   - Execute all simultaneously: `EnqueueActionLinear()` for each
   - Mark `performed = true`

4. **ExecuteConcurrentRequests** (line 319-362):
   - Find requests with `concurrent` constraints
   - Shuffle execution order
   - Apply random delay: `Timer(..., math.random(0, max_delay), ...)`
   - Execute with delay: `EnqueueActionLinear()`

5. **ExecuteSingularRequests** (line 299-317):
   - For all valid, unperformed requests
   - Execute immediately: `EnqueueActionLinear()`

6. **Process POI Queues** (line 290-296):
   - After execution, process all POI queues
   - Handles actions that freed POIs

### 3.3 EnqueueActionLinear (line 392-423)

**Purpose**: POI queue coordination and context switch handling.

**Flow**:

1. **Check Location Mismatch** (line 403-421):
   - `actorLocation = actor:getData('locationId')`
   - `requiredLocation = action.NextLocation.LocationId`
   - If `actorLocation ~= requiredLocation`:
     - **Enqueue for POI**: `EnqueueForPOI(actor, action, eventId, requiredLocation)`
     - **Return early** (action will execute when POI acquired)

2. **Else**: Direct execution via `TriggerActionExecution()`

### 3.4 EnqueueForPOI (line 690-723)

**Purpose**: Queue actor for POI access, handling conflicts.

**Process**:

1. Initialize queue: `self.poiQueues[locationId] = {}`
2. Check if actor already queued (skip duplicate)
3. Add entry: `{actor, action, eventId}`
4. Set actor data: `actor:setData('queuedForLocationId', locationId)`
5. If first in queue: `ProcessPOIQueue(locationId)` (try immediate acquisition)

### 3.5 ProcessPOIQueue (line 728-831)

**Purpose**: Try to grant POI access to first actor in queue.

**Flow**:

1. **Get First Actor** (line 732-742):
   - `first = queue[1]`
   - Find target POI in `CurrentEpisode.POI`

2. **Check Availability** (line 745-778):
   - Find occupying actor: `ped:getData('locationId') == locationId`
   - **Can acquire if**:
     - No occupant OR
     - Occupant is same actor OR
     - `CanActorBeDisplaced(occupyingActor)` succeeds AND `DisplaceActor()` succeeds OR
     - Both actors targeting same interaction (allow shared POI with clone)

3. **If Acquired** (line 780-825):
   - Remove from queue: `table.remove(queue, 1)`
   - Clear queued flag: `actor:setData('queuedForLocationId', nil)`
   - **Insert Corrective Move** (line 791-816):
     - If actor displaced since queueing and action isn't Move
     - Find Move action to target POI
     - Insert into `actionsQueues[actorId]`
     - Apply Move first (original action executes after)
   - **Else**: Execute immediately via `TriggerActionExecution()`
   - Process next in queue: `ProcessPOIQueue(locationId)` (recursive)

### 3.6 CanActorBeDisplaced (line 498-576)

**Rules** (in order):

1. **Cannot displace** if first in queue and POI acquirable (about to execute)
2. **Can displace** if story ended (`storyEnded = true`)
3. **Cannot displace** if waiting for interaction (`isWaitingForInteraction = true`)
4. **Cannot displace** if in interaction action (`currentAction in Interactions`)
5. **Can displace** if in `interactionsOnly` POI doing non-interaction action
6. **Can displace** if awaiting constraints (`isAwaitingConstraints = true`)
7. **Default**: Cannot displace (actively executing)

### 3.7 DisplaceActor (line 588-683)

**Priority** (selects Move target):

1. POIs with no actions, same region, not busy, not reserved
2. POIs not busy/reserved, same region
3. POIs with no actions, any region
4. POIs not busy/reserved, any region
5. Fallback: any non-busy POI

**Process**:
- Remove from POI queue if queued
- Mark target busy: `targetMove.NextLocation.isBusy = true`
- Update locationId: `actor:setData('locationId', targetId)`
- Apply Move: `targetMove:Apply()`

### 3.8 TriggerActionExecution (line 425-447)

**Final step before action execution**.

**Process**:

1. **Store Event ID** (line 428-430):
   - `actor:setData('currentGraphEventId', eventId)` (skip for artificial actions)
   - Used by `OnGlobalActionFinished` to publish event completion

2. **Check Context Switch** (line 432-446):
   - `shouldAwait = actor:getData('currentEpisode') ~= CURRENT_STORY.CurrentFocusedEpisode`
   - If different episode:
     - `actor:setData('isAwaitingContextSwitch', true)`
     - Store in queue: `self.actionQueue[actorId] = {action, eventId}`
     - Request camera focus: `CameraHandler:requestFocus(actorId)`
     - **Wait** for CameraHandler to switch context and call `TriggerActionFromQueue()`
   - Else:
     - Publish event start: `PublishActionStarted(actor, action, eventId)`
     - Execute: `action:Apply()`

### 3.9 PublishActionStarted (line 449-473)

**Purpose**: Emit event to EventBus for camera/logging systems.

**Validation**:
- Only for graph stories with valid eventId
- Only if action is not artificial
- Only if action name matches normalized expected action from graph
  - Normalization handles: `INV-Give → Receive`
- Publishes: `graph_event_start` with `{eventId, actorId, actionName}`

### 3.10 TriggerActionFromQueue (line 475-493)

**Called by**: CameraHandler after context switch completes.

**Process**:
- Retrieve: `action = self.actionQueue[actorId]`
- Clear flag: `actor:setData('isAwaitingContextSwitch', false)`
- Publish: `PublishActionStarted(actor, action.action, action.eventId)`
- Execute: `action.action:Apply()`
- Clear queue: `self.actionQueue[actorId] = nil`

---

## 4. Action Execution and Completion

### 4.1 Action Execution (StoryActionBase:Apply)

**What happens** (simplified, actual implementation varies by action):

1. Action performs its game logic (play animation, move ped, spawn object, etc.)
2. On completion, calls `OnGlobalActionFinished(delay, playerId, storyId, callback)`

### 4.2 OnGlobalActionFinished (ActionsGlobals.lua:7-182)

**Purpose**: Loop back to get next action for actor.

**Flow**:

1. **Execute Callback** (line 35-47):
   - If provided, execute custom callback (e.g., for animation state preservation)

2. **Publish Event End** (line 57-83):
   - Retrieve: `completedEventId = actor:getData('currentGraphEventId')`
   - Preserve for NextAction propagation: `eventIdForNextAction = completedEventId`
   - Validate action name matches expected graph action (with normalization)
   - Publish: `graph_event_end` event to EventBus
   - Clear: `actor:setData('currentGraphEventId', nil)`

3. **Handle Pause Request** (line 85-93):
   - If `requestPause = true`: set `paused = true`, request camera focus, return

4. **Retrieve Next Action** (line 96-137):

   **Case 1: No Last Action** (line 99-118):
   - First action protocol
   - Get: `idx = actor:getData('startingPoiIdx')`
   - Call: `CurrentEpisode.POI[idx]:GetNextValidAction(actor)`

   **Case 2: Linear Story with NextAction Chain** (line 120-127):
   - `nextAction = lastAction.NextAction` (pick random if array)
   - Set: `isNextActionFromChain = true`

   **Case 3: Graph Story** (line 129-136):
   - Call: `lastAction.NextLocation:GetNextValidAction(actor)`
   - This triggers `Location:ProcessNextAction()` → full cycle repeats

5. **Enqueue Next Action** (line 163-172):
   - **If from NextAction chain**: `EnqueueAction(nextAction, actor, eventIdForNextAction)`
     - Preserves eventId for NextAction inheritance
   - **Else**: `EnqueueAction(nextAction, actor)` (lookup eventId from lastEvents)

---

## 5. Special Cases

### 5.1 Interaction Actions

**Unique Properties**:
- Two actors, one action instance
- First actor executes, second waits passively
- Shared POI with offset positioning for second actor

**Flow**:

1. **ProcessNextAction** detects interaction (line 833)
2. **First Actor**:
   - Creates active Wait (`doNothing=false`)
   - Creates interaction action (Talk, Hug, etc.)
   - Chains: `wait.NextAction = interactionAction`
   - Stores: `interactionActionMap[relation] = action` (for offset)
   - Marks: `interactionProcessedMap[relation] = true`
   - Claims POI: `interactionPoiMap[relation] = locationId`
3. **Second Actor**:
   - Finds `interactionProcessedMap[relation] == true`
   - Creates passive Wait (`doNothing=true`)
   - Receives cloned POI with offset
4. **Wait Action**:
   - Monitors `targetInteraction` relation
   - Checks both actors at target POI
   - Checks constraints satisfied
   - First actor: executes interaction when ready
   - Second actor: completes when first actor finishes

### 5.2 Artificial Move Actions

**Purpose**: Navigation between locations, not graph events.

**Characteristics**:
- Created when `previousLocation ~= nextLocation` (line 742)
- Marked: `move.isArtificial = true` (line 808, 809)
- **Skip temporal constraints**: `GetTemporalConstraints()` skips starts_with for artificial (line 129)
- **Skip event publication**: Not published to EventBus (line 428, 452)

**Why Needed**:
- Graph only specifies actions, not all movements
- Ensures actor physically moves to correct POI before action

### 5.3 Wait Actions for Interactions

**Two Types**:

1. **Active Wait** (`doNothing=false`, line 844):
   - First actor
   - Has `NextAction = interactionAction`
   - Monitors and executes interaction when ready

2. **Passive Wait** (`doNothing=true`, line 841):
   - Second actor
   - No NextAction
   - Just waits for first actor to complete
   - Completes when interaction finishes

**Synchronization**:
- Uses `nextTargetLocation` data (set during Move creation, line 816)
- Actors can detect partner is heading to same POI even before arrival
- Prevents premature Wait completion

### 5.4 Clone/Offset POI Creation

**When**: Second actor in interaction moves to already-claimed POI.

**Process** (Location.lua:522-542):
1. Clone original POI: `Location(..., offset.x, offset.y, offset.z, ...)`
2. Copy metadata: `LocationId`, `allActions`, `Episode`, `interactionsOnly`
3. Mark: `clone.isClone = true` (bypasses POI queue coordination)
4. Store: `clone.originalLocationId` (debugging reference)

**Offset** (line 523):
- Default: `Vector3(-0.7, -0.7, 0)`
- Or retrieved from stored `interactionActionMap[relation].InteractionOffset`

**Result**: Both actors at same logical POI but different physical positions.

### 5.5 Chain ID System

**Purpose**: Prevent actor conflicts when multiple valid object/POI mappings exist.

**Lifecycle**:

1. **Creation** (GraphStory.lua:1657):
   - `chainId = poiDescription_poiRegion_poiLocationId_globalCounter`
   - Each POI gets unique chain even for same object type

2. **Assignment** (Location.lua:1412):
   - When actor selects next location: `player:setData('mappedChainId', newChainId)`
   - Locks actor to specific object instances for event chain

3. **Usage**:
   - `GetMappedEventObjectId(eventObjectId, playerChainId)` (line 206-255)
     - Prefers mapping with matching chainId
     - Fallback: first available mapping if no match
   - POI selection filters chains already assigned to other actors (line 1155-1164)

**Conflict Prevention**:
- Two actors never share same chain unless intentional (interactions)
- Each actor gets consistent object instances throughout action sequence

---

## Key Data Flow Summary

```
GraphStory.ProcessActions
  ↓ (initialize actors, create eventObjectMap/poiMap)
  ↓
Location.ProcessNextAction (called from GetNextValidAction)
  ↓ (determine nextEvent, select nextLocation)
  ↓
  ├─ Insert Artificial Move (if location changed)
  ├─ Create Wait (if interaction)
  └─ Instantiate Event Action
  ↓ (add to actionsQueues[actorId])
  ↓
Location.GetNextValidAction (retrieves from queue)
  ↓ (dequeues action[1])
  ↓
ActionsOrchestrator.EnqueueAction
  ↓
ActionsOrchestrator.EnqueueActionGraph
  ↓ (extract temporal constraints)
  ↓
ActionsOrchestrator.ProcessActionRequests
  ↓ (validate constraints, execute starts_with/concurrent/singular)
  ↓
ActionsOrchestrator.EnqueueActionLinear
  ↓
  ├─ (if wrong location) → EnqueueForPOI → ProcessPOIQueue
  │                           ↓ (wait for POI available)
  │                           ├─ DisplaceActor (if needed)
  │                           └─ TriggerActionExecution
  └─ (if correct location) → TriggerActionExecution
                              ↓
                              ├─ (if context switch needed) → actionQueue (wait for CameraHandler)
                              │                                  ↓
                              │                            TriggerActionFromQueue
                              │                                  ↓
                              └─ (else) ────────────────────────┘
                                                                 ↓
                                                     PublishActionStarted (EventBus)
                                                                 ↓
                                                          action:Apply()
                                                                 ↓
                                                                ... (action executes)
                                                                 ↓
                                                  OnGlobalActionFinished
                                                                 ↓
                                                     PublishActionEnd (EventBus)
                                                                 ↓
                                                       Retrieve Next Action
                                                                 ↓
                                                                ...
                                                   (loop back to EnqueueAction)
```

---

## Critical Files Reference

- **GraphStory.lua:1833-1945**: Initial action planning, object/POI mapping
- **Location.lua:685-1490**: Next action queuing, POI selection, artificial move insertion
- **Location.lua:522-616**: Clone POI creation, Move action creation
- **Location.lua:206-255**: Chain-based object mapping
- **ActionsOrchestrator.lua:23-857**: Temporal constraint validation, POI queue management
- **ActionsGlobals.lua:7-182**: Action completion callback, next action retrieval
- **Player.lua:159**: Initial trigger after all spectators spawn
