--- Translation tables for semantic camera specifications to technical parameters
--- Converts filmmaker vocabulary to concrete camera settings (distance, FOV, offsets, behavior)
CameraParameters = {}

--- Shot framing definitions mapping semantic descriptions to technical camera parameters
--- Distance: how far camera is from subject
--- FOV: field of view in degrees (higher = wider angle)
--- Height: camera height offset from ground/subject
CameraParameters.SHOT_FRAMINGS = {
    ["extremewide"] = {
        distance = 20,
        fov = 90,
        height = 1.5,
        description = "Extreme wide - establishing shot"
    },
    ["wide"] = {
        distance = 10,
        fov = 80,
        height = 0.8,
        description = "Wide shot - full scene"
    },
    ["medium"] = {
        distance = 5,
        fov = 70,
        height = 0.8,
        description = "Medium shot - waist up (default)"
    },
    ["closeup"] = {
        distance = 1.5,
        fov = 50,
        height = 0.8,
        description = "Close up - face/object detail"
    },
    ["extremecloseup"] = {
        distance = 0.8,
        fov = 40,
        height = 0.8,
        description = "Extreme close up - eyes/small details"
    }
}

--- Shot type definitions mapping semantic shot types to camera behavior
--- Mode: "continuous" (tracks per frame) or "fixed" (one-time positioning)
--- Offset: {x, y, z} position offset from subject
--- Behavior: execution strategy for the camera handler
CameraParameters.SHOT_TYPES = {
    ["follow"] = {
        mode = "continuous",
        offset = {x = 0, y = -3, z = 0.8},
        behavior = "track_behind",
        description = "Track subject continuously from behind"
    },
    ["static"] = {
        mode = "fixed",
        offset = {x = 0, y = 0, z = 0},
        behavior = "use_region_camera",
        description = "Use region's predefined static camera"
    },
    ["free"] = {
        mode = "fixed",
        offset = {x = 0, y = 0, z = 0},
        behavior = "no_change",
        description = "Don't change camera position"
    },
    ["overshoulder"] = {
        mode = "fixed",
        offset = {x = -1, y = -2, z = 0.8},
        behavior = "look_at_target",
        description = "Over-shoulder view looking at target"
    },
    ["closeup"] = {
        mode = "fixed",
        offset = {x = 0, y = -1.5, z = 0},
        behavior = "focus_on_subject",
        framing = "closeup",
        description = "Close-up framing on subject"
    },
    ["show"] = {
        mode = "fixed",
        offset = {x = 0, y = -3, z = 0},
        behavior = "focus_on_subject",
        framing = "medium",
        description = "Medium shot showing subject"
    },
    ["wide"] = {
        mode = "fixed",
        offset = {x = 0, y = -10, z = 1.2},
        behavior = "focus_on_subject",
        framing = "wide",
        description = "Wide shot of subject/region"
    },
    ["medium"] = {
        mode = "fixed",
        offset = {x = 0, y = -5, z = 0},
        behavior = "focus_on_subject",
        framing = "medium",
        description = "Medium framing of subject"
    },
    ["extremewide"] = {
        mode = "fixed",
        offset = {x = 0, y = -20, z = 2},
        behavior = "focus_on_subject",
        framing = "extremewide",
        description = "Extreme wide establishing shot"
    },
    ["extremecloseup"] = {
        mode = "fixed",
        offset = {x = 0, y = -0.8, z = 0},
        behavior = "focus_on_subject",
        framing = "extremecloseup",
        description = "Extreme close-up detail shot"
    },
    ["twoshot"] = {
        mode = "fixed",
        offset = {x = 0, y = -4, z = 0.8},
        behavior = "frame_multiple",
        framing = "medium",
        description = "Frame two or more subjects"
    },
    -- Legacy support
    ["record"] = {
        mode = "fixed",
        offset = {x = 0, y = 0, z = 0},
        behavior = "record",
        description = "Start artifact collection"
    },
    ["stop"] = {
        mode = "fixed",
        offset = {x = 0, y = 0, z = 0},
        behavior = "stop",
        description = "Stop artifact collection"
    }
}

--- Translate semantic specification to technical parameters
--- Takes normalized semantic spec from CameraSpecParser and produces concrete camera parameters
--- @param semanticSpec table Normalized semantic specification {type, subject, target, framing, ...}
--- @return table Technical parameters {distance, fov, height, offset, mode, behavior, subject, target, subjects}
--- @usage local params = CameraParameters.Translate({type = "follow", subject = "actor0"})
function CameraParameters.Translate(semanticSpec)
    if not semanticSpec or not semanticSpec.type then
        if DEBUG then
            print("[CameraParameters] Invalid semantic spec - using medium shot default")
        end
        semanticSpec = {type = "medium"}
    end

    -- Get shot type definition (defaults to medium if unknown)
    local shotType = CameraParameters.SHOT_TYPES[semanticSpec.type]
    if not shotType then
        if DEBUG then
            print("[CameraParameters] Unknown shot type: "..semanticSpec.type.." - using medium default")
        end
        shotType = CameraParameters.SHOT_TYPES["medium"]
    end

    -- Determine framing (can be overridden by semantic spec)
    local framingKey = semanticSpec.framing or shotType.framing or "medium"
    local framing = CameraParameters.SHOT_FRAMINGS[framingKey]
    if not framing then
        if DEBUG then
            print("[CameraParameters] Unknown framing: "..framingKey.." - using medium default")
        end
        framing = CameraParameters.SHOT_FRAMINGS["medium"]
    end

    -- Build technical parameters
    local technicalParams = {
        -- From framing
        distance = framing.distance,
        fov = framing.fov,
        height = framing.height,

        -- From shot type
        offset = shotType.offset or {x = 0, y = 0, z = 0},
        mode = shotType.mode or "fixed",
        behavior = shotType.behavior or "no_change",

        -- From semantic spec (subjects/targets)
        subject = semanticSpec.subject,
        target = semanticSpec.target,
        subjects = semanticSpec.subjects,

        -- Metadata for debugging
        shotType = semanticSpec.type,
        framingType = framingKey
    }

    if DEBUG_CAMERA then
        print("[CameraParameters] Translated '"..semanticSpec.type.."' to:")
        print("  - Behavior: "..technicalParams.behavior)
        print("  - Mode: "..technicalParams.mode)
        print("  - Distance: "..technicalParams.distance)
        print("  - FOV: "..technicalParams.fov)
    end

    return technicalParams
end

--- Get default technical parameters for medium shot
--- Used as fallback when translation fails
--- @return table Default technical parameters
function CameraParameters.GetDefault()
    return CameraParameters.Translate({type = "medium"})
end
