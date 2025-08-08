# Supertemplate.lua

## Purpose
This file implements the Supertemplate system, which manages collections of related Templates as cohesive units. Supertemplates enable complex scene composition by coordinating multiple templates with precise relative positioning and transformation offsets.

## Key Functions/Classes

### Core Class: Supertemplate
Coordinates collections of templates with unified positioning and offset management.

### Primary Methods

**Construction & Lifecycle:**
- **`init(params)`** - Initialize supertemplate with name, position, templates array, and offsets
- **`Destroy()`** - Clean up instantiated template elements

**Serialization & Loading:**
- **`Serialize()`** - Convert supertemplate to JSON-serializable format
- **`Load(name)`** - Static method to load supertemplate from file system

## Dependencies
- **Template class** - Individual template management
- **Vector3** - 3D coordinate mathematics  
- **MTA file functions** - JSON serialization and file I/O

## Data Flow

1. **Supertemplate Creation** → Initialize with name and reference position
2. **Template Collection** → Gather related templates into unified collection
3. **Offset Calibration** → Interactive positioning determines template offsets
4. **Serialization** → Save coordinated template collection with offset data
5. **Episode Integration** → Deploy entire supertemplate with preserved relationships

## Key Data Structures

### Supertemplate Structure
- **`name`** - Unique identifier for the supertemplate
- **`position`** - Reference point for all contained templates (Vector3)
- **`templates`** - Array of template names included in supertemplate
- **`offsets`** - Array of positioning data corresponding to each template

### Offset Data Format
Each offset entry contains:
- **`skip`** - Boolean flag for template exclusion
- **`offset`** - Translation offset from supertemplate position
- **`rotationOffset`** - Rotation offset for template orientation

### Serialization Format
```lua
{
    name = "supertemplate_name",
    position = {x, y, z},
    templates = {
        "template1",
        "template2", 
        ...
    },
    offsets = {
        {skip = false, offset = {x, y, z}, rotationOffset = {x, y, z}},
        ...
    }
}
```

## Architecture Notes

### Hierarchical Template System
Multi-level content organization:
- **Templates**: Individual POI + objects + actions
- **Supertemplates**: Coordinated collections of templates
- **Episodes**: Runtime deployment of supertemplates
- **Meta-Episodes**: Multi-environment stories using supertemplates

### Reference Coordinate System
Unified positioning framework:
- **Supertemplate Position**: Master reference point for entire collection
- **Template Offsets**: Individual template positions relative to master reference
- **Rotation Offsets**: Individual template orientations relative to master
- **Skip Flags**: Optional template exclusion without breaking collection

### Interactive Calibration Workflow
User-driven positioning system:
1. **Sequential Presentation**: Templates presented one-by-one for positioning
2. **Interactive Manipulation**: Real-time 3D adjustment with visual feedback  
3. **Offset Capture**: Position and rotation deltas stored automatically
4. **Skip Option**: Templates can be marked for exclusion during calibration
5. **Batch Processing**: Multiple templates calibrated in single session

### File System Organization
Hierarchical directory structure:
```
files/supertemplates/
    supertemplate_name/
        supertemplate_name.json
        template1.json
        template2.json
        ...
```

### Template Coordination
Sophisticated relationship management:
- **Dependency Preservation**: Cross-template references maintained
- **ID Namespace**: Template IDs coordinated to prevent conflicts
- **Action Chains**: Actions can reference objects across templates
- **Spatial Relationships**: Templates positioned with awareness of others

### Runtime Instantiation
Efficient deployment system:
- **Batch Loading**: All templates loaded simultaneously
- **Offset Application**: Stored offsets applied automatically
- **Skip Processing**: Excluded templates omitted without errors
- **Episode Integration**: Coordinated insertion into episode structure

### Development Workflow Integration
Seamless content creation pipeline:
1. **Template Development**: Create individual templates with full functionality
2. **Supertemplate Assembly**: Collect related templates into coherent units
3. **Offset Calibration**: Interactive positioning determines spatial relationships
4. **Testing & Validation**: Verify supertemplate functionality in test episodes
5. **Production Deployment**: Automated supertemplate instantiation in stories

### Error Handling & Validation
Robust content management:
- **File Existence Validation**: Checks for required template files
- **Deserialization Safety**: Graceful handling of corrupted data
- **Template Validation**: Ensures all referenced templates exist
- **Offset Consistency**: Validates offset array length matches template count

### Future Extensibility
System designed for enhancement:
- **Property-Based Selection**: Templates can be chosen by properties
- **Random Selection**: Support for probabilistic template inclusion
- **Conditional Logic**: Template inclusion based on story context
- **Inventory Integration**: Template selection based on actor inventory

### Integration Points
Connection to broader system:
- **Episode Commands**: Direct integration with episode creation workflow
- **Template System**: Built on foundation of individual templates
- **Story Engine**: Deployed automatically during story execution
- **Content Pipeline**: Part of comprehensive content creation toolchain

This system enables sophisticated scene composition by coordinating multiple templates into cohesive, reusable units that maintain complex spatial and functional relationships while providing flexible deployment options.