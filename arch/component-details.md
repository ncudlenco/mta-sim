# Detailed Component Architecture

This document provides detailed architectural views of the key system components.

## GraphStory Engine Detailed Flow

```mermaid
flowchart TD
    subgraph "Initialization Phase"
        Init[Initialize GraphStory]
        LoadGraph[Load JSON Graph]
        ParseEvents[Parse Events & Actors]
        ValidateEpisodes[Validate Episodes]
    end
    
    subgraph "Mapping Phase"
        MapObjects[Map Graph Objects]
        MapActions[Map Graph Actions]
        MapPOIs[Map Points of Interest]
        CreateChains[Create Chain IDs]
    end
    
    subgraph "Execution Planning"
        ExtractConstraints[Extract Temporal Constraints]
        BuildActionQueue[Build Action Queue]
        InitializeOrchestrator[Initialize Orchestrator]
    end
    
    subgraph "Runtime Execution"
        ProcessQueue[Process Action Queue]
        HandleConstraints[Handle Temporal Constraints]
        ExecuteActions[Execute Individual Actions]
        UpdateState[Update System State]
    end
    
    Init --> LoadGraph
    LoadGraph --> ParseEvents
    ParseEvents --> ValidateEpisodes
    
    ValidateEpisodes --> MapObjects
    MapObjects --> MapActions
    MapActions --> MapPOIs
    MapPOIs --> CreateChains
    
    CreateChains --> ExtractConstraints
    ExtractConstraints --> BuildActionQueue
    BuildActionQueue --> InitializeOrchestrator
    
    InitializeOrchestrator --> ProcessQueue
    ProcessQueue --> HandleConstraints
    HandleConstraints --> ExecuteActions
    ExecuteActions --> UpdateState
    UpdateState --> ProcessQueue
```

## ActionsOrchestrator State Machine

```mermaid
stateDiagram-v2
    [*] --> Initializing
    Initializing --> Ready
    
    Ready --> ProcessingQueue
    ProcessingQueue --> CheckingConstraints
    
    CheckingConstraints --> ConstraintsSatisfied: All constraints met
    CheckingConstraints --> WaitingForConstraints: Constraints pending
    CheckingConstraints --> ConstraintsFailed: Constraints failed
    
    ConstraintsSatisfied --> RequestingLocation
    RequestingLocation --> LocationAssigned: Location found
    RequestingLocation --> LocationFailed: No location available
    
    LocationAssigned --> ExecutingAction
    ExecutingAction --> ActionComplete
    ExecutingAction --> ActionFailed
    
    ActionComplete --> ProcessingQueue
    ActionFailed --> ProcessingQueue
    
    WaitingForConstraints --> ProcessingQueue: Retry after delay
    ConstraintsFailed --> ProcessingQueue: Skip action
    LocationFailed --> ProcessingQueue: Retry or skip
    
    ProcessingQueue --> Complete: Queue empty
    Complete --> [*]
```

## Location Manager Decision Tree

```mermaid
flowchart TD
    Start[New Location Request]
    
    subgraph "Initial Filtering"
        GetCandidates[Get Available Locations]
        FilterByActor[Filter by Actor Constraints]
        FilterByObject[Filter by Object Requirements]
        FilterByAction[Filter by Action Compatibility]
    end
    
    subgraph "Chain ID Processing"
        CheckChainID{Chain ID<br/>Required?}
        FilterByChain[Filter by Chain ID]
        AssignNewChain[Assign New Chain ID]
    end
    
    subgraph "Proximity Analysis"
        CalcDistances[Calculate Distances]
        CheckOccupancy[Check Occupancy]
        ScoreLocations[Score Locations]
    end
    
    subgraph "Final Selection"
        HasCandidates{Any Valid<br/>Candidates?}
        SelectBest[Select Best Location]
        AddToWaitList[Add to Wait List]
    end
    
    Start --> GetCandidates
    GetCandidates --> FilterByActor
    FilterByActor --> FilterByObject
    FilterByObject --> FilterByAction
    
    FilterByAction --> CheckChainID
    CheckChainID -->|Yes| FilterByChain
    CheckChainID -->|No| AssignNewChain
    FilterByChain --> CalcDistances
    AssignNewChain --> CalcDistances
    
    CalcDistances --> CheckOccupancy
    CheckOccupancy --> ScoreLocations
    
    ScoreLocations --> HasCandidates
    HasCandidates -->|Yes| SelectBest
    HasCandidates -->|No| AddToWaitList
    
    SelectBest --> End[Return Location]
    AddToWaitList --> End
```

