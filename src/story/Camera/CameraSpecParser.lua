--- Parser for semantic camera commands from GEST
--- Converts structured camera specifications to normalized format
--- Only supports structured object format (no string parsing)
CameraSpecParser = {}

--- Parse semantic camera command from GEST
--- @param spec table Camera command from graph (must be structured object)
--- @return table Normalized semantic specification
--- @usage local normalized = CameraSpecParser.Parse({shot = {type = "follow", subject = "actor0"}})
--- @usage local normalized = CameraSpecParser.Parse({recording = "start", shot = {type = "static"}})
function CameraSpecParser.Parse(spec)
    if type(spec) ~= "table" then
        error("[CameraSpecParser] Camera commands must be structured objects, not "..type(spec)..". Use format: {shot = {type = '...', ...}}")
    end

    return CameraSpecParser.ParseTable(spec)
end


--- Parse structured objects into normalized semantic specification
--- Supports both legacy format ({action = "record"}) and new shot format ({shot = "follow", subject = "actor0"})
--- @param tbl table Semantic object command
--- @return table Normalized specification
function CameraSpecParser.ParseTable(tbl)
    -- Legacy format: {action = "record"} or {action = "stop"}
    if tbl.action then
        if tbl.action == "record" then
            return {type = "record"}
        elseif tbl.action == "stop" then
            return {type = "stop"}
        else
            if DEBUG then
                print("[CameraSpecParser] Unknown legacy action: "..tbl.action)
            end
            return {type = "unknown", original = tbl}
        end
    end

    -- New shot format: supports both string and nested table
    -- String format: {shot = "follow", subject = "actor0"}
    -- Nested table format: {shot = {type = "follow", subject = "actor0"}}
    if tbl.shot then
        local shotType
        local shotSubject
        local shotTarget
        local shotSubjects
        local shotFraming

        -- Check if shot is string or table
        if type(tbl.shot) == "string" then
            -- String format: {shot = "follow", subject = "actor0", ...}
            shotType = tbl.shot:lower():gsub("%s+", "") -- Remove spaces: "close up on" → "closeupon"
            shotSubject = tbl.subject
            shotTarget = tbl.looking_at or tbl.target
            shotSubjects = tbl.subjects
            shotFraming = tbl.framing
        elseif type(tbl.shot) == "table" then
            -- Nested table format: {shot = {type = "follow", subject = "actor0"}}
            shotType = tbl.shot.type and tbl.shot.type:lower():gsub("%s+", "") or "unknown"
            shotSubject = tbl.shot.subject
            shotTarget = tbl.shot.looking_at or tbl.shot.target
            shotSubjects = tbl.shot.subjects
            shotFraming = tbl.shot.framing
        else
            if DEBUG then
                print("[CameraSpecParser] Invalid shot format: "..type(tbl.shot))
            end
            return {type = "unknown", original = tbl}
        end

        -- Normalize shot types
        local typeMapping = {
            ["follow"] = "follow",
            ["static"] = "static",
            ["free"] = "free",
            ["closeupon"] = "closeup",
            ["closeup"] = "closeup",
            ["close_up"] = "closeup",
            ["show"] = "show",
            ["twoshot"] = "twoshot",
            ["overshoulder"] = "overshoulder",
            ["wide"] = "wide",
            ["medium"] = "medium",
            ["extremewide"] = "extremewide",
            ["extremecloseup"] = "extremecloseup"
        }

        local normalizedType = typeMapping[shotType] or shotType

        -- Build normalized spec
        local normalized = {
            type = normalizedType,
            subject = shotSubject,
            target = shotTarget,
            subjects = shotSubjects,
            framing = shotFraming
        }

        return normalized
    end

    -- Unknown table format
    if DEBUG then
        print("[CameraSpecParser] Unknown table command format")
    end
    return {type = "unknown", original = tbl}
end
