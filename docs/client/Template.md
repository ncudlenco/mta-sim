# Template.lua

## Purpose
This file implements the Template system, which packages reusable combinations of POIs, objects, and actions for efficient episode creation. Templates enable modular content creation and facilitate complex scene composition through relative positioning and dependency management.

## Key Functions/Classes

### Core Class: Template
Encapsulates a POI with its associated objects, actions, and dependent locations.

### Primary Methods

**Construction & Lifecycle:**
- **`init(params)`** - Initialize template with POI, objects, locations, and positioning
- **`Instantiate(interior, position)`** - Create visual markers and objects for editing
- **`Destroy()`** - Clean up all visual elements and markers

**Positioning & Transformation:**
- **`UpdatePosition(translation, rotation, relativePosition)`** - Apply transformations to all template elements
- **`Rebase(newRelativePosition, offsetVector)`** - Change reference coordinate system
- **`ComputeGlobalCentroid()`** - Calculate center point of all template elements

**Serialization & Loading:**
- **`Serialize(directory)`** - Save template to JSON with dependency tracking
- **`Load(supertemplate, name)`** - Static method to load template from file
- **`GetSerializedOffsets()`** - Extract positioning offsets for supertemplate storage

**Integration:**
- **`InsertInEpisode(episode, deserialize)`** - Add template contents to episode with ID remapping
- **`AddItems(mainPoi, objects, locations)`** - Add additional content to template

## Dependencies
- **Location class** - POI management
- **SampStoryObjectBase** - Object instances
- **Vector3** - 3D mathematics
- **MTA client functions** - File I/O, 3D objects, markers

## Data Flow

1. **Template Creation** → Capture POI, objects, and dependencies
2. **Relative Positioning** → Convert to relative coordinate system
3. **Interactive Editing** → Visual manipulation with real-time feedback
4. **Serialization** → Save with dependency relationships preserved
5. **Integration** → Insert into episodes with ID remapping

## Key Data Structures

### Template Structure
- **`poi`** - Main Point of Interest (can be empty placeholder)
- **`objects`** - Array of dependent objects with serialized data
- **`locations`** - Array of dependent POIs with actions
- **`position`** - Template reference point in world coordinates
- **`offset`** / **`rotationOffset`** - Transformation offsets for supertemplate positioning

### Serialization Format
```lua
{
    poi = serializedPOI,
    objects = {
        { id, dynamicString },
        ...
    },
    locations = {
        serializedPOI,
        ...
    },
    globalCentroid = {x, y, z},
    position = {x, y, z},
    name = "template_name"
}
```

## Architecture Notes

### Relative Coordinate System
All template elements use relative positioning:
- **Reference Point**: Template position serves as origin (0,0,0)
- **Object Positions**: Stored relative to template origin
- **POI Coordinates**: Adjusted relative to template position
- **Global Conversion**: Automatic coordinate transformation during instantiation

### Dependency Management System
Complex cross-reference handling:
- **Object Dependencies**: Actions reference specific objects
- **Location Dependencies**: Actions can target other POIs within template
- **ID Remapping**: Template IDs remapped to episode IDs during insertion
- **Circular Reference Prevention**: Careful ordering prevents reference loops

### Visual Editing Integration
Interactive manipulation system:
- **Marker System**: Color-coded markers for POI (magenta), objects, locations (cyan)
- **Real-time Updates**: All elements update during transformation
- **Offset Tracking**: Position changes tracked for supertemplate integration
- **Rotation Support**: Full 3D rotation around template origin

### Global Centroid Calculation
Mathematical center computation:
- Includes all POI positions and object positions
- Used for supertemplate alignment and positioning
- Enables intelligent template placement and orientation
- Facilitates template composition workflows

### Supertemplate Integration
Hierarchical template system:
- **Offset Storage**: Position and rotation offsets preserved
- **Skip Flags**: Templates can be marked for exclusion
- **Relative Positioning**: All coordinates maintained relative to supertemplate
- **Batch Processing**: Multiple templates positioned together

### ID Mapping System
Critical for episode integration:
- **Object Mapping**: Template object IDs → Episode object indices
- **POI Mapping**: Template location IDs → Episode POI indices
- **Action Remapping**: All action references updated to episode indices
- **Dependency Preservation**: Complex action chains maintained

### Transformation Mathematics
Sophisticated 3D transformations:
- **Translation**: Simple vector addition
- **Rotation**: Matrix rotation around template origin with offset handling
- **Coordinate Systems**: Seamless conversion between relative and global coordinates
- **Precision Handling**: Vector3 mathematics for accurate positioning

### Serialization Strategy
Non-destructive content preservation:
- **Instance Backup**: Visual elements backed up during save
- **Vector Unpacking**: Vector3 objects converted to serializable format  
- **Instance Restoration**: Visual elements restored after serialization
- **Reference Integrity**: All cross-references preserved during save/load

### Action Chain Processing
Complex action relationship handling:
- **NextAction Arrays**: Support for multiple possible next actions
- **Closing Actions**: Action pairs with opening/closing relationships
- **Target Remapping**: Action targets updated to episode references
- **Chain Validation**: Ensures action sequences remain valid

### Error Handling & Validation
Robust content management:
- **File Existence Checks**: Validation before load operations
- **Deserialization Validation**: Error handling for corrupt template data
- **Instance Management**: Safe cleanup of visual elements
- **Reference Validation**: Checks for valid object and POI references

This system enables sophisticated modular content creation, allowing developers to create complex interactive environments through composition of reusable, tested components while maintaining full dependency integrity.