## Template Resolution Process

```mermaid
sequenceDiagram
    participant Client as Client
    participant ST as Supertemplate
    participant T as Template
    participant Resolver as Template Resolver
    participant Coords as Coordinate System
    participant Validator as Validator

    Client->>ST: Request Template Resolution
    ST->>ST: Load Referenced Templates
    
    loop For Each Referenced Template
        ST->>T: Load Template Definition
        T->>Resolver: Parse Template Objects
        T->>Resolver: Parse Template Actions
        T->>Resolver: Parse Template POIs
        
        Resolver->>Coords: Transform Coordinates
        Coords->>Resolver: Return World Coordinates
        
        Resolver->>Validator: Validate Template
        Validator->>Resolver: Return Validation Result
        
        alt Validation Successful
            Resolver->>ST: Add to Resolution Set
        else Validation Failed
            Resolver->>ST: Report Error
        end
    end
    
    ST->>Client: Return Resolved Templates
```

## Object Mapping Chain System

```mermaid
graph TD
    subgraph "Chain ID System"
        ChainGenerator[Chain ID Generator]
        ChainRegistry[Chain Registry]
        ChainValidator[Chain Validator]
    end
    
    subgraph "Object Categories"
        FixedObjects[Fixed Objects<br/>Furniture, TVs, etc.]
        SpawnableObjects[Spawnable Objects<br/>Cigarettes, Phones, etc.]
        SharedObjects[Shared Objects<br/>Tables, Chairs, etc.]
    end
    
    subgraph "Chain Assignment Logic"
        NewChain{Need New<br/>Chain ID?}
        ExistingChain[Use Existing Chain]
        CreateChain[Create New Chain]
        ValidateChain[Validate Chain Consistency]
    end
    
    subgraph "Conflict Resolution"
        ChainConflict{Chain ID<br/>Conflict?}
        ResolveConflict[Resolve Conflict]
        WaitForRelease[Wait for Chain Release]
        FindAlternative[Find Alternative Object]
    end
    
    ChainGenerator --> ChainRegistry
    ChainRegistry --> ChainValidator
    
    FixedObjects --> NewChain
    SpawnableObjects --> NewChain
    SharedObjects --> NewChain
    
    NewChain -->|No| ExistingChain
    NewChain -->|Yes| CreateChain
    ExistingChain --> ValidateChain
    CreateChain --> ValidateChain
    
    ValidateChain --> ChainConflict
    ChainConflict -->|No| End[Assign Chain]
    ChainConflict -->|Yes| ResolveConflict
    
    ResolveConflict --> WaitForRelease
    ResolveConflict --> FindAlternative
    WaitForRelease --> ValidateChain
    FindAlternative --> ValidateChain
```

## MetaEpisode Management System

```mermaid
flowchart TD
    subgraph "MetaEpisode Initialization"
        CreateME[Create MetaEpisode]
        LoadEpisodes[Load Component Episodes]
        ValidateLinks[Validate Episode Links]
        BuildActorMap[Build Actor Distribution Map]
    end
    
    subgraph "Episode Coordination"
        ActorDistribution[Distribute Actors Across Episodes]
        LinkProcessing[Process Episode Links]
        MovementGeneration[Generate Movement Actions]
        ContextManagement[Manage Episode Contexts]
    end
    
    subgraph "Cross-Episode Operations"
        MoveBetweenEpisodes[Move Actor Between Episodes]
        SynchronizeStates[Synchronize Episode States]
        TransferObjects[Transfer Objects Between Episodes]
        UpdateContexts[Update All Episode Contexts]
    end
    
    subgraph "Runtime Management"
        MonitorActors[Monitor Actor Locations]
        HandleMovements[Handle Episode Transitions]
        MaintainConsistency[Maintain Cross-Episode Consistency]
        CleanupResources[Cleanup Episode Resources]
    end
    
    CreateME --> LoadEpisodes
    LoadEpisodes --> ValidateLinks
    ValidateLinks --> BuildActorMap
    
    BuildActorMap --> ActorDistribution
    ActorDistribution --> LinkProcessing
    LinkProcessing --> MovementGeneration
    MovementGeneration --> ContextManagement
    
    ContextManagement --> MoveBetweenEpisodes
    MoveBetweenEpisodes --> SynchronizeStates
    SynchronizeStates --> TransferObjects
    TransferObjects --> UpdateContexts
    
    UpdateContexts --> MonitorActors
    MonitorActors --> HandleMovements
    HandleMovements --> MaintainConsistency
    MaintainConsistency --> CleanupResources
    
    CleanupResources --> MonitorActors
```

