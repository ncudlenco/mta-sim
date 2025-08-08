# ActionsOrchestrator.lua

## Purpose
This is the core action coordination system that manages temporal constraints between multiple actors in graph-based stories. It processes complex synchronization requirements (after, before, starts_with, concurrent) and coordinates context switching between different episodes/locations.

## Key Functions/Classes

### Core Class: ActionsOrchestrator
Manages action queues, temporal constraints, and multi-actor synchronization.

### Primary Methods

**Queue Management:**
- **`EnqueueAction(action, actor)`** - Main entry point, routes to graph or linear processing
- **`EnqueueActionGraph(action, actor)`** - Handles graph-based stories with temporal constraints
- **`EnqueueActionLinear(action, actor)`** - Handles simple linear action execution
- **`TriggerActionFromQueue(actor)`** - Executes queued action after context switch

**Temporal Constraint Processing:**
- **`GetTemporalConstraints(actor, action, lastEvent)`** - Extracts temporal requirements from graph
- **`ValidateSingularConstraints()`** - Validates after/before constraints
- **`ValidateConcurrentConstraints()`** - Validates starts_with/concurrent constraints
- **`ProcessActionRequests()`** - Main constraint satisfaction processor

**Execution Methods:**
- **`ExecuteSingularRequests()`** - Executes actions without timing dependencies
- **`ExecuteStartsWithRequests()`** - Executes simultaneous actions
- **`ExecuteConcurrentRequests()`** - Executes actions with random delays

**Utility:**
- **`Reset()`** - Clears all queues and state for new story

## Dependencies
- **CURRENT_STORY** - Active story instance (GraphStory or linear story)
- **CameraHandler** - Manages focus and context switching
- **Timer** - For delayed concurrent action execution

## Data Flow

1. **Action Request** → Extract temporal constraints from graph
2. **Constraint Validation** → Check if dependencies are satisfied
3. **Execution Ordering** → starts_with → concurrent → singular
4. **Context Management** → Handle episode switches and camera focus
5. **Action Application** → Execute validated actions

## Key Data Structures

### actionRequests
```lua
{
    actorId = {
        eventId = "graph_event_id",
        actor = actorObject,
        action = actionObject,
        constraints = {
            {actorId, eventId, constraint},
            ...
        },
        isValid = boolean,
        performed = boolean
    }
}
```

### Constraint Types
- **after**: Action starts after target event completes
- **before**: Action must complete before target event starts
- **starts_with**: Actions start simultaneously
- **concurrent**: Actions start in random order with max delay

## Architecture Notes

### Temporal Constraint Algorithm
1. **Constraint Extraction**: Parse graph temporal relationships
2. **Dependency Building**: Create constraint tree between actors/events
3. **Validation Pipeline**: 
   - Singular constraints (after/before)
   - Concurrent constraints (starts_with/concurrent)
4. **Execution Ordering**: Process constraint groups in priority order

### Context Switching Management
Critical for multi-episode stories:
- Detects when actor needs different episode context
- Queues action until camera focus switches
- Coordinates with CameraHandler for seamless transitions
- Prevents action execution in wrong context

### Deadlock Prevention
The system includes safeguards against temporal deadlocks:
- Validates constraint satisfaction before execution
- Uses fulfilled event tracking to prevent circular dependencies
- Implements timeout mechanisms through story time limits

### Multi-Actor Synchronization
Complex synchronization patterns supported:
- **Sequential**: A1.e1 → A2.e1 → A2.e2 (after relationships)
- **Parallel**: A1.e1 ↔ A2.e1 (starts_with relationships)  
- **Interleaved**: A1.e1 ⟷ A2.e1 (concurrent with delays)
- **Mixed**: Combinations of above patterns

### Interaction Handling
Special handling for multi-actor interactions:
- Only initiating actor triggers interaction request
- Constraint system automatically includes target actor
- Enforces proper sequencing for complex social actions

### State Tracking
- **fulfilled**: Completed events for constraint checking
- **actionQueue**: Actions awaiting context switch
- **lock**: Prevents concurrent processing conflicts

### Constraint Validation Process
1. **Singular Validation**: Check if after/before dependencies met
2. **Concurrent Validation**: Verify all linked actors ready
3. **Execution Grouping**: Group actions by constraint type
4. **Timing Application**: Apply delays for concurrent actions

### Camera Integration
Tight integration with camera system:
- Clears focus requests when new actions queued
- Requests focus for context switches
- Ensures proper visual continuity during episode transitions

This system enables sophisticated temporal choreography of multi-actor stories with precise synchronization control, making it possible to generate complex interactive narratives in 3D environments.