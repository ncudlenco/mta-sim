# MappingCommands.lua

## Purpose
This file provides client-side commands for creating and editing pathfinding graphs used by the story system. It enables developers to create navigation networks by placing nodes and connecting them with weighted edges for AI pathfinding.

## Key Functions/Classes

### Core Command Handler: graph
Pathfinding graph management:

**Graph Lifecycle:**
- **`new`** - Initialize new empty graph
- **`load graph_name`** - Load existing graph from JSON file
- **`save graph_name`** - Save current graph to JSON file

### Node and Edge Management Commands

**add command:**
- **`add node`** - Add pathfinding node at current player position
- **`add edge id1 id2`** - Connect two nodes with weighted edge

**modify command:**
- **`modify node id`** - Update node position to current player location

### Visual Rendering System

**Real-time Graph Visualization (`text_render`):**
- 3D overlay rendering of all graph nodes
- Distance-based visibility culling (10 unit radius)
- Node ID and edge information display
- Color-coded markers (red=no edges, green=has edges)
- Performance optimization (max 100 nodes displayed)

## Dependencies
- **MTA client functions** - File I/O, 3D positioning, rendering
- **Vector3** - 3D mathematics for edge calculations
- **JSON functions** - Graph serialization/deserialization

## Data Flow

1. **Graph Creation** → Initialize empty node collection
2. **Node Placement** → Add nodes at player positions with ground snapping
3. **Edge Creation** → Connect nodes with distance-weighted edges
4. **Visualization** → Real-time 3D feedback with markers and text
5. **Serialization** → Save graph to JSON for pathfinding system

## Key Data Structures

### Graph Format (JSON)
```lua
[
    {
        id = nodeId,
        x = worldX,
        y = worldY, 
        z = groundZ,
        edges = {
            {targetNodeId, edgeWeight},
            ...
        }
    },
    ...
]
```

### Visual Elements
- **`json`** - Array of graph nodes with positions and connections
- **`markers`** - Visual 3D markers for each node
- Color coding: Red (isolated), Green (connected)

## Architecture Notes

### Ground Snapping System
Automatic terrain alignment:
- Uses `getGroundPosition()` to find terrain height
- Fallbacks to player Z-1 if ground detection fails
- Ensures pathfinding nodes align with walkable surfaces

### Edge Weight Calculation
Distance-based edge weighting:
- Calculates 3D Euclidean distance between connected nodes
- Converts to integer for pathfinding efficiency
- Bidirectional edge creation for undirected graph

### Visual Feedback System
Real-time development environment:
- 3D text overlays showing node IDs and edge lists
- Distance-based culling for performance
- Color-coded markers indicating connectivity status
- Interactive marker updates when edges are added

### JSON Processing
Special JSON handling:
- String manipulation for MTA JSON compatibility
- Handles nested array structures properly
- Preserves graph topology during save/load cycles

### Performance Optimization
- Limits displayed nodes to 100 for performance
- Distance-based rendering culling
- Efficient marker reuse system
- Lazy rendering updates

### Development Workflow
1. **Initialize Graph**: Create new graph or load existing
2. **Place Nodes**: Walk through environment adding navigation points
3. **Connect Nodes**: Create edges between logically connected locations
4. **Visual Validation**: Use real-time rendering to verify graph structure
5. **Save Graph**: Export for use by pathfinding system

### Integration with Story System
The generated graphs are used by:
- **ServerCommands.lua** pathfinding system
- **Location.lua** movement validation
- AI navigation for story actors
- Episode transition planning

### Error Handling
- File existence validation for load operations
- Parameter validation for node/edge operations
- Safe fallbacks for ground position detection
- Robust marker management

This system provides essential infrastructure for AI navigation in the story simulation, enabling actors to move realistically through complex 3D environments while following story requirements.