## Debug and Development Pipeline

```mermaid
graph LR
    subgraph "Content Creation"
        EpisodeEditor[3D Episode Editor]
        PathEditor[Path Network Editor]
        TemplateEditor[Template System Editor]
        ObjectPlacer[Interactive Object Placer]
    end
    
    subgraph "Development Tools"
        CommandInterface[Command Interface]
        RealTimeDebug[Real-time Debug System]
        StateInspector[State Inspector]
        ConstraintMonitor[Constraint Monitor]
    end
    
    subgraph "Testing Framework"
        MockMTA[MTA Mocks]
        TestRunner[Test Runner]
        ChainIDTester[Chain ID Tester]
        ScenarioTester[Scenario Tester]
    end
    
    subgraph "Output and Analysis"
        DebugLogger[Debug Logger]
        VideoCapture[Video Capture]
        StateExporter[State Exporter]
        MetricsCollector[Metrics Collector]
    end
    
    EpisodeEditor --> CommandInterface
    PathEditor --> CommandInterface
    TemplateEditor --> CommandInterface
    ObjectPlacer --> CommandInterface
    
    CommandInterface --> RealTimeDebug
    RealTimeDebug --> StateInspector
    StateInspector --> ConstraintMonitor
    
    ConstraintMonitor --> MockMTA
    MockMTA --> TestRunner
    TestRunner --> ChainIDTester
    ChainIDTester --> ScenarioTester
    
    ScenarioTester --> DebugLogger
    DebugLogger --> VideoCapture
    VideoCapture --> StateExporter
    StateExporter --> MetricsCollector
```

## System Integration Architecture

```mermaid
graph TD
    subgraph "External Interfaces"
        MTAAPI[MTA Server API]
        ClientInterface[Client Interface]
        FileSystem[File System]
        PythonTools[Python Tools]
    end
    
    subgraph "Core System"
        ServerGlobals[Server Globals]
        ServerCommands[Server Commands]
        GraphEngine[Graph Processing Engine]
        ActionSystem[Action Execution System]
    end
    
    subgraph "Content Management"
        EpisodeSystem[Episode Management]
        TemplateSystem[Template System]
        ObjectSystem[Object Management]
        LocationSystem[Location System]
    end
    
    subgraph "Execution Runtime"
        PedHandlers[Ped Handlers]
        CameraSystem[Camera System]
        PathfindingSystem[Pathfinding System]
        TimingSystem[Timing & Synchronization]
    end
    
    MTAAPI --> ServerGlobals
    ClientInterface --> ServerCommands
    FileSystem --> GraphEngine
    PythonTools --> FileSystem
    
    ServerGlobals --> GraphEngine
    ServerCommands --> ActionSystem
    GraphEngine --> ActionSystem
    
    ActionSystem --> EpisodeSystem
    ActionSystem --> TemplateSystem
    ActionSystem --> ObjectSystem
    ActionSystem --> LocationSystem
    
    EpisodeSystem --> PedHandlers
    TemplateSystem --> CameraSystem
    ObjectSystem --> PathfindingSystem
    LocationSystem --> TimingSystem
    
    PedHandlers --> MTAAPI
    CameraSystem --> MTAAPI
    PathfindingSystem --> MTAAPI
    TimingSystem --> MTAAPI
```