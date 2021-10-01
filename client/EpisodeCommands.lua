addEvent ( "onElementDoneEditing", true )
addEvent ( "onActionRetrieved", true )

DEFINING_EPISODES = false
if DEFINING_EPISODES then
    addEventHandler ( "onClientPlayerSpawn", getLocalPlayer(), function()
        print('onClientPlayerSpawn')

        local g = Guid()
        localPlayer:setData("id", g.Id)
        localPlayer:setData("isPed", false)
    
        print('Player '..g.Id)
        CLIENT_STORY = Story(localPlayer, 10000, true)
        CURRENT_STORY = CLIENT_STORY
    end)
    function GetStory(player)
        print('GetStory called from client')
        if not CLIENT_STORY.History then
            CLIENT_STORY.History = {}
        end
        if not CLIENT_STORY.History[localPlayer:getData("id")] then
            CLIENT_STORY.History[localPlayer:getData("id")] = {}
        end
        return CLIENT_STORY
    end
end

local episode = DynamicEpisode()
local markers = {}
local currentRegion = nil
local function text_render ( )
    local closestRegion = nil
    if currentRegion then
        closestRegion = currentRegion 
    elseif episode.Regions then
        local regionsInRange = Region.FilterWithinRange(localPlayer.position, episode.Regions, 1.5)
        closestRegion = Region.GetClosest(localPlayer, regionsInRange, false)
    end
    if closestRegion then
        if closestRegion.cameras then
            for i,c in ipairs(closestRegion.cameras) do
                local sx, sy, _ = getScreenFromWorldPosition(c.x, c.y, c.z)
                if sx then 
                    local sw, sh = guiGetScreenSize ( )
                    dxDrawText ("cam"..i, sx, sy, sw, sh, tocolor ( 255, 255, 0, 255 ), 2.0, "default-bold" ) 
                end
            end
        end
        for i,v in ipairs(closestRegion.vertexes) do
            local sx, sy, _ = getScreenFromWorldPosition(v.x, v.y, v.z)
            if sx then 
                local sw, sh = guiGetScreenSize ( )
                dxDrawText ('v'..i..': '..closestRegion.name, sx, sy, sw, sh, tocolor ( 0, 0, 0, 255 ), 2.0, "default-bold" ) 
            end
        end
        if not currentRegion then
            local centerText = closestRegion.name
            if closestRegion.Objects and #closestRegion.Objects > 0 then
                centerText = centerText..': '..table.concat( closestRegion.Objects, ", ")
            end
            local sx, sy, _ = getScreenFromWorldPosition(closestRegion.center.x, closestRegion.center.y, closestRegion.center.z)
            if sx then 
                local sw, sh = guiGetScreenSize ( )
                dxDrawText (centerText, sx, sy, sw, sh, tocolor ( 0, 0, 0, 255 ), 2.0, "default-bold" ) 
            end
        end
    end
    for i, obj in ipairs(episode.ObjectsToDelete) do
        local sx, sy, _ = getScreenFromWorldPosition(obj.position.x, obj.position.y, obj.position.z)
        if sx then 
            local sw, sh = guiGetScreenSize ( )
            dxDrawText ("deleted", sx, sy, sw, sh, tocolor ( 255, 0, 0, 255 ), 2.0, "default-bold" ) 
        end 
    end
    for i, obj in ipairs(episode.Objects) do
        local sx, sy, _ = getScreenFromWorldPosition(obj.position.x, obj.position.y, obj.position.z)
        if sx then 
            local sw, sh = guiGetScreenSize ( )
            dxDrawText (i..': '..(obj.Description or '')..' '..(obj.modelid or 'random eModel'), sx, sy, sw, sh, tocolor ( 0, 255, 0, 255 ), 1.0, "default-bold" ) 
        end 
    end
    for i, poi in ipairs ( episode.POI ) do
        if #markers == #(episode.POI) and i > 100 then
            break
        end
        local x = poi.X
        local y = poi.Y
        local z = poi.Z
        local sx, sy, _ = getScreenFromWorldPosition ( x, y, z ) 
        
        local playerZ = localPlayer.position.z
        if (localPlayer.position - Vector3(x,y,z)).length < 10 then
            if sx then 
                local sw, sh = guiGetScreenSize ( )
                local actionsText = ""
                if #poi.PossibleActions > 0 then
                    local a = poi.PossibleActions[1]
                    actionsText = a.id..": "..a.Description
                    while (a) do
                        if a.NextAction and #a.NextAction > 0 then
                            a = a.NextAction[1]
                        else
                            a = a.NextAction
                        end
                        if not a then
                            break
                        end
                        if isArray(a) then
                            actionsText = actionsText.." -random- ["
                            for k, ra in ipairs(a) do
                                actionsText = actionsText..ra.id..": "..ra.Description
                            end
                            actionsText = actionsText..']'
                        else
                            actionsText = actionsText.." -mandatory- "..a.id..": "..a.Description
                        end
                    end
                end
                local allActionsText = ""
                for k, a in ipairs(poi.allActions) do
                    local closingActionText = ""
                    if a.ClosingAction then
                        closingActionText = "-closed by- "..a.ClosingAction.id..": "..a.ClosingAction.Description
                    end
                    allActionsText = allActionsText.."\n["..a.id..": "..a.Description..closingActionText.."]"
                end
                dxDrawText ( i..":"..poi.Description.."\n"..actionsText..allActionsText, sx, sy, sw, sh, tocolor ( 255, 200, 0, 255 ), 1.0, "default-bold" ) 
            end 
        end

        if #markers < #(episode.POI) then
            -- outputChatBox(#markers..' vs '..#(episode.POI))
            local r = 255
            local g = 0
            if #poi.PossibleActions > 0 then
                r = 0
                g = 255
            end
            local groundZ = getGroundPosition (x, y, z)
            if not groundZ or groundZ == 0 then
                groundZ = z - 1
            end

            local marker = Marker(x, y, groundZ, "cylinder", 1, r, g, 0, 128)
            marker.interior = poi.Interior
            table.insert(markers, marker)
        end
    end
    if episode.supertemplates then
        for _,s in ipairs(episode.supertemplates) do
            if s.position then
                local sx, sy, _ = getScreenFromWorldPosition ( s.position.x, s.position.y, s.position.z ) 
                if sx then
                    local sw, sh = guiGetScreenSize ( )
                    dxDrawText ( 'supertemplate '..s.name.."\n", sx, sy, sw, sh, tocolor ( 183, 44, 174, 255 ), 1.0, "default-bold" ) 
                end
            end
        end
    end
end 

local function unloadEpisode(episode)
    if not episode then
        return false
    end
    removeEventHandler("onClientRender", getRootElement(), text_render)
    for _,obj in ipairs(episode.ObjectsToDelete) do
        restoreWorldModel(obj.modelid, obj.size, obj.position.x, obj.position.y, obj.position.z)
    end
    for _, marker in pairs ( markers ) do 
        marker:destroy()
    end
    if currentRegion and currentRegion.markers then
        for _, m in pairs(currentRegion.markers) do
            m:destroy()
        end
        currentRegion = nil
    end
    if episode.supertemplates then
        for _,st in ipairs(episode.supertemplates) do
            if st.instantiatedTemplate then
                st.instantiatedTemplate:Destroy()
            end
        end
    end 
    markers = {}
    episode:Destroy()
    return true
end

local editedObject = nil
local relativePosition = nil
local nextEditSameThing = false
local cameraTargetObject = nil
local isEditedObjectAttached = false
local altPressed = false
local shiftPressed = false
local setCamera = false
local moveTarget = false
local isTemplate = false
local function playerPressedKey(button, press)
    if (press) then
        local translationIncrement = 0.1
        local rotationIncrement = 5
        local sizeIncrement = 0.5
        if altPressed then
            translationIncrement = 0.01
            rotationIncrement = 1
            sizeIncrement = 0.1
        end
        if shiftPressed then
            translationIncrement = 0.5
            rotationIncrement = 90
            sizeIncrement = 1
        end
        local offset = Vector3(0,0,0)
        local translate = false
        local rotate = false
        local changeSize = false
        local skip = false
        local function done()
            showCursor(false)
            removeEventHandler("onClientKey", root, playerPressedKey)
            triggerEvent ( "onElementDoneEditing", getRootElement(), editedObject )
            if not nextEditSameThing then
                editedObject = nil
                setCamera = false
                isTemplate = false
                isEditedObjectAttached = false
                if cameraTargetObject then
                    cameraTargetObject:destroy()
                    cameraTargetObject = nil
                end
            end
        end
        if button == "w" then
            translate = true
            offset = Vector3(translationIncrement,0,0)
        elseif button == "s" then
            translate = true
            offset =  Vector3(-1*translationIncrement,0,0)
        elseif button == "a" then
            translate = true
            offset =  Vector3(0,-1*translationIncrement,0)
        elseif button == "d" then
            translate = true
            offset =  Vector3(0,translationIncrement,0)
        elseif button == "z" then 
            translate = true
            offset =  Vector3(0,0,translationIncrement)
        elseif button == "x" then
            translate = true
            offset =  Vector3(0,0,-1 *translationIncrement)
        elseif button == "q" then
            rotate = true
            offset =  Vector3(0,0,rotationIncrement)
        elseif button == "e" then
            rotate = true
            offset =  Vector3(0,0,-1 * rotationIncrement)
        elseif button == "h" then
            rotate = true
            offset =  Vector3(0,rotationIncrement,0)
        elseif button == "j" then
            rotate = true
            offset =  Vector3(0,-1 * rotationIncrement,0)
        elseif button == "f" then
            rotate = true
            offset =  Vector3(rotationIncrement,0,0)
        elseif button == "g" then
            rotate = true
            offset =  Vector3(-1 * rotationIncrement,0,0)
        elseif button == "mouse_wheel_up" then
            changeSize = true
        elseif button == "mouse_wheel_down" then
            changeSize = true
            sizeIncrement = -1 * sizeIncrement
        elseif button == "n" then
            if editedObject:getData('isTemporary') and editedObject.destroy then
                editedObject:destroy()
            end
            editedObject = nil
            done()
            return
        elseif button == "enter" then
            done()
            return
        elseif button == "lalt" or button == "ralt" then
            altPressed = true
        elseif button == "lshift" or button == "rshift" then
            shiftPressed = true
        elseif setCamera and button == "u" then
            if moveTarget then
                moveTarget = false
                outputChatBox("Use w/a/s/d/z/x/q/e to place and roll the camera, use scroll up/down to change the field of view", 255, 0, 0, false)
                outputChatBox("Press u to modify the coordinates of the camera target", 255, 0, 0, false)
                outputChatBox("Press enter to save the current camera and target setting", 255, 0, 0, false)

            else
                outputChatBox("Use w/a/s/d to set the coordinates of the camera target. Press u again to return to modifying the camera position", 255, 0, 0, false)
                outputChatBox("Press enter to save the current camera and target setting", 255, 0, 0, false)
                moveTarget = true
            end
        elseif isTemplate and button == "backspace" then
            skip = true
        end

        if setCamera then
            if moveTarget then
                cameraTargetObject.position = cameraTargetObject.position + offset
                editedObject.lx = cameraTargetObject.position.x
                editedObject.ly = cameraTargetObject.position.y
                editedObject.lz = cameraTargetObject.position.z
            else
                if translate then
                    editedObject.x = editedObject.x + offset.x
                    editedObject.y = editedObject.y + offset.y
                    editedObject.z = editedObject.z + offset.z
                elseif rotate then
                    editedObject.roll = editedObject.roll + offset.z
                elseif changeSize then
                    editedObject.fov = editedObject.fov + sizeIncrement
                end    
            end

            Camera.setMatrix(
                editedObject.x,
                editedObject.y,
                editedObject.z,
                editedObject.lx,
                editedObject.ly,
                editedObject.lz,
                editedObject.roll,
                editedObject.fov
            )
            localPlayer.cameraInterior = localPlayer.interior
        elseif isEditedObjectAttached then
            if translate then
                editedObject.PosOffset = Vector3(editedObject.PosOffset.x, editedObject.PosOffset.y, editedObject.PosOffset.z) + offset
            elseif rotate then
                editedObject.RotOffset = Vector3(editedObject.RotOffset.x, editedObject.RotOffset.y, editedObject.RotOffset.z) + offset
            elseif changeSize then
                editedObject.scale = editedObject.scale + sizeIncrement
            end
            setElementBonePositionOffset(editedObject.instance, editedObject.PosOffset.x, editedObject.PosOffset.y, editedObject.PosOffset.z)
            setElementBoneRotationOffset(editedObject.instance, editedObject.RotOffset.x, editedObject.RotOffset.y, editedObject.RotOffset.z)
            setObjectScale(editedObject.instance, editedObject.scale)
        elseif isTemplate then
            if skip then
                editedObject.skip = true
                done()
                return
            end
            if translate then
                editedObject:UpdatePosition(offset)
            elseif rotate then
                editedObject:UpdatePosition(nil, offset, relativePosition)
            end
        else
            if translate then
                editedObject.position = Vector3(editedObject.position.x, editedObject.position.y, editedObject.position.z) + offset
            elseif rotate then
                editedObject.rotation = Vector3(editedObject.rotation.x, editedObject.rotation.y, editedObject.rotation.z) + offset
            elseif changeSize then
                if editedObject.size then
                    editedObject.size = editedObject.size + sizeIncrement
                end
            end
        end
    else
        if button == "lalt" or button == "ralt" then
            altPressed = false
        elseif button == "lshift" or button == "rshift" then
            shiftPressed = false
        end
    end
end

local lastAction = nil
local function getAction(actionName, params)
    params.performer = localPlayer
    local action = loadstring("return function(params) return "..actionName.."(params) end")()(params)
    --here I have an action either defined or DynamicAction, with description, block, anim and (optional) time (which can be random)
    --I will ask for further ids: nextLocation id, targetItem type (object or location) and it's id
    --actions can be chained, ex: a1 -mandatory- a2 -random- [a3, a4, a5] -mandatory- --a6 with the link actions command
    local poi = nil
    local minDist = 1000
    for i,v in ipairs (episode.POI) do
        local dist = math.abs((localPlayer.position - Vector3(v.X, v.Y, v.Z)).length)
        if dist < minDist then
            minDist = dist
            poi = v
        end
    end

    local function getTargetItem()
        outputChatBox("Enter the target item type (object, location or none):",255,255,0)
        function consoleCheck2(text2)
            if starts_with(text2, "episode ") then
                return
            end
            removeEventHandler("onClientConsole",getLocalPlayer(),consoleCheck2)
            local targetItemType = text2
            if targetItemType ~= "object" and targetItemType ~= "location" and targetItemType ~= "none" then
                outputChatBox("Expected object, location or none but got "..text2,255,255,0)
                return
            end
            if targetItemType == "none" then
                lastAction = action
                triggerEvent ( "onActionRetrieved", getRootElement(), action )
                return
            end
            outputChatBox("Enter the target item id:",255,255,0)
            function consoleCheck3(text3)
                if starts_with(text3, "episode ") then
                    return
                end
                removeEventHandler("onClientConsole",getLocalPlayer(),consoleCheck3)
                local targetItemId = tonumber(text3)
                if not targetItemId then
                    outputChatBox("Could not parse the numeric value "..text3,255,255,0)
                    return
                end
                --do work here to identify that
                local targetItem = nil
                if targetItemType == "object" then
                    if targetItemId > #episode.Objects then
                        outputChatBox("Target item id is greater than the number of objects: "..targetItemId..' > '..#episode.Objects,255,255,0)
                        return
                    end
                    targetItem = episode.Objects[targetItemId]
                else
                    if locationId > #episode.POI then
                        outputChatBox("Target item id is greater than the number of POI: "..locationId..' > '..#episode.POI,255,255,0)
                        return
                    end
                    targetItem = episode.POI[locationId]
                end
                if targetItem then
                    outputChatBox("target item identified")
                    action.TargetItem = targetItem
                    lastAction = action
                    triggerEvent ( "onActionRetrieved", getRootElement(), action )
                end
            end
            addEventHandler("onClientConsole",getLocalPlayer(),consoleCheck3)
        end
        addEventHandler("onClientConsole",getLocalPlayer(),consoleCheck2)
    end

    if poi == nil then
        outputChatBox("Enter the nextLocation id and press enter :",255,255,0)
        function consoleCheck(text)
            if starts_with(text, "episode ") then
                return
            end
            removeEventHandler("onClientConsole",getLocalPlayer(),consoleCheck)
            local locationId = tonumber(text)
            if not locationId then
                outputChatBox("Could not parse the numeric value "..text,255,255,0)
                return
            end
            if locationId > #episode.POI then
                outputChatBox("Location id is greater than the number of POI: "..locationId..' > '..#episode.POI,255,255,0)
                return
            end
            poi = episode.POI[locationId]
            action.NextLocation = poi
            getTargetItem()
        end
        addEventHandler("onClientConsole",getLocalPlayer(),consoleCheck)
    else
        action.NextLocation = poi
        getTargetItem()
    end
end
local supertemplate = Supertemplate{}
local template = Template{}

addCommandHandler("episode",
    function (commandName, command, param1, param2, ...)
        if command == "new" then
            DEFINING_EPISODES = true
            unloadEpisode(episode)
            episode = DynamicEpisode()
            episode.InteriorId = localPlayer.interior
            if param1 then
                episode.name = param1
            end
            
            outputChatBox("New episode initialized", 255, 0, 0, false)
            addEventHandler("onClientRender", getRootElement(), text_render)
        elseif command == "run" then
            episode:Destroy()
            episode:Initialize(localPlayer)
            episode:Play(localPlayer)
        elseif command == "load" then
            DEFINING_EPISODES = true
            unloadEpisode(episode)
            if param1 then
                episode = DynamicEpisode(param1)
                if episode:LoadFromFile() then
                    episode:Initialize(localPlayer) --should not create the supertemplate contents
                    outputChatBox("Loaded files/episodes/"..episode.name..".json", 255, 0, 0, false)
                else
                    outputChatBox("File not found files/episodes/"..episode.name..".json", 255, 0, 0, false)
                end
            else
                outputChatBox("Parameter episode_name not provided. Ex: episode load episode_name", 255, 0, 0, false)
            end
		    addEventHandler("onClientRender", getRootElement(), text_render)
            CLIENT_STORY.CurrentEpisode = episode
        elseif command == "save" then
            DEFINING_EPISODES = true
            if param1 then
                episode.name = param1
                --check if all the required parameters are given
                if not episode.graphPath then
                    outputChatBox("Warning: the graph_path is not set. Run episode setgraph graph_name to set it.", 255, 0, 0, false)
                end
                if #episode.POI == 0 then
                    outputChatBox("Warning: no POI set. Run episode add poi to add some, at least one is necessary.", 255, 0, 0, false)
                end
                if param2 ~= "o" and fileExists("files/episodes/"..param1..".json") then
                    outputChatBox("files/episodes/"..param1..".json already exists. To overwrite it type episode save episode_name o", 255, 0, 0, false)
                    return
                end
                local instances = {}
                for _,obj in ipairs(episode.Objects) do
                    table.insert(instances, obj.instance)
                    if obj.position and obj.position.unpack then
                        obj.position = obj.position:unpack()
                    end
                    if obj.rotation and obj.rotation.unpack then
                        obj.rotation = obj.rotation:unpack()
                    end
                    if obj.PosOffset and obj.PosOffset.unpack then
                        obj.PosOffset = obj.PosOffset:unpack()
                    end
                    if obj.RotOffset and obj.RotOffset.unpack then
                        obj.RotOffset = obj.RotOffset:unpack()
                    end
                    obj.instance = nil
                    
                    -- outputChatBox(tostring(obj["removeZOffset"] ~= nil))

                    if obj["removeZOffset"] ~= nil then
                        obj:removeZOffset()
                    end
                end
                for _,obj in ipairs(episode.ObjectsToDelete) do
                    if obj.position and obj.position.unpack then
                        obj.position = obj.position:unpack()
                    end
                    if obj.rotation and obj.rotation.unpack then
                        obj.rotation = obj.rotation:unpack()
                    end
                    if obj.PosOffset and obj.PosOffset.unpack then
                        obj.PosOffset = obj.PosOffset:unpack()
                    end
                    if obj.RotOffset and obj.RotOffset.unpack then
                        obj.RotOffset = obj.RotOffset:unpack()
                    end
                    obj.instance = nil
                end
                local backupPOI = {}
                local serializedPOI = {}
                for _,poi in ipairs(episode.POI) do
                    table.insert(backupPOI, poi)
                    --serialize all actions in this poi
                    local spoi = poi:Serialize(episode)
                    table.insert(serializedPOI, spoi)
                end
                episode.POI = serializedPOI
                for _,r in ipairs(episode.Regions) do
                    r.Episode = nil
                    r.instance = nil
                    r.Id = nil
                    r.POI = nil
                    r.isExplored = nil
                end
                if episode.supertemplates then
                    local supertemplateInstances = {}
                    for _,st in ipairs(episode.supertemplates) do
                        table.insert(supertemplateInstances, st.instantiatedTemplate)
                        st.instantiatedTemplate = nil
                    end
                end
                local fileHandle = fileCreate("files/episodes/"..param1..".json")
                if fileHandle then
                    local jsonStr = toJSON(episode)
                    fileWrite(fileHandle, jsonStr)
                    fileClose(fileHandle)
                    outputChatBox("Saved files/episodes/"..param1..".json", 255, 0, 0, false)
                end
                for i,obj in ipairs(episode.Objects) do
                    obj.instance = instances[i]
                end
                if episode.supertemplates then
                    for i,st in ipairs(episode.supertemplates) do
                        st.instantiatedTemplate = supertemplateInstances[i]
                    end
                end
                episode.POI = backupPOI
            else
                outputChatBox("Parameter episode_name not provided. Ex: episode save episode_name", 255, 0, 0, false)
            end
        elseif command == "setgraph" then
            if param1 then
                episode.graphPath = "files/paths/"..param1..".json"
                if not fileExists(episode.graphPath) then
                    outputChatBox("Graph path set to "..episode.graphPath.." but this file could not be found in the current client folder.", 255, 0, 0, false)
                    outputChatBox("Run graph new to generate a graph for this episode", 255, 0, 0, false)
                else
                    outputChatBox("Graph path set to "..episode.graphPath, 255, 0, 0, false)
                end
            else
                outputChatBox("Parameter graph_name not provided. Ex: episode setgraph house3", 255, 0, 0, false)
            end
        elseif command == "cancel" then
            removeEventHandler("onClientKey", root, playerPressedKey)
            showCursor(false)
            if currentRegion and currentRegion.markers then
                for _,v in currentRegion.markers do
                    v:destroy()
                end
                currentRegion = nil
            end
            if editedObject and editedObject:getData('isTemporary') then
                editedObject:destroy()
            end
        elseif command == "delete" then
            if param1 == "object" then
                if not param2 then
                    outputChatBox("[info] Write the modelId for the world object to be deleted: Ex: episode delete object 2255", 255, 0, 0, false)
                    outputChatBox("[info] or the idx of the object to remove. Ex: episode delete object idx 5", 255, 0, 0, false)
                end
                if param2 == 'idx' then
                    local objIdx = tonumber(arg[1])
                    if not objIdx or #episode.Objects < objIdx then
                        outputChatBox("Invalid object idx", 255, 0, 0, false)
                        return
                    end
                    local v = episode.Objects[objIdx]
                    v:Destroy()
                    table.remove(episode.Objects, objIdx)
                    outputChatBox("Object found in current episode and deleted", 255, 0, 0, false)
                    return
                end
                outputChatBox("Click on the (position of the) object to be deleted.", 255, 0, 0, false)
                showCursor(true, true)
                function onClick(button, state, absoluteX, absoluteY, worldX, worldY, worldZ, element)
                    if state ~= "up" then
                        return
                    end 
                    outputChatBox("Clicked at "..worldX..", "..worldY..", "..worldZ, 255, 0, 0, false)
                    removeEventHandler("onClientClick", getRootElement(), onClick)
                    if not param2 then
                        for i,v in ipairs (episode.Objects) do
                            if
                                v.interior == localPlayer.interior
                                and math.abs((Vector3(v.position.x, v.position.y, v.position.z) - Vector3(worldX, worldY, worldZ)).length) < 0.1
                            then
                                v:Destroy()
                                table.remove(episode.Objects, i)
                                outputChatBox("Object found in current episode and deleted", 255, 0, 0, false)
                                removeEventHandler("onClientClick", getRootElement(), onClick)
                                return
                            end
                        end
                        outputChatBox("Object not found in current episode or try again with a worldmodelid if you intend to delete a world model", 255, 0, 0, false)
                        removeEventHandler("onClientClick", getRootElement(), onClick)
                        showCursor(false)
                        return
                    end

                    local modelId = tonumber(param2)

                    local function addObjectToDelete(obj)
                        local modelid = obj.modelid
                        if  obj.getData and obj:getData("modelId") then
                            modelid = obj:getData("modelId")
                        end
                        showCursor(false)
                        outputChatBox("Trying to delete world model "..modelid.." in interior"..obj.interior.." from position "..obj.position.x.." "..obj.position.y.." "..obj.position.z, 255, 0, 0, false)
                        removeEventHandler("onElementDoneEditing", getRootElement(), addObjectToDelete)
                        if removeWorldModel (modelid, obj.size, obj.position.x, obj.position.y, obj.position.z, obj.interior) then
                            outputChatBox("Done. Marked to be deleted.", 255, 0, 0, false)
                            table.insert(
                                episode.ObjectsToDelete,
                                SampStoryObjectBase {
                                    description = "",
                                    modelid = modelid,
                                    position = obj.position:unpack(),
                                    rotation = obj.rotation:unpack(),
                                    interior = obj.interior,
                                    size = obj.size or 2.5
                                })
                            if obj.destroy then
                                obj:destroy()
                            end
                            return true
                        end
                        return false
                    end
                    showCursor(true,true)
                    outputChatBox("Place the world object to be deleted inside this marker and press enter", 255, 0, 0, false)
                    outputChatBox("Use w/a/s/d/z/x/q/e/f/g/h/j to place and rotate the marker", 255, 0, 0, false)
                    outputChatBox("Press enter to finish", 255, 0, 0, false)
                    editedObject = Marker(worldX, worldY, worldZ, "cylinder", 2.5, 0, 0, 255, 128)
                    editedObject.interior = localPlayer.interior
                    element = editedObject
                    element:setData('deleteMarker', true)
                    element:setData('modelId', modelId)
                    
                    addEventHandler("onClientKey", root, playerPressedKey)
                    addEventHandler ( "onElementDoneEditing", getRootElement(), addObjectToDelete)
                    removeEventHandler("onClientClick", getRootElement(), onClick)
                end
                addEventHandler ( "onClientClick", getRootElement(), onClick)
            elseif param1 == "poi" then
                local poi = nil
                local minDist = 1000
                local id = -1
                for i,v in ipairs (episode.POI) do
                    local dist = math.abs((localPlayer.position - Vector3(v.X, v.Y, v.Z)).length)
                    if dist < minDist then
                        minDist = dist
                        poi = v
                        id = i
                    end
                end
                if poi == nil then
                    outputChatBox('Could not find any POI nearby. Place the player in the desired POI')
                   return 
                end

                table.remove(episode.POI, id)
            end
        elseif command == "restore" then
            if param1 == "object" then
                if not param2 then
                    outputChatBox("Write the modelId for the world object to be restored: Ex: episode restore object 2255", 255, 0, 0, false)
                    return
                end
                outputChatBox("Select the position of the object to be restored.", 255, 0, 0, false)
                showCursor(true, true)
                function onClick(button, state, absoluteX, absoluteY, worldX, worldY, worldZ, element)
                    outputChatBox("Clicked at "..worldX..", "..worldY..", "..worldZ, 255, 0, 0, false)
                    local modelId = tonumber(param2)

                    local function addObjectToRestore(obj)
                        local modelid = obj.modelid
                        if  obj.getData and obj:getData("modelId") then
                            modelid = obj:getData("modelId")
                        end
                        showCursor(false)
                        outputChatBox("Trying to restore world model "..modelid.." in interior"..obj.interior.." from position "..obj.position.x.." "..obj.position.y.." "..obj.position.z, 255, 0, 0, false)
                        removeEventHandler("onElementDoneEditing", getRootElement(), addObjectToRestore)
                        if restoreWorldModel (modelid, obj.size, obj.position.x, obj.position.y, obj.position.z) then
                            for i,v in ipairs(episode.ObjectsToDelete) do
                                if 
                                    v.modelid == modelid
                                    and math.abs(v.position.y - obj.position.y) < obj.size 
                                    and math.abs(v.position.z - obj.position.z) < obj.size 
                                    and math.abs(v.position.x - obj.position.x) < obj.size 
                                    and v.interior == obj.interior 
                                then
                                    table.remove(episode.ObjectsToDelete, i)
                                    outputChatBox("Done. Restored.", 255, 0, 0, false)
                                    break
                                end
                            end
                            if obj.destroy then
                                obj:destroy()
                            end
                            return true
                        end
                        return false
                    end
                    outputChatBox("Place the world object to be restored inside this marker and press enter", 255, 0, 0, false)
                    outputChatBox("Use w/a/s/d/z/x/q/e/f/g/h/j to place and rotate the marker", 255, 0, 0, false)
                    outputChatBox("Press enter to finish", 255, 0, 0, false)
                    editedObject = Marker(worldX, worldY, worldZ, "cylinder", 2.5, 255, 0, 0, 128)
                    editedObject.interior = localPlayer.interior
                    element = editedObject
                    element:setData('restoreMarker', true)
                    element:setData('modelId', modelId)
                    
                    addEventHandler("onClientKey", root, playerPressedKey)
                    addEventHandler ( "onElementDoneEditing", getRootElement(), addObjectToRestore)
                    removeEventHandler("onClientClick", getRootElement(), onClick)
                end
                addEventHandler ( "onClientClick", getRootElement(), onClick)
            end
        elseif command == "modify" then
            if param1 == "object" then
                outputChatBox("episode modify object [idx] [idx_value].", 255, 0, 0, false)
                local idx = tonumber(arg[1])
                if param2 == 'idx' and idx and idx <= #episode.Objects then
                    editedObject = episode.Objects[idx].instance
                    outputChatBox("Object found in current episode. Modify it and press enter.", 255, 0, 0, false)
                    outputChatBox("Use w/a/s/d/z/x/q/e/f/g/h/j to place and rotate the object", 255, 0, 0, false)
                    outputChatBox("Press enter to finish", 255, 0, 0, false)
                    local function updateObjectData(obj)
                        showCursor(false)
                        removeEventHandler("onElementDoneEditing", getRootElement(), addObjectToCreate)
                        episode.Objects[idx]:UpdateData(true)
                        outputChatBox("Done. Object modified.", 255, 0, 0, false)
                        return true
                    end
                    addEventHandler("onClientKey", root, playerPressedKey)
                    addEventHandler ( "onElementDoneEditing", getRootElement(), updateObjectData)
                    return
                end
                outputChatBox("Click on the object to be modified.", 255, 0, 0, false)
                showCursor(true, true)
                function onClick(button, state, absoluteX, absoluteY, worldX, worldY, worldZ, element)
                    if state ~= "up" then
                        return
                    end 
                    outputChatBox("Clicked at "..worldX..", "..worldY..", "..worldZ, 255, 0, 0, false)
                    for i,v in ipairs (episode.Objects) do
                        if
                            v.interior == localPlayer.interior
                            and math.abs((Vector3(v.position.x, v.position.y, v.position.z) - Vector3(worldX, worldY, worldZ)).length) < 0.1
                        then
                            editedObject = v.instance
                            outputChatBox("Object found in current episode. Modify it and press enter.", 255, 0, 0, false)
                            outputChatBox("Use w/a/s/d/z/x/q/e/f/g/h/j to place and rotate the object", 255, 0, 0, false)
                            outputChatBox("Press enter to finish", 255, 0, 0, false)
                            local function updateObjectData(obj)
                                showCursor(false)
                                removeEventHandler("onElementDoneEditing", getRootElement(), addObjectToCreate)
                                v:UpdateData(true)
                                outputChatBox("Done. Object modified.", 255, 0, 0, false)
                                return true
                            end
                            addEventHandler("onClientKey", root, playerPressedKey)
                            addEventHandler ( "onElementDoneEditing", getRootElement(), updateObjectData)
                            removeEventHandler("onClientClick", getRootElement(), onClick)
                            return
                        end
                    end
                    outputChatBox("Object not found in current episode", 255, 0, 0, false)
                    removeEventHandler("onClientClick", getRootElement(), onClick)
                end
                addEventHandler ( "onClientClick", getRootElement(), onClick)
            
            elseif param1 == "vertex" then
                if episode.Regions then
                    local regionsInRange = Region.FilterWithinRange(localPlayer.position, episode.Regions, 1.5)
                    local closestRegion = Region.GetClosest(localPlayer, regionsInRange, true)
                    if closestRegion then
                        local closestVertex = nil
                        local minDist = 1000
                        local closestIdx = -1
                        for i,v in ipairs (closestRegion.vertexes) do
                            local dist = math.abs((localPlayer.position - Vector3(v.x, v.y, v.z)).length)
                            if dist < minDist then
                                minDist = dist
                                closestVertex = v
                                closestIdx = i
                            end
                        end
                        if closestVertex then
                            showCursor(true, true)
                            outputChatBox("Place the vertex marker as desired and press enter", 255, 0, 0, false)
                            outputChatBox("Use w/a/s/d/z/x/q/e/f/g/h/j to place and rotate the marker", 255, 0, 0, false)
                            outputChatBox("Press enter to finish", 255, 0, 0, false)
                            editedObject = Marker(closestVertex.x, closestVertex.y, closestVertex.z, "cylinder", 0.5, 255, 0, 0, 128)
                            editedObject.interior = localPlayer.interior
                            editedObject:setData('isTemporary', true)

                            local function vertexMarkerSet(vertexMarker)
                                removeEventHandler("onElementDoneEditing", getRootElement(), vertexMarkerSet)
                                showCursor(false)
                                local vertex = vertexMarker.position
                                closestRegion.center = (((Vector3(closestRegion.center.x, closestRegion.center.y, closestRegion.center.z) * #closestRegion.vertexes) - Vector3(closestVertex.x, closestVertex.y, closestVertex.z) + vertex) / #closestRegion.vertexes):unpack()
                                closestRegion.vertexes[closestIdx] = vertex:unpack()
                                vertexMarker:destroy()
                            end

                            addEventHandler("onClientKey", root, playerPressedKey)
                            addEventHandler ( "onElementDoneEditing", getRootElement(), vertexMarkerSet)
                        else
                            outputChatBox("Could not find the closest vertex in this region")
                        end
                    else
                        outputChatBox("Could not find a region for this location")
                    end
                else
                    outputChatBox("No region defined yet")
                end            
            end
        elseif command == "reset" then
            if param1 == "camera" then
                setCameraTarget(localPlayer)
            end
        elseif command == "add" then
            if param1 == "poi" or param1 == "POI" then
                if not param2 then
                    outputChatBox("POI description expected: Ex: episode add poi house entrance", 255, 0, 0, false)
                    return
                end
                local description = param2
                local stringWithAllParameters = table.concat( arg, " " )
                if stringWithAllParameters then
                    description = description .. " " .. stringWithAllParameters
                end

                table.insert(
                    episode.POI, 
                    Location(
                        localPlayer.position.x,
                        localPlayer.position.y,
                        localPlayer.position.z,
                        localPlayer.rotation.z,
                        localPlayer.interior,
                        description,
                        true
                    )
                )
            elseif param1 == "object" then
                if not param2 then
                    outputChatBox("Object modelid or object class expected: Ex: episode add object 2281 painting or episode add Laptop [optional modelId; if no modelId is given then it will be randomly chosen from eModel]", 255, 0, 0, false)
                    return
                end
                local description = table.concat( arg, " " )
                if (not description or description == "") and tonumber(param2) ~= nil then
                    outputChatBox("Object description expected: Ex: episode add object 2281 painting", 255, 0, 0, false)
                    return
                end

                outputChatBox("Select the position of the object to be created.", 255, 0, 0, false)
                showCursor(true, true)
                function onClick(button, state, absoluteX, absoluteY, worldX, worldY, worldZ, element)
                    outputChatBox("Clicked at "..worldX..", "..worldY..", "..worldZ, 255, 0, 0, false)
                    local type = nil
                    local randomModelid = true
                    local modelId = nil

                    if description == "" then
                        randomModelid = true
                        type = param2
                        modelId = loadstring('return '..type..'.eModel[PickRandom('..type..'.eModel)]')()
                        outputChatBox('Will choose a random modelid. For now it is : ...'..modelId..'...')
                    else
                        if tonumber(param2) ~= nil then
                            modelId = tonumber(param2)
                            outputChatBox('modelid: ...'..modelId..'...')
                            outputChatBox('description: ...'..description..'...')
                        else
                            type = param2
                            modelId = tonumber(description)
                            outputChatBox('type: ...'..type..'...')
                            outputChatBox('modelId: ...'..modelId..'...')
                        end
                    end

                    local function addObjectToCreate(obj)
                        showCursor(false)
                        removeEventHandler("onElementDoneEditing", getRootElement(), addObjectToCreate)
                        local objModelId = modelId
                        if randomModelid then
                            objModelId = nil
                        end
                        local object = SampStoryObjectBase {
                            description = description,
                            modelid = objModelId,
                            position = obj.position:unpack(),
                            rotation = obj.rotation:unpack(),
                            interior = obj.interior,
                            type = type,
                            noCollisions = obj.noCollisions
                        }
                        object = loadstring(object.dynamicString)()
                        object.ObjectId = #episode.Objects..''

                        table.insert(
                            episode.Objects,
                            object
                        )
                        object.instance = obj
                        outputChatBox("Done. Object added.", 255, 0, 0, false)
                        return true
                    end
                    outputChatBox("Use w/a/s/d/z/x/q/e/f/g/h/j to place and rotate the object", 255, 0, 0, false)
                    outputChatBox("Press enter to finish", 255, 0, 0, false)
                    editedObject = Object(modelId, Vector3(worldX, worldY, worldZ), Vector3(0,0,0), true)
                    editedObject.interior = localPlayer.interior
                    
                    addEventHandler("onClientKey", root, playerPressedKey)
                    addEventHandler ( "onElementDoneEditing", getRootElement(), addObjectToCreate)
                    removeEventHandler("onClientClick", getRootElement(), onClick)
                end
                addEventHandler ( "onClientClick", getRootElement(), onClick)
            elseif param1 == "action" then
                local function addAction(action)
                    action = lastAction
                    action.id = #action.NextLocation.allActions + 1
                    table.insert(action.NextLocation.allActions, action)
                    removeEventHandler ( "onActionRetrieved", getRootElement(), addAction)
                    outputChatBox('action '..action.id..' added')
                end
                if param2 == "last" then
                    if lastAction == nil then
                        outputChatBox('last action is not defined yet')
                        return
                    end
                    addAction(lastAction)
                else
                    local actionName = param2
                    local params = {}
                    local paramName = nil
                    for i,v in ipairs(arg) do
                        if i % 2 == 0 then
                            params[paramName] = loadstring('return '..v)()
                            print(params[paramName])
                            print(paramName)
                        else
                            paramName = v
                        end
                    end
                    addEventHandler ( "onActionRetrieved", getRootElement(), addAction)
                    getAction(actionName, params)
                end
            elseif param1 == "camera" then
                local regionsInRange = Region.FilterWithinRange(localPlayer.position, episode.Regions, 1.5)
                local closestRegion = Region.GetClosest(localPlayer, regionsInRange, true)
                if closestRegion == nil then
                    outputChatBox('A region for the current player location could not be found. Make sure you create a region for it first.')
                    return
                end
        
                outputChatBox('Set the camera as you desire and press enter')
                setCamera = true
                moveTarget = false
                showCursor(true, true)
                outputChatBox("Use w/a/s/d/z/x/q/e to place and roll the camera, use scroll up/down to change the field of view", 255, 0, 0, false)
                outputChatBox("Press u to modify the coordinates of the camera target", 255, 0, 0, false)
                outputChatBox("Press enter to save the current camera and target setting", 255, 0, 0, false)

                local groundZ = getGroundPosition (localPlayer.position.x, localPlayer.position.y, localPlayer.position.z)
                if not groundZ or groundZ == 0 then
                    groundZ = localPlayer.position.z - 1
                end
    
                cameraTargetObject = Marker(localPlayer.position.x, localPlayer.position.y, groundZ, "cylinder", 1, 255, 255, 0, 128)
                cameraTargetObject.interior = localPlayer.interior
                local startingCameraPos = localPlayer.position + localPlayer.matrix.up * 1.2 - localPlayer.matrix.forward * 1.2
                editedObject = {
                    x = startingCameraPos.x,
                    y = startingCameraPos.y,
                    z = startingCameraPos.z,
                    lx = cameraTargetObject.position.x,
                    ly = cameraTargetObject.position.y,
                    lz = cameraTargetObject.position.z,
                    roll = 0,
                    fov = 70
                }
                Camera.setMatrix(
                    editedObject.x,
                    editedObject.y,
                    editedObject.z,
                    editedObject.lx,
                    editedObject.ly,
                    editedObject.lz,
                    editedObject.roll,
                    editedObject.fov
                )
                localPlayer.cameraInterior = localPlayer.interior
                local function addCamera(element)
                    if not closestRegion.cameras then
                        closestRegion.cameras = {}
                    end
                    table.insert(closestRegion.cameras, element)
                    showCursor(false)
                    setCameraTarget(localPlayer)
                    removeEventHandler("onElementDoneEditing", getRootElement(), addCamera)
                end
                addEventHandler("onClientKey", root, playerPressedKey)
                addEventHandler ( "onElementDoneEditing", getRootElement(), addCamera)
            elseif param1 == "region" then
                if not param2 or param2 == '' then
                    outputChatBox("region short name expected: episode add region name <end with ; > [ description optional ;] [ objects ; object1; object2 ; object3 optional]")
                    outputChatBox("don't forget to place a ; at the end of the name")
                    return
                end
                local name = param2;
                if #arg == 0 then
                    outputChatBox("info: region description was not provided")
                end
                local wholeStr = table.concat( arg, " " )
                local description = ''

                local t = split_string(wholeStr, ';')
                local objects = {}
                for i,obj in ipairs(t) do
                    if trim(obj) ~= 'objects' then
                        if i == 1 then
                            name = name .. " " .. trim(obj)
                        elseif i == 2 then
                            description = trim(obj)
                        else
                            table.insert(objects, trim(obj))
                        end
                    end
                end

                currentRegion = {
                    name = name,
                    Description = description,
                    Objects = objects,
                    vertexes = {},
                    center = Vector3(0,0,0),
                    markers = {}
                }
                outputChatBox("Started recording vertexes for the region "..name)
                outputChatBox("To add the vertexes, stop in each desired location clockwise or counterclockwise and execute the command: ")
                outputChatBox("episode add vertex")
            elseif param1 == "vertex" then
                if currentRegion == nil then
                    outputChatBox("First run the command to start recording a region: episode add region name [optional description]")
                    outputChatBox("Ex: episode add region bedroom [optional description]")
                    return
                end
                
                local function doneAddingVertexes()
                    currentRegion.center = currentRegion.center / #currentRegion.vertexes
                    currentRegion.center = currentRegion.center:unpack()
                    for _, m in ipairs(currentRegion.markers) do
                        m:destroy()
                    end
                    currentRegion.markers = nil
                    currentRegion = Region.ProcessVertexesPlane(currentRegion)
                    table.insert(episode.Regions, Region(currentRegion))
                    currentRegion = nil
                    outputChatBox("done adding vertexes")
                end

                if param2 == "done" then
                    doneAddingVertexes()
                    return
                end

                showCursor(true, true)
                local vertex = localPlayer.position
                local groundZ = getGroundPosition (vertex.x, vertex.y, vertex.z)
                if not groundZ or groundZ == 0 then
                    groundZ = vertex.z - 1
                end
                vertex.z = groundZ;

                outputChatBox("Place the vertex marker as desired and press enter", 255, 0, 0, false)
                outputChatBox("Use w/a/s/d/z/x/q/e/f/g/h/j to place and rotate the marker", 255, 0, 0, false)
                outputChatBox("Press enter to finish or n to cancel", 255, 0, 0, false)
                editedObject = Marker(vertex.x, vertex.y, vertex.z, "cylinder", 0.5, 255, 0, 0, 128)
                editedObject.interior = localPlayer.interior
                editedObject:setData('isTemporary', true)

                local function vertexMarkerSet(vertexMarker)
                    removeEventHandler("onElementDoneEditing", getRootElement(), vertexMarkerSet)
                    showCursor(false)
                    if vertexMarker == nil then
                        outputChatBox("Cancelled adding vertex")
                    else
                        local vertex = vertexMarker.position
                        currentRegion.center = currentRegion.center + vertex
                        table.insert(currentRegion.vertexes, vertex:unpack())
                        table.insert(currentRegion.markers, vertexMarker)
                        outputChatBox("vertex nr " .. #currentRegion.vertexes .. " added")
                        if #currentRegion.vertexes < 3 then
                            outputChatBox("at least "..(3 - #currentRegion.vertexes).." more needed to create a valid region")
                        end
                    end

                    if param2 == "last" then
                        doneAddingVertexes()
                    else
                        if #currentRegion.vertexes >= 2 then
                            outputChatBox("execute 'episode add vertex last' next, if the next vertex is the last one")
                        end
                        if #currentRegion.vertexes >= 3 then
                            outputChatBox("execute 'episode add vertex done' if you are done now and you don't wish to add any more vertexes")
                        end
                    end
                end

                addEventHandler("onClientKey", root, playerPressedKey)
                addEventHandler ( "onElementDoneEditing", getRootElement(), vertexMarkerSet)
            end
        elseif command == "linkactions" then
            local poi = nil
            local minDist = 1000
            for i,v in ipairs (episode.POI) do
                local dist = math.abs((localPlayer.position - Vector3(v.X, v.Y, v.Z)).length)
                if dist < minDist then
                    minDist = dist
                    poi = v
                end
            end
            if poi == nil then
                outputChatBox('Could not find any POI nearby. Place the player in the desired POI')
               return 
            end
            local toActionId = tonumber(param2)
            local fromActionId = tonumber(param1)
            if not fromActionId and param1 ~= "possibleActions" then
                outputChatBox("expected numeric action id or the keyword possibleActions but got "..(param1 or 'nil')..". Ex: episode linkactions 1 2 [{optional}closing] or episode linkactions possibleActions 1")
                return
            end
            if not toActionId then
                outputChatBox("expected numeric action id but got "..(param2 or 'nil')..". Ex: episode linkactions 1 2 [{optional}closing] or episode linkactions possibleActions 1")
                return
            end

            if toActionId > #poi.allActions then
                outputChatBox("param2 is greater than the number of actions defined in this POI "..toActionId.." vs "..#poi.allActions)
                return
            end
            local others = table.concat( arg, " " )
            local action2 = poi.allActions[toActionId]
            if param1 == "possibleActions" then
                table.insert(poi.PossibleActions, action2)
            else
                if fromActionId > #poi.allActions then
                    outputChatBox("param1 is greater than the number of actions defined in this POI "..fromActionId.." vs "..#poi.allActions)
                    return
                end
                local action1 = poi.allActions[fromActionId]
                if others == "closing" then
                    action1.ClosingAction = action2
                else
                    if not action1.NextAction then
                        action1.NextAction = action2
                    elseif isArray(action1.NextAction) then
                        table.insert(action1.NextAction, action2)
                    else
                        action1.NextAction = {action1.NextAction, action2}
                    end
                end
            end
        elseif command == "help" then
            outputChatBox("episode new: discards the currently loaded episode and initializes a new episode", 0, 0, 255, false)
            outputChatBox("episode run: plays the current episode", 0, 0, 255, false)
            outputChatBox("episode load episode_name: discards the currently loaded episode and loads a new episode", 0, 0, 255, false)
            outputChatBox("episode save episode_name [o]: saves the current episode; optional: o overwrites an existing episode", 0, 0, 255, false)
            outputChatBox("episode setgraph graph_path: sets the current's episode graph path", 0, 0, 255, false)
            outputChatBox("episode delete object: mark map objects to be deleted", 0, 0, 255, false)
            outputChatBox("episode restore object: restores a deleted world object", 0, 0, 255, false)
            outputChatBox("episode modify object: changes the object's position and rotation", 0, 0, 255, false)
            outputChatBox("episode add poi: add a point of interest (location)", 0, 0, 255, false)
            outputChatBox("episode add object: add object to be created", 0, 0, 255, false)
            outputChatBox("episode add action: add an action in the point of interest where the player is currently located", 0, 0, 255, false)
            outputChatBox("episode linkactions: in the POI where the player is located, add an action to the POI possibleActions, define NextAxtion (can contain multiple actions) for an action", 0, 0, 255, false)
        elseif command == "test" then
            if param1 == "action" then
                outputChatBox("episode test action name param1_name param1_value param2_name param2_value...", 255, 0, 0, false)
                local actionName = param2
                local params = {}
                local paramName = nil
                for i,v in ipairs(arg) do
                    outputChatBox(i.." "..v..' '..(i % 2))
                    if i % 2 == 0 then
                        params[paramName] = loadstring('return '..v)()
                    else
                        paramName = v
                    end
                end
                local function actionRetrieved(action)
                    removeEventHandler ( "onActionRetrieved", getRootElement(), actionRetrieved)
                    outputChatBox("action retrieved")
                    prevPosition = localPlayer.position
                    lastAction:Apply()
                end
                addEventHandler ( "onActionRetrieved", getRootElement(), actionRetrieved)
                getAction(actionName, params)
            elseif param1 == "poi" then
                local poi = nil
                local minDist = 1000
                for i,v in ipairs (episode.POI) do
                    local dist = math.abs((localPlayer.position - Vector3(v.X, v.Y, v.Z)).length)
                    if dist < minDist then
                        minDist = dist
                        poi = v
                    end
                end
                if poi then
                    localPlayer.position = poi.position
                    localPlayer.rotation = poi.rotation
                    poi:GetNextValidAction(localPlayer):Apply()
                else
                    outputChatBox('Couldn\'t find any pois')
                end
            elseif param1 == "camera" then
                local regionsInRange = Region.FilterWithinRange(localPlayer.position, episode.Regions, 1.5)
                local closestRegion = Region.GetClosest(localPlayer, regionsInRange, true)
                if closestRegion == nil then
                    outputChatBox('A region for the current player location could not be found. Make sure you create regions first.')
                    return
                end

                if not closestRegion.cameras then
                    outputChatBox("The region has no cameras defined",255,255,0)
                    return
                end
                local cam = nil
                local minDist = 1000
                for i,v in ipairs (closestRegion.cameras) do
                    local dist = math.abs((localPlayer.position - Vector3(v.x, v.y, v.z)).length)
                    if dist < minDist then
                        minDist = dist
                        cam = v
                    end
                end

                if cam == nil then
                    outputChatBox("No camera found nearby",255,255,0)
                    return
                end

                Camera.setMatrix(
                    cam.x,
                    cam.y,
                    cam.z,
                    cam.lx,
                    cam.ly,
                    cam.lz,
                    cam.roll,
                    cam.fov
                )
                localPlayer.cameraInterior = localPlayer.interior    
            else
                outputChatBox("Possible commands: \ntest action \ntest poi"..text,255,255,0)
            end
        elseif command == "attach" then
            local i = tonumber(param1)
            if not i then
                outputChatBox("Invalid arguments. Ex: episode attach id [optional: boneNr]")
            end
            editedObject = episode.Objects[i];
            isEditedObjectAttached = true
            local bone = tonumber(param2) or 12;

            local x = 0;
            local y = 0;
            local z = 0;
            local rx = 0;
            local ry = 0;
            local rz = 0;
            if editedObject.PosOffset then
                x = editedObject.PosOffset.x
                y = editedObject.PosOffset.y
                z = editedObject.PosOffset.z
            end
            if editedObject.RotOffset then
                rx = editedObject.PosOffset.rx
                ry = editedObject.PosOffset.ry
                rz = editedObject.PosOffset.rz
            end

            attachElementToBone(editedObject.instance, localPlayer, bone, x, y, z, rx, ry, rz)
            outputChatBox("Place the object where you want it to be attached and press enter. Reset the camera before doing this!", 255, 0, 0, false)
            outputChatBox("Use w/a/s/d/z/x/q/e/f/g/h/j to place and rotate it. Use alt for smaller changes and shift for big steps", 255, 0, 0, false)
            outputChatBox("Press enter to finish", 255, 0, 0, false)

            showCursor(true, true)
            addEventHandler("onClientKey", root, playerPressedKey)
            local function onAttachOffsetsSet(object)
                removeEventHandler("onElementDoneEditing", getRootElement(), onAttachOffsetsSet)
                detachElementFromBone(episode.Objects[i].instance)
                episode.Objects[i].instance.position = Vector3(episode.Objects[i].position.x, episode.Objects[i].position.y, episode.Objects[i].position.z)
                episode.Objects[i].instance.rotation = Vector3(episode.Objects[i].rotation.x, episode.Objects[i].rotation.y, episode.Objects[i].rotation.z)
                episode.Objects[i]:UpdateData(false)
                showCursor(false)
            end
            addEventHandler ( "onElementDoneEditing", getRootElement(), onAttachOffsetsSet)
        end
	end
)

--when defining a supertemplate, all coordinates will be relative to the localPlayer.position
--when defining an episode and you insert a supertemplate, it will be inserted first relative to localPlayer.position, then the relative point is edited and saved
--saved inside the episode along with the supertemplate name, offsets (and rotations) for each template individually, and a boolean (include template or not in the current episode)
--initially the offsets are 0, when defined the admin will have the option to save these offsets by default for templates

addCommandHandler("supertemplate",
    function (commandName, command, param1, param2, ...)
        if command == "new" then
            if not param1 then
                outputChatBox("name was expected but got empty. supertemplate new name", 255, 0, 0, false)
                return
            end
            --delete the current supertemplate
            supertemplate = Supertemplate{position = localPlayer.position, name = param1}
            outputChatBox("Supertemplate "..supertemplate.name.." initialized at player position", 255, 0, 0, false)
        elseif command == 'load' then
            if not param1 then
                outputChatBox("name was expected but got empty. supertemplate load name", 255, 0, 0, false)
                return
            end
            supertemplate = Supertemplate.Load(param1)
            outputChatBox("Supertemplate loaded", 255, 0, 0, false)
        elseif command == "save" then
            if param2 ~= "o" and fileExists("files/supertemplates/"..param1.."/"..param1..".json") then
                outputChatBox("files/supertemplates/"..param1.."/"..param1..".json already exists. To overwrite it type supertemplate save template_name o", 255, 0, 0, false)
                return
            end

            local fileHandle = fileCreate("files/supertemplates/"..param1.."/"..param1..".json")
            if fileHandle then
                local jsonStr = toJSON(supertemplate:Serialize())
                fileWrite(fileHandle, jsonStr)
                fileClose(fileHandle)
                outputChatBox("Saved files/supertemplates/"..param1.."/"..param1..".json", 255, 0, 0, false)
            end
        elseif command == 'showtemplates' then
            outputChatBox('supertemplate templates nr: '..#supertemplate.templates)
            for _,t in ipairs(supertemplate.templates) do
                outputChatBox(t)
            end
        elseif command == 'who' then
            outputChatBox('supertemplate ' .. supertemplate.name)
        elseif command == 'add' then
            --add the current template to the supertemplate
            if param1 == 'current' or param1 == nil or param1 == '' then
                if #supertemplate.templates == 0 then
                    supertemplate.position = template.position
                else
                    local firstTemplate = Template.Load(supertemplate.name, supertemplate.templates[1])
                    template:ComputeGlobalCentroid()
                    template:Rebase(supertemplate.position, 
                        Vector3(
                            firstTemplate.globalCentroid.x,
                            firstTemplate.globalCentroid.y,
                            firstTemplate.globalCentroid.z
                        ) - template.globalCentroid
                    )
                end 
                template:Serialize("files/supertemplates/"..supertemplate.name)
                table.insert(supertemplate.templates, template.name)
            else
                local template = Template.Load(supertemplate.name, param1)
                if #supertemplate.templates == 0 then
                    supertemplate.position = template.position
                else
                    local firstTemplate = Template.Load(supertemplate.name, supertemplate.templates[1])
                    template:ComputeGlobalCentroid()
                    template:Rebase(
                        supertemplate.position, 
                        Vector3(
                            firstTemplate.globalCentroid.x,
                            firstTemplate.globalCentroid.y,
                            firstTemplate.globalCentroid.z
                        ) - template.globalCentroid
                    )
                end 
                template:Serialize("files/supertemplates/"..supertemplate.name)
                table.insert(supertemplate.templates, template.name)
            end
            outputChatBox('supertemplate templates nr: '..#supertemplate.templates)
        elseif command == 'insert' then
            if param1 then
                supertemplate = Supertemplate.Load(param1)
            end
            --the relative point is the current player location, insert in turn all templates from the supertemplate, obtaining the offsets
            supertemplate.templateIdx = 1
            template = Template.Load(supertemplate.name, supertemplate.templates[supertemplate.templateIdx])
            if not template then
                outputChatBox("Something went wrong while deserializing the template")
                return
            end
            supertemplate.position = localPlayer.position
            supertemplate.offsets = {}
            template:Instantiate(localPlayer.interior, supertemplate.position)
            showCursor(true, true)
            outputChatBox("Use w/a/s/d/z/x/q/e/f/g/h/j to place and rotate the object", 255, 0, 0, false)
            outputChatBox("Press backspace to mark the template to be skipped", 255, 0, 0, false)
            outputChatBox("Press enter to finish", 255, 0, 0, false)
            editedObject = template
            isTemplate = true   
            relativePosition = supertemplate.position
            addEventHandler("onClientKey", root, playerPressedKey)

            local function finishedOffsettingTemplate(edited_template)
                showCursor(false)
                removeEventHandler("onElementDoneEditing", getRootElement(), finishedOffsettingTemplate)

                if #supertemplate.offsets < supertemplate.templateIdx then
                    table.insert(supertemplate.offsets, template:GetSerializedOffsets())
                else
                    local offsets = supertemplate.offsets[supertemplate.templateIdx]
                    template.offset = template.offset + Vector3(offsets.offset.x, offsets.offset.y, offsets.offset.z)
                    template.rotationOffset = template.rotationOffset + Vector3(offsets.rotationOffset.x, offsets.rotationOffset.y, offsets.rotationOffset.z)
                    supertemplate.offsets[supertemplate.templateIdx] = template:GetSerializedOffsets()
                end
                supertemplate.templateIdx = supertemplate.templateIdx + 1
                if supertemplate.templateIdx <= #supertemplate.templates then
                    template:Destroy()
                    template = Template.Load(supertemplate.name, supertemplate.templates[supertemplate.templateIdx])
                    if not template then
                        outputChatBox("Something went wrong while deserializing the template")
                        return
                    end
                    --insert the next template (with offsets from supertemplate)
                    template:Instantiate(localPlayer.interior, supertemplate.position)
                    showCursor(true, true)
                    outputChatBox("Use w/a/s/d/z/x/q/e/f/g/h/j to place and rotate the object", 255, 0, 0, false)
                    outputChatBox("Press backspace to mark the template to be skipped", 255, 0, 0, false)
                    outputChatBox("Press enter to finish", 255, 0, 0, false)
                    nextEditSameThing = true
                    editedObject = template
                    isTemplate = true
                    addEventHandler("onClientKey", root, playerPressedKey)
                    addEventHandler ( "onElementDoneEditing", getRootElement(), finishedOffsettingTemplate)
                else
                    supertemplate.instantiatedTemplate = template
                    --insert serialized supertemplate in episode
                    supertemplate.position = supertemplate.position:unpack()
                    table.insert(episode.supertemplates, supertemplate)
                end
            end  
            addEventHandler ( "onElementDoneEditing", getRootElement(), finishedOffsettingTemplate)
        end
    end
)
--the coordinates of the mainpoi is not relative
addCommandHandler("template",
    function (commandName, command, param1, param2, ...)
        if command == "save" then
            outputChatBox('Notice that this command only serializes the template now (it doesn\'t serialize the closest poi)\nAnd only as part of a supertemplate')
            local name = param2
            if not name or name == 'o' then
                name = template.name
            end
            template.name = name
            if not name then
                outputChatBox('The template does not have a name, write template save name')
                return
            end
            local param3 = arg[1]
            --the user can save a template but only directly in a supertemplate folder
            --save template, load supertemplate, add template name to supertemplate.templates list, overwrite supertemplate json file
            if param2 ~= "o" and param3 ~= 'o' and fileExists("files/supertemplates/"..param1.."/"..name..".json") then
                outputChatBox("files/supertemplates/"..param1.."/"..name..".json already exists. To overwrite it type template save supertemplate_name [optional - template_name] o", 255, 0, 0, false)
                return
            end
            --idea: if the supertemplate doesn't have any templates yet => the supertemplate relative point = template.relativePoint; compute the template globalCentroid
            --else offset the current template with the vector firstTemplate.centroid - curTemplate.centroid in global coordinates, then recompute the coordinates relative to the supertemplate's relative point
            local supertemplate = Supertemplate.Load(param1)
            if not supertemplate then
                outputChatBox('The supertemplate '..param1..' doesn\'t exist. Make sure it is saved first (the full path mods/deathmatch/resources/sv2l/files/supertemplates/'..param1..'/'..param1..'.json exists)')
                return
            end

            if #supertemplate.templates == 0 then
                supertemplate.position = template.position
            else
                local firstTemplate = Template.Load(param1, supertemplate.templates[1])
                template:ComputeGlobalCentroid()
                template:Rebase(
                    supertemplate.position, 
                    Vector3(
                        firstTemplate.globalCentroid.x, 
                        firstTemplate.globalCentroid.y, 
                        firstTemplate.globalCentroid.z
                    ) - template.globalCentroid
                )
            end 
            template:Serialize("files/supertemplates/"..param1)
            table.insert(supertemplate.templates, template.name)
            supertemplate:Serialize(param1)
        elseif command == 'load' then
            if not param1 or param1 == '' then
                outputChatBox('supertemplate name expected. template load supertemplate_name template_name')
                return
            end
            if not param2 or param2 == '' then
                outputChatBox('template name expected. template load supertemplate_name template_name')
                return
            end
            template = Template.Load(param1, param2)
            outputChatBox('template '..param2..' from supertemplate '..param1..'successfully loaded')
        elseif command == 'new' then
            if not param1 then
                outputChatBox("name was expected but got empty. template new name", 255, 0, 0, false)
                return
            end
            template = Template({name = param1})
            outputChatBox("template "..template.name..' initialized', 255, 0, 0, false)
        elseif command == "add" then
            if param1 == "poi" then
                local poi = nil
                local minDist = 1000
                for i,v in ipairs (episode.POI) do
                    local dist = math.abs((localPlayer.position - Vector3(v.X, v.Y, v.Z)).length)
                    if dist < minDist then
                        minDist = dist
                        poi = v
                    end
                end
    
                if not poi then
                    outputChatBox("Could not find a POI nearby!")
                    return
                else
                    outputChatBox("Found a POI nearby")
                end

                local relativePoint = localPlayer.position
                if template.position then 
                    relativePoint = template.position
                else
                    template.position = localPlayer.position
                end
    
                local mainPoi, objects, locations = poi:Serialize(episode, relativePoint, template.objects, template.locations, template.poi, true)
                outputChatBox("poi serialized: "..#objects..' objects ; '..#locations..' locations and the main poi')

                template:AddItems(mainPoi, objects, locations)

                outputChatBox("poi successfully added ")
            elseif param1 == 'object' then
                if param2 == nil or param2 == '' or not tonumber(param2) then
                    outputChatBox('Object id expected. template add object objectid')
                    return
                end

                if not template.position then 
                    template.position = localPlayer.position
                end
                
                local id = tonumber(param2)
                if #Where(template.objects, function (x) return x.id == id end) == 0 then
                    local sourceObject = episode.Objects[id]
                    local objectCopy = SampStoryObjectBase(sourceObject)
                    local targetItemRelativePosition = Vector3(sourceObject.position.x, sourceObject.position.y, sourceObject.position.z) - template.position
                    objectCopy.position = targetItemRelativePosition
                    objectCopy.instance = nil
                    objectCopy:UpdateData(true)
                    objectCopy.id = id

                    table.insert(template.objects, {
                        id = objectCopy.id, 
                        dynamicString = objectCopy.dynamicString
                    })
                end

                outputChatBox("object successfully added "..param2)
            else
                outputChatBox("template add poi or template add object id")
            end
        elseif command == "insert" then
            if param1 and param2 then
                template = Template.Load(param1, param2)
                if not template then
                    outputChatBox("Something went wrong while deserializing the template")
                    return
                end
            else
                outputChatBox("trying to instantiate the current template")
            end
            --Create the marker for the POI, the objects as dependencies and the markers for the other dependent locations
            template:Instantiate(localPlayer.interior, localPlayer.position)
            --First: ask the player to position the main poi
            local function includeTemplateInEpisode(edited_template)
                showCursor(false)
                removeEventHandler("onElementDoneEditing", getRootElement(), includeTemplateInEpisode)
                if template.skip then
                    outputChatBox("The template is marked to be skipped")
                    return
                end
                outputChatBox("Episode objects before: "..#episode.Objects, 255, 255, 255, false)
                outputChatBox("Episode poi before: "..#episode.POI, 255, 255, 255, false)

                if template:InsertInEpisode(episode) then
                    outputChatBox("Episode objects after: "..#episode.Objects, 255, 255, 255, false)
                    outputChatBox("Episode poi after: "..#episode.POI, 255, 255, 255, false)
    
                    outputChatBox("Template: ".. #template.objects .." dependent objects inserted...", 255, 255, 255, false)
                    outputChatBox("Template: ".. #template.locations .." dependent poi inserted...", 255, 255, 255, false)
                    outputChatBox("Done. Template with all dependencies inserted.", 255, 0, 0, false)                    
                end
            end                
            showCursor(true, true)
            outputChatBox("Use w/a/s/d/z/x/q/e/f/g/h/j to place and rotate the object", 255, 0, 0, false)
            outputChatBox("Press enter to finish", 255, 0, 0, false)
            editedObject = template
            isTemplate = true
            relativePosition = localPlayer.position
            addEventHandler("onClientKey", root, playerPressedKey)
            addEventHandler ( "onElementDoneEditing", getRootElement(), includeTemplateInEpisode)
        else
            outputChatBox("Command not found. Try the following: template save; template create; template insert; template add poi; template add object")
            outputChatBox("A template is a POI, with actions and their dependencies. The actions dependencies are their target items and next locations.")
            outputChatBox("Target items can be objects, locations or nothing.")
        end
    end
)