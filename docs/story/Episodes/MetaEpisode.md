# MetaEpisode.lua

## Purpose
MetaEpisode is a wrapper that combines multiple individual episodes into a single unified episode for complex multi-location stories. It enables seamless transitions between different 3D environments while maintaining object and actor consistency across locations.

## Key Functions/Classes

### Core Class: MetaEpisode
Inherits from `StoryEpisodeBase` and acts as a facade over multiple individual episodes.

### Primary Methods

**Construction & Setup:**
- **`init(episodes)`** - Combines multiple episodes into unified collections
- **`Initialize(actor, isTemporaryInitialize, actors, graphOfEvents)`** - Initializes all component episodes and creates cross-episode movement actions
- **`Destroy()`** - Cleanup all component episodes
- **`Play(...)`** - Delegates to base class play functionality

**Episode Linking:**
- Automatically creates `Move` actions between all POIs across different episodes
- Processes explicit episode links defined in POI configurations
- Maintains episode context for each POI

## Dependencies
- **StoryEpisodeBase** - Base episode functionality
- **Move action** - For cross-episode transitions
- Individual episode classes (DynamicEpisode, House1, etc.)

## Data Flow

1. **Episode Aggregation** → Combine POIs, Objects, Regions from all episodes
2. **Actor Distribution** → Propagate actors to all component episodes  
3. **Link Creation** → Generate Move actions between episodes
4. **Unified Interface** → Present as single episode to story system

## Key Data Structures

### Aggregated Collections
- **`POI`** - Combined points of interest from all episodes
- **`Objects`** - Merged object collections with episode context
- **`Regions`** - Unified region definitions
- **`peds`** - Shared actor collection across episodes

### Episode Management
- **`Episodes`** - Array of component episodes
- **`episodeLinks`** - Explicit cross-episode connections

## Architecture Notes

### Multi-Episode Composition Pattern
MetaEpisode implements the Composite pattern:
- Provides unified interface over multiple episodes
- Aggregates collections from component episodes
- Delegates operations to individual episodes
- Maintains episode context for each POI

### Cross-Episode Movement System
Automatically generates comprehensive movement network:
- Creates Move actions between every POI pair across episodes
- Links prerequisites from existing actions
- Maintains proper action chaining
- Enables arbitrary cross-episode navigation

### Actor Propagation Strategy
Ensures all actors available in all episodes:
- Deduplicates actors during initialization
- Propagates unified actor list to all component episodes
- Prevents actor duplication across episodes
- Maintains consistent actor state

### Episode Context Tracking
Each POI maintains reference to its source episode:
- `poi.Episode` links POI back to originating episode
- Enables context-aware operations
- Supports episode-specific behavior
- Facilitates debugging and validation

### Initialization Sequence
1. **Initialize Primary Episode**: First episode gets full actor set
2. **Initialize Secondary Episodes**: Remaining episodes get empty actor set initially
3. **Actor Distribution**: All episodes receive unified actor collection
4. **Link Generation**: Create cross-episode movement actions
5. **Context Assignment**: Assign episode context to all POIs

### Episode Linking Mechanisms
Two types of cross-episode connections:

**Explicit Links:**
- Defined in POI `episodeLinks` property
- Represent logical story connections
- Processed during initialization
- Create specific source→target relationships

**Universal Links:**
- Automatically generated between all POI pairs
- Enable complete navigation freedom
- Support dynamic story requirements
- Provide fallback movement options

### Memory and Resource Management
- Aggregates references rather than copying data
- Delegates destruction to component episodes
- Maintains minimal additional overhead
- Supports garbage collection of unused episodes

### Debug Integration
- `DEBUG_METAEPISODE` flag for initialization logging
- `DEBUG_CHAIN_LINKED_ACTIONS` for movement action creation
- Detailed POI episode assignment logging
- Cross-episode link creation tracking

### Story System Integration
Seamless integration with story execution:
- Presents as single episode to GraphStory
- Maintains compatibility with existing action system
- Supports temporal constraint processing
- Enables complex multi-location narratives

This architecture enables sophisticated stories that span multiple 3D environments while maintaining the simplicity of single-episode story processing from the perspective of the story execution engine.