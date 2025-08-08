# System Architecture Overview

This document provides comprehensive architectural diagrams for the MTA San Andreas Story Simulation System using Mermaid diagrams.

## High-Level System Architecture

```mermaid
graph TD
    subgraph "Input Layer"
        JSON[Story Graph JSON]
        Episodes[Episode Definitions]
        Templates[Template Library]
    end
    
    subgraph "Core Processing Engine"
        GS[GraphStory Engine]
        AO[ActionsOrchestrator]
        ME[MetaEpisode Manager]
    end
    
    subgraph "3D World Interface"
        PH[PedHandler]
        CH[CameraHandler]
        EL[Episode Loader]
        Loc[Location Manager]
    end
    
    subgraph "Content Systems"
        TS[Template System]
        ST[Supertemplate System]
        OM[Object Mapping]
    end
    
    subgraph "Output Layer"
        MTA[MTA Game Engine]
        Video[Video Output]
        Logs[Debug Logs]
    end
    
    JSON --> GS
    Episodes --> ME
    Templates --> TS
    
    GS --> AO
    GS --> ME
    ME --> Loc
    
    AO --> PH
    AO --> CH
    Loc --> EL
    
    TS --> ST
    ST --> OM
    OM --> Loc
    
    PH --> MTA
    CH --> MTA
    EL --> MTA
    MTA --> Video
    
    GS --> Logs
    AO --> Logs
    Loc --> Logs
```

## Story Processing Flow

```mermaid
sequenceDiagram
    participant Client as Client
    participant GS as GraphStory
    participant ME as MetaEpisode
    participant AO as ActionsOrchestrator
    participant Loc as Location
    participant MTA as MTA Engine

    Client->>GS: Load Graph JSON
    GS->>GS: Parse Events & Actors
    GS->>ME: Create MetaEpisode
    ME->>ME: Load Component Episodes
    GS->>GS: Map Objects & Actions
    
    loop For Each Event in Graph
        GS->>AO: Enqueue Action with Constraints
        AO->>AO: Check Temporal Constraints
        
        alt Constraints Satisfied
            AO->>Loc: Request Location Assignment
            Loc->>Loc: Evaluate Candidates
            Loc->>AO: Return Selected Location
            AO->>MTA: Execute Action
        else Constraints Not Met
            AO->>AO: Keep in Queue
        end
    end
    
    AO->>Client: Story Complete
```

## Temporal Constraint System

```mermaid
graph TD
    subgraph "Constraint Types"
        After[After Constraint]
        Before[Before Constraint]
        StartsWith[StartsWith Constraint]
        Concurrent[Concurrent Constraint]
    end
    
    subgraph "ActionsOrchestrator Core"
        Queue[Action Queue]
        Validator[Constraint Validator]
        Executor[Action Executor]
    end
    
    subgraph "Constraint Processing"
        AfterCheck{After Event<br/>Completed?}
        BeforeCheck{Before Event<br/>Not Started?}
        StartCheck{Start Event<br/>Beginning?}
        ConcurCheck{Concurrent<br/>Window Open?}
    end
    
    After --> AfterCheck
    Before --> BeforeCheck
    StartsWith --> StartCheck
    Concurrent --> ConcurCheck
    
    Queue --> Validator
    AfterCheck --> Validator
    BeforeCheck --> Validator
    StartCheck --> Validator
    ConcurCheck --> Validator
    
    Validator --> Executor
    Executor --> Queue
```

## Location Management Architecture

