# EpisodeCommands.lua

## Purpose
This file provides comprehensive client-side commands for episode creation, editing, and testing. It implements an interactive episode development toolkit that allows developers to create complex 3D story environments with POIs, objects, regions, actions, and templates.

## Key Functions/Classes

### Core Command Handler: episode
Comprehensive episode management with sub-commands:

**Episode Lifecycle:**
- **`new [name]`** - Initialize new episode
- **`load episode_name`** - Load existing episode from JSON
- **`save episode_name [o]`** - Save episode to JSON with optional overwrite
- **`run`** - Execute current episode for testing

**Content Management:**
- **`add poi description`** - Add Point of Interest at current location
- **`add object modelid description`** - Add 3D object with interactive placement
- **`add action actionname params`** - Add action to current POI
- **`add region name`** - Start region definition with vertex recording
- **`add vertex`** - Add vertex to current region
- **`add camera`** - Add camera position for current region

**Content Modification:**
- **`modify object [idx]`** - Edit object position/rotation
- **`modify poi idx`** - Update POI coordinates
- **`modify vertex`** - Adjust region vertex positions
- **`delete object/poi/camera`** - Remove content elements

**World Model Management:**
- **`delete object modelid`** - Mark world objects for deletion
- **`restore object modelid`** - Restore deleted world objects

**Episode Linking:**
- **`linkepisode episode_name`** - Link current POI to another episode
- **`setgraph graph_name`** - Associate pathfinding graph

### Template System Commands

**template command:**
- **`new name`** - Initialize new template
- **`load supertemplate_name template_name`** - Load template from supertemplate
- **`save supertemplate_name [template_name] [o]`** - Save template to supertemplate
- **`add poi`** - Add current POI to template
- **`add object id`** - Add episode object to template
- **`insert [supertemplate template]`** - Instantiate template in episode

**supertemplate command:**
- **`new name`** - Initialize new supertemplate
- **`load name`** - Load existing supertemplate
- **`save [name] [o]`** - Save supertemplate to JSON
- **`add [current/template_name]`** - Add template to supertemplate
- **`insert [name]`** - Instantiate supertemplate with interactive positioning

### Interactive Editing System

**Key Binding System (`playerPressedKey`):**
- **Movement**: W/A/S/D/Z/X for translation
- **Rotation**: Q/E/F/G/H/J for rotation on different axes
- **Precision**: Alt (fine), Shift (coarse) modifiers
- **Size**: Mouse wheel for scaling
- **Completion**: Enter to finish, N to cancel

**Visual Feedback System (`text_render`):**
- Real-time 3D overlay rendering
- POI visualization with action chains
- Object instance visualization
- Region vertex and center display
- Camera position indicators
- Episode link visualization

## Dependencies
- **DynamicEpisode** - JSON-based episode loading
- **Location, Region, Object classes** - Core story components
- **Template, Supertemplate classes** - Template system
- **MTA client functions** - 3D world interaction
- **File I/O functions** - JSON serialization

## Data Flow

1. **Episode Creation** → Initialize episode structure
2. **Interactive Editing** → Place/modify 3D elements
3. **Serialization** → Convert to JSON with dependency tracking
4. **Template System** → Package reusable components
5. **Testing** → Runtime validation and debugging

## Architecture Notes

### Interactive 3D Editing
Sophisticated 3D manipulation system:
- Click-to-place object positioning
- Real-time keyboard-based fine adjustment
- Multi-axis rotation and scaling
- Visual feedback with markers and overlays
- Precision control with modifier keys

### Template System Architecture
Hierarchical content organization:
- **Templates**: Individual POI + dependencies
- **Supertemplates**: Collections of related templates
- **Relative Positioning**: All coordinates relative to template origin
- **Dependency Tracking**: Automatic object/location dependency resolution

### Region Definition System
Interactive region creation:
- Vertex-by-vertex polygon definition
- Real-time center calculation
- Visual feedback with markers
- Plane computation for collision detection
- Camera association for region-specific views

### Serialization Strategy
Complex dependency management:
- Relative coordinate conversion
- Cross-reference resolution (POI→Objects, Actions→Targets)
- Instance cleanup for JSON compatibility
- Dependency graph traversal
- Backup/restore for non-destructive serialization

### Visual Development Environment
Real-time development feedback:
- 3D text overlays for all interactive elements
- Color-coded visual indicators (POI=green, Objects=cyan, etc.)
- Action chain visualization
- Distance-based detail level
- Performance-optimized rendering

### Episode Linking System
Multi-episode story support:
- POI-based episode connections
- Move action auto-generation
- Episode transition validation
- Graph-based navigation support

### Object Management
Comprehensive 3D object handling:
- Interactive placement and adjustment
- World model deletion/restoration
- Attachment to character bones
- Scale and rotation support
- Collision state management

### Action System Integration
Story action development:
- Interactive action parameter input
- POI-action association
- Action chaining (NextAction, ClosingAction)
- Prerequisite system
- Testing and validation

### Error Handling and Validation
Robust development environment:
- File existence validation
- Parameter validation
- Overwrite protection
- Distance-based selection
- State consistency checking

### Development Workflow
Streamlined content creation:
1. **Episode Structure**: Create regions and POIs
2. **Object Placement**: Add and position 3D objects
3. **Action Definition**: Define available actions per POI
4. **Template Creation**: Package reusable components
5. **Testing**: Validate episode functionality
6. **Serialization**: Save for production use

This system provides a complete 3D story development environment within the game engine, enabling rapid prototyping and iteration of complex interactive narratives.