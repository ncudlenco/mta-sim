# Data Flow Architecture

This document details the data flow patterns throughout the MTA San Andreas Story Simulation System.

## Graph Processing Data Flow

```mermaid
flowchart TD
    subgraph "Input Data"
        GraphJSON[Story Graph JSON]
        EpisodeFiles[Episode JSON Files]
        TemplateFiles[Template JSON Files]
        PathFiles[Path JSON Files]
    end
    
    subgraph "Parsing Layer"
        GraphParser[Graph Parser]
        EpisodeParser[Episode Parser]
        TemplateParser[Template Parser]
        PathParser[Path Parser]
    end
    
    subgraph "Validation Layer"
        EventValidator[Event Validator]
        ActorValidator[Actor Validator]
        ObjectValidator[Object Validator]
        LocationValidator[Location Validator]
    end
    
    subgraph "Mapping Layer"
        ObjectMapper[Object Mapper]
        ActionMapper[Action Mapper]
        POIMapper[POI Mapper]
        ConstraintMapper[Constraint Mapper]
    end
    
    subgraph "Orchestration Layer"
        ActionQueue[Action Queue]
        ConstraintEngine[Constraint Engine]
        LocationEngine[Location Engine]
        ExecutionEngine[Execution Engine]
    end
    
    GraphJSON --> GraphParser
    EpisodeFiles --> EpisodeParser
    TemplateFiles --> TemplateParser
    PathFiles --> PathParser
    
    GraphParser --> EventValidator
    GraphParser --> ActorValidator
    EpisodeParser --> ObjectValidator
    EpisodeParser --> LocationValidator
    
    EventValidator --> ObjectMapper
    ActorValidator --> ActionMapper
    ObjectValidator --> POIMapper
    LocationValidator --> ConstraintMapper
    
    ObjectMapper --> ActionQueue
    ActionMapper --> ConstraintEngine
    POIMapper --> LocationEngine
    ConstraintMapper --> ExecutionEngine
    
    ActionQueue --> ExecutionEngine
    ConstraintEngine --> ExecutionEngine
    LocationEngine --> ExecutionEngine
```

## Action Execution Data Flow

```mermaid
sequenceDiagram
    participant AO as ActionsOrchestrator
    participant CE as Constraint Engine
    participant LM as Location Manager
    participant EP as Episode
    participant MTA as MTA Engine
    participant Log as Logger

    Note over AO: Action Available in Queue
    AO->>CE: Check Temporal Constraints
    CE->>CE: Evaluate after/before/concurrent/starts_with
    
    alt Constraints Satisfied
        CE->>AO: Constraints OK
        AO->>LM: Request Location Assignment
        
        LM->>LM: Evaluate Available Locations
        LM->>EP: Get Location Candidates
        EP->>LM: Return POI List
        
        LM->>LM: Apply Chain ID Filtering
        LM->>LM: Calculate Distances & Scores
        LM->>AO: Return Best Location
        
        AO->>MTA: Execute Action at Location
        MTA->>Log: Log Action Start
        
        Note over MTA: Action Executes in 3D World
        
        MTA->>AO: Action Completed
        AO->>Log: Log Action Complete
        AO->>CE: Update Constraint State
        
    else Constraints Not Satisfied
        CE->>AO: Constraints Failed
        AO->>Log: Log Constraint Wait
        Note over AO: Keep Action in Queue
    end
```

## Template Resolution Data Flow

```mermaid
flowchart LR
    subgraph "Template Input"
        SupertemplateFile[Supertemplate JSON]
        TemplateFiles[Template JSON Files]
        CoordinateRefs[Coordinate References]
    end
    
    subgraph "Resolution Process"
        STLoader[Supertemplate Loader]
        TLoader[Template Loader]
        RefResolver[Reference Resolver]
        CoordTransform[Coordinate Transformer]
        ObjInstantiator[Object Instantiator]
    end
    
    subgraph "Validation & Output"
        TemplateValidator[Template Validator]
        ConflictChecker[Conflict Checker]
        EpisodeIntegrator[Episode Integrator]
        FinalTemplate[Resolved Template]
    end
    
    SupertemplateFile --> STLoader
    TemplateFiles --> TLoader
    CoordinateRefs --> RefResolver
    
    STLoader --> RefResolver
    TLoader --> RefResolver
    RefResolver --> CoordTransform
    
    CoordTransform --> ObjInstantiator
    ObjInstantiator --> TemplateValidator
    
    TemplateValidator --> ConflictChecker
    ConflictChecker --> EpisodeIntegrator
    EpisodeIntegrator --> FinalTemplate
```

## Chain ID Management Data Flow

```mermaid
stateDiagram-v2
    [*] --> ChainRequest
    
    ChainRequest --> CheckExisting: Object needs Chain ID
    
    CheckExisting --> ExistingFound: Chain ID exists for object
    CheckExisting --> CreateNew: No existing Chain ID
    
    ExistingFound --> ValidateChain: Check chain availability
    CreateNew --> GenerateID: Create new Chain ID
    
    ValidateChain --> ChainAvailable: Chain not in use
    ValidateChain --> ChainConflict: Chain in use by another actor
    
    GenerateID --> RegisterChain: Register new Chain ID
    RegisterChain --> ChainAvailable
    
    ChainConflict --> QueueWait: Add to wait queue
    ChainConflict --> FindAlternative: Look for alternative object
    
    QueueWait --> ValidateChain: Retry when chain released
    FindAlternative --> CheckExisting: Try different object
    
    ChainAvailable --> AssignToActor: Assign Chain ID to actor
    AssignToActor --> [*]
```

## Multi-Episode State Synchronization

```mermaid
flowchart TD
    subgraph "Episode 1 State"
        E1Actors[Actor Positions]
        E1Objects[Object States]
        E1Chains[Chain IDs]
    end
    
    subgraph "Episode 2 State"
        E2Actors[Actor Positions]
        E2Objects[Object States]
        E2Chains[Chain IDs]
    end
    
    subgraph "MetaEpisode Coordinator"
        StateSync[State Synchronizer]
        ActorTracker[Actor Tracker]
        ChainManager[Chain Manager]
        MovementHandler[Movement Handler]
    end
    
    subgraph "Synchronization Operations"
        ActorMove[Actor Movement Between Episodes]
        StateTransfer[State Transfer]
        ChainUpdate[Chain ID Updates]
        ContextSwitch[Context Switching]
    end
    
    E1Actors --> StateSync
    E1Objects --> StateSync
    E1Chains --> StateSync
    
    E2Actors --> StateSync
    E2Objects --> StateSync
    E2Chains --> StateSync
    
    StateSync --> ActorTracker
    StateSync --> ChainManager
    StateSync --> MovementHandler
    
    ActorTracker --> ActorMove
    ChainManager --> ChainUpdate
    MovementHandler --> ContextSwitch
    
    ActorMove --> StateTransfer
    ChainUpdate --> StateTransfer
    ContextSwitch --> StateTransfer
    
    StateTransfer --> E1Actors
    StateTransfer --> E1Objects
    StateTransfer --> E1Chains
    
    StateTransfer --> E2Actors
    StateTransfer --> E2Objects
    StateTransfer --> E2Chains
```

## Debug Information Flow

```mermaid
flowchart LR
    subgraph "Debug Sources"
        GraphEngine[Graph Engine Debug]
        Orchestrator[Orchestrator Debug]
        Location[Location Debug]
        Template[Template Debug]
        Actions[Action Debug]
    end
    
    subgraph "Debug Processing"
        Logger[Debug Logger]
        Filter[Debug Filter]
        Formatter[Debug Formatter]
        Router[Debug Router]
    end
    
    subgraph "Debug Outputs"
        Console[Console Output]
        LogFiles[Log Files]
        Screenshots[Debug Screenshots]
        StateExports[State Export Files]
        Visualizer[3D Visualizer]
    end
    
    GraphEngine --> Logger
    Orchestrator --> Logger
    Location --> Logger
    Template --> Logger
    Actions --> Logger
    
    Logger --> Filter
    Filter --> Formatter
    Formatter --> Router
    
    Router --> Console
    Router --> LogFiles
    Router --> Screenshots
    Router --> StateExports
    Router --> Visualizer
```

## Video Generation Pipeline

```mermaid
flowchart TD
    subgraph "Story Execution"
        StoryStart[Story Begins]
        ActionExecution[Actions Execute]
        CameraControl[Camera Management]
        PedControl[Ped Management]
    end
    
    subgraph "Capture System"
        FrameCapture[Frame Capture]
        TimingControl[Frame Timing]
        QualityControl[Quality Control]
        MetadataCapture[Metadata Capture]
    end
    
    subgraph "Processing Pipeline"
        FrameBuffer[Frame Buffer]
        FrameProcessor[Frame Processor]
        Encoder[Video Encoder]
        MetadataSync[Metadata Sync]
    end
    
    subgraph "Output Generation"
        VideoFile[Video File]
        DebugFrames[Debug Frame Sequence]
        TimingLogs[Timing Logs]
        ActionLogs[Action Logs]
    end
    
    StoryStart --> ActionExecution
    ActionExecution --> CameraControl
    ActionExecution --> PedControl
    
    CameraControl --> FrameCapture
    PedControl --> FrameCapture
    FrameCapture --> TimingControl
    TimingControl --> QualityControl
    QualityControl --> MetadataCapture
    
    MetadataCapture --> FrameBuffer
    FrameBuffer --> FrameProcessor
    FrameProcessor --> Encoder
    FrameProcessor --> MetadataSync
    
    Encoder --> VideoFile
    MetadataSync --> DebugFrames
    MetadataSync --> TimingLogs
    MetadataSync --> ActionLogs
```

## Real-time Development Data Flow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant Client as MTA Client
    participant Commands as Command System
    participant Episode as Episode System
    participant Visual as 3D Visualizer
    participant Files as File System

    Dev->>Client: Connect to development server
    Client->>Commands: Execute development command
    
    alt Episode Editing Command
        Commands->>Episode: Modify episode structure
        Episode->>Visual: Update 3D visualization
        Visual->>Client: Render changes
        Client->>Dev: Show updated 3D world
        
        Dev->>Commands: Save changes
        Commands->>Files: Write updated JSON
        Files->>Commands: Confirm save
        
    else Template Editing Command
        Commands->>Episode: Load template system
        Episode->>Visual: Show template objects
        Visual->>Client: Render template visualization
        
        Dev->>Commands: Modify template
        Commands->>Visual: Update visualization
        Visual->>Client: Show changes
        
        Dev->>Commands: Save template
        Commands->>Files: Write template JSON
        
    else Path Editing Command
        Commands->>Episode: Load pathfinding data
        Episode->>Visual: Show path network
        Visual->>Client: Render path visualization
        
        Dev->>Commands: Add/modify paths
        Commands->>Visual: Update path display
        Visual->>Client: Show updated paths
        
        Dev->>Commands: Save paths
        Commands->>Files: Write path JSON
    end
    
    Commands->>Dev: Operation complete
```

## System Performance Metrics Flow

```mermaid
flowchart LR
    subgraph "Performance Sources"
        ActionTiming[Action Execution Timing]
        ConstraintTiming[Constraint Resolution Timing]
        LocationTiming[Location Assignment Timing]
        TemplateTiming[Template Resolution Timing]
    end
    
    subgraph "Metrics Collection"
        MetricsCollector[Metrics Collector]
        TimingAggregator[Timing Aggregator]
        PerformanceAnalyzer[Performance Analyzer]
        BottleneckDetector[Bottleneck Detector]
    end
    
    subgraph "Analysis & Output"
        PerformanceReports[Performance Reports]
        OptimizationSuggestions[Optimization Suggestions]
        RealTimeMetrics[Real-time Metrics]
        HistoricalData[Historical Performance Data]
    end
    
    ActionTiming --> MetricsCollector
    ConstraintTiming --> MetricsCollector
    LocationTiming --> MetricsCollector
    TemplateTiming --> MetricsCollector
    
    MetricsCollector --> TimingAggregator
    TimingAggregator --> PerformanceAnalyzer
    PerformanceAnalyzer --> BottleneckDetector
    
    BottleneckDetector --> PerformanceReports
    BottleneckDetector --> OptimizationSuggestions
    BottleneckDetector --> RealTimeMetrics
    BottleneckDetector --> HistoricalData
```