```mermaid
graph TD
    subgraph "Location Selection Process"
        Loc[Location Manager]
        Candidates[Candidate Evaluation]
        Constraints[Constraint Checking]
        Selection[Final Selection]
    end
    
    subgraph "Constraint Types"
        ActorCons[Actor Constraints]
        ObjectCons[Object Constraints]
        ChainCons[Chain ID Constraints]
        ProximityCons[Proximity Constraints]
        OccupancyCons[Occupancy Constraints]
    end
    
    subgraph "Selection Criteria"
        Distance[Distance Scoring]
        Availability[Availability Check]
        Compatibility[Action Compatibility]
        ChainID[Chain ID Matching]
    end
    
    Loc --> Candidates
    Candidates --> ActorCons
    Candidates --> ObjectCons
    Candidates --> ChainCons
    Candidates --> ProximityCons
    Candidates --> OccupancyCons
    
    ActorCons --> Constraints
    ObjectCons --> Constraints
    ChainCons --> Constraints
    ProximityCons --> Constraints
    OccupancyCons --> Constraints
    
    Constraints --> Distance
    Constraints --> Availability
    Constraints --> Compatibility
    Constraints --> ChainID
    
    Distance --> Selection
    Availability --> Selection
    Compatibility --> Selection
    ChainID --> Selection
```

## Template System Architecture

```mermaid
graph TD
    subgraph "Template Hierarchy"
        ST[Supertemplate]
        T1[Template 1]
        T2[Template 2]
        T3[Template N]
    end
    
    subgraph "Template Components"
        Objects[Template Objects]
        Actions[Template Actions]
        POIs[Points of Interest]
        Coords[Coordinate System]
    end
    
    subgraph "Resolution Process"
        Resolver[Template Resolver]
        Coordinator[Coordinate Transformer]
        Validator[Template Validator]
        Instantiator[Object Instantiator]
    end
    
    ST --> T1
    ST --> T2
    ST --> T3
    
    T1 --> Objects
    T1 --> Actions
    T1 --> POIs
    T1 --> Coords
    
    T2 --> Objects
    T2 --> Actions
    T2 --> POIs
    T2 --> Coords
    
    Objects --> Resolver
    Actions --> Resolver
    POIs --> Resolver
    Coords --> Coordinator
    
    Resolver --> Validator
    Coordinator --> Validator
    Validator --> Instantiator
    Instantiator --> ST
```

## Multi-Episode System

```mermaid
graph TD
    subgraph "MetaEpisode Structure"
        ME[MetaEpisode Manager]
        E1[Episode 1]
        E2[Episode 2]
        E3[Episode N]
    end
    
    subgraph "Episode Components"
        Objects1[Objects & POIs]
        Paths1[Navigation Paths]
        Actions1[Available Actions]
        
        Objects2[Objects & POIs]
        Paths2[Navigation Paths]
        Actions2[Available Actions]
        
        Objects3[Objects & POIs]
        Paths3[Navigation Paths]
        Actions3[Available Actions]
    end
    
    subgraph "Cross-Episode Operations"
        Movement[Inter-Episode Movement]
        Context[Context Switching]
        ActorDist[Actor Distribution]
        StateSync[State Synchronization]
    end
    
    ME --> E1
    ME --> E2
    ME --> E3
    
    E1 --> Objects1
    E1 --> Paths1
    E1 --> Actions1
    
    E2 --> Objects2
    E2 --> Paths2
    E2 --> Actions2
    
    E3 --> Objects3
    E3 --> Paths3
    E3 --> Actions3
    
    E1 -.-> Movement
    E2 -.-> Movement
    E3 -.-> Movement
    
    Movement --> Context
    Context --> ActorDist
    ActorDist --> StateSync
    StateSync --> ME
```

## Data Flow Architecture

```mermaid
flowchart LR
    subgraph "Input Sources"
        GraphJSON[Story Graph JSON]
        EpisodeJSON[Episode JSON Files]
        TemplateJSON[Template JSON Files]
    end
    
    subgraph "Processing Pipeline"
        Parser[Graph Parser]
        Validator[Episode Validator]
        Mapper[Object Mapper]
        Orchestrator[Actions Orchestrator]
        LocationMgr[Location Manager]
        TemplateEngine[Template Engine]
    end
    
    subgraph "Execution Layer"
        PedControl[Ped Controller]
        CameraControl[Camera Controller]
        ObjectSpawner[Object Spawner]
        PathFinder[Path Finder]
    end
    
    subgraph "Output Generation"
        VideoCapture[Video Capture]
        LogOutput[Debug Logs]
        StateOutput[State Tracking]
    end
    
    GraphJSON --> Parser
    EpisodeJSON --> Validator
    TemplateJSON --> TemplateEngine
    
    Parser --> Mapper
    Validator --> Mapper
    TemplateEngine --> Mapper
    
    Mapper --> Orchestrator
    Orchestrator --> LocationMgr
    LocationMgr --> PedControl
    LocationMgr --> CameraControl
    LocationMgr --> ObjectSpawner
    LocationMgr --> PathFinder
    
    PedControl --> VideoCapture
    CameraControl --> VideoCapture
    ObjectSpawner --> StateOutput
    PathFinder --> LogOutput
    
    VideoCapture --> LogOutput
    StateOutput --> LogOutput
```

## Advanced Camera Synchronization System

```mermaid
flowchart TD
    subgraph "Focus Request System"
        ActionTrigger[Action Begins]
        FocusRequest[Request Focus]
        FocusQueue[Focus Queue]
        AutoFocus[Auto Focus Assignment]
    end
    
    subgraph "Context Detection"
        RegionCheck[Check Actor Region]
        EpisodeCheck[Check Episode Context]
        ContextChange{Context Changed?}
        ContextSwitch[Context Switch Process]
    end
    
    subgraph "Episode Coordination"
        PauseOldEpisode[Pause Old Episode]
        WaitForPause[Wait for Actions to Pause]
        FadeOut[Fade Out Spectators]
        SwitchContext[Switch to New Episode]
        ResumeNewEpisode[Resume New Episode]
        FadeIn[Fade In Spectators]
    end
    
    subgraph "Spectator Management"
        SpectatorCameras[Spectator Cameras]
        FadeControl[Fade Control]
        TimingControl[Focus Timing Control]
        VideoCapture[Video Capture]
    end
    
    ActionTrigger --> FocusRequest
    FocusRequest --> FocusQueue
    FocusQueue --> AutoFocus
    
    AutoFocus --> RegionCheck
    RegionCheck --> EpisodeCheck
    EpisodeCheck --> ContextChange
    
    ContextChange -->|Yes| ContextSwitch
    ContextChange -->|No| SpectatorCameras
    
    ContextSwitch --> PauseOldEpisode
    PauseOldEpisode --> WaitForPause
    WaitForPause --> FadeOut
    FadeOut --> SwitchContext
    SwitchContext --> ResumeNewEpisode
    ResumeNewEpisode --> FadeIn
    FadeIn --> SpectatorCameras
    
    SpectatorCameras --> FadeControl
    FadeControl --> TimingControl
    TimingControl --> VideoCapture
    VideoCapture --> ActionTrigger
```

## Debug and Development Architecture

```mermaid
graph TD
    subgraph "Development Tools"
        EC[Episode Commands]
        MC[Mapping Commands]
        SC[Server Commands]
    end
    
    subgraph "Interactive Systems"
        3DEdit[3D Episode Editor]
        PathEdit[Path Editor]
        TemplateEdit[Template Editor]
        ObjectEdit[Object Placer]
    end
    
    subgraph "Debug Systems"
        Logger[Debug Logger]
        Visualizer[3D Visualizer]
        StateInspector[State Inspector]
        ConstraintMonitor[Constraint Monitor]
    end
    
    subgraph "Output Systems"
        DebugLogs[Debug Log Files]
        Screenshots[Debug Screenshots]
        StateFiles[State Export Files]
        VideoFiles[Debug Videos]
    end
    
    EC --> 3DEdit
    MC --> PathEdit
    SC --> TemplateEdit
    
    3DEdit --> ObjectEdit
    PathEdit --> ObjectEdit
    TemplateEdit --> ObjectEdit
    
    ObjectEdit --> Logger
    Logger --> Visualizer
    Visualizer --> StateInspector
    StateInspector --> ConstraintMonitor
    
    Logger --> DebugLogs
    Visualizer --> Screenshots
    StateInspector --> StateFiles
    ConstraintMonitor --> VideoFiles
```