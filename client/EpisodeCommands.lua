addEvent ( "onElementDoneEditing", true )

local episode = DynamicEpisode()
local markers = {}
local function text_render ( )
    for i, obj in ipairs(episode.ObjectsToDelete) do
        local sx, sy, _ = getScreenFromWorldPosition(obj.position.x, obj.position.y, obj.position.z)
        if sx then 
            local sw, sh = guiGetScreenSize ( )
            dxDrawText ("deleted", sx, sy, sw, sh, tocolor ( 255, 0, 0, 255 ), 2.0, "default-bold" ) 
        end 
    end
    for i, poi in ipairs ( episode.POI ) do 
        if #markers == #episode.POI and i > 100 then
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
                dxDrawText ( poi.idr..":"..poi.Description.."\n"..toJSON(poi.PossibleActions), sx, sy, sw, sh, tocolor ( 255, 200, 0, 255 ), 1.0, "default-bold" ) 
            end 
        end

        if #markers < #episode.POI then
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
    markers = {}
    episode:Destroy()
    return true
end

local editedObject = nil
local function playerPressedKey(button, press)
    if (press) then
        if button == "w" then
            editedObject.position = editedObject.position + Vector3(.1,0,0)
        elseif button == "s" then
            editedObject.position = editedObject.position + Vector3(-.1,0,0)
        elseif button == "a" then
            editedObject.position = editedObject.position + Vector3(0,-.1,0)
        elseif button == "d" then
            editedObject.position = editedObject.position + Vector3(0,.1,0)
        elseif button == "z" then 
            editedObject.position = editedObject.position + Vector3(0,0,.1)
        elseif button == "x" then
            editedObject.position = editedObject.position + Vector3(0,0,-.1)
        elseif button == "q" then
            editedObject.rotation = editedObject.rotation + Vector3(0,0,5)
        elseif button == "e" then
            editedObject.rotation = editedObject.rotation + Vector3(0,0,-5)
        elseif button == "h" then
            editedObject.rotation = editedObject.rotation + Vector3(0,5,0)
        elseif button == "j" then
            editedObject.rotation = editedObject.rotation + Vector3(0,-5,0)
        elseif button == "f" then
            editedObject.rotation = editedObject.rotation + Vector3(5,0,0)
        elseif button == "g" then
            editedObject.rotation = editedObject.rotation + Vector3(-5,0,0)
        elseif button == "mouse_wheel_up" then
            if editedObject.size then
                editedObject.size = editedObject.size + 0.5
            end
        elseif button == "mouse_wheel_down" then
            if editedObject.size then
                editedObject.size = editedObject.size - 0.5
            end
        elseif button == "enter" then
            showCursor(false)
            removeEventHandler("onClientKey", root, playerPressedKey)
            triggerEvent ( "onElementDoneEditing", getRootElement(), editedObject )
            editedObject = nil
        end
    end
end

addCommandHandler("episode",
    function (commandName, command, param1, param2, ...)
        if command == "new" then
            unloadEpisode(episode)
            episode = DynamicEpisode()
            episode.InteriorId = localPlayer.interior
            if param1 then
                episode.name = param1
            end
            
            outputChatBox("New episode initialized", 255, 0, 0, false)
            addEventHandler("onClientRender", getRootElement(), text_render)
        elseif command == "run" then
            episode:Initialize(localPlayer)
        elseif command == "load" then
            unloadEpisode(episode)
            if param1 then
                episode = DynamicEpisode(param1)
                if episode:LoadFromFile() then
                    episode:Initialize(localPlayer)
                    outputChatBox("Loaded files/episodes/"..episode.name..".json", 255, 0, 0, false)
                else
                    outputChatBox("File not found files/episodes/"..episode.name..".json", 255, 0, 0, false)
                end
            else
                outputChatBox("Parameter episode_name not provided. Ex: episode load episode_name", 255, 0, 0, false)
            end
		    addEventHandler("onClientRender", getRootElement(), text_render)
        elseif command == "save" then
            if param1 then
                episode.name = param1
                --TODO: check if all the required parameters are given
                if not episode.graph_path then
                    outputChatBox("Warning: the graph_path is not set. Run episode setgraph graph_name to set it.", 255, 0, 0, false)
                end
                if param2 ~= "o" and fileExists("files/episodes/"..param1..".json") then
                    outputChatBox("files/episodes/"..param1..".json already exists. To overwrite it type episode save episode_name o", 255, 0, 0, false)
                    return
                end
                local instances = {}
                for _,obj in ipairs(episode.Objects) do
                    table.insert(instances, obj.instance)
                    obj.instance = nil
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
        elseif command == "delete" then
            if param1 == "object" then
                if not param2 then
                    outputChatBox("[info] Write the modelId for the world object to be deleted: Ex: episode delete object 2255", 255, 0, 0, false)
                end
                outputChatBox("Select the (position of the) object to be deleted.", 255, 0, 0, false)
                showCursor(true, true)
                function onClick(button, state, absoluteX, absoluteY, worldX, worldY, worldZ, element)
                    if state ~= "up" then
                        return
                    end 
                    outputChatBox("Clicked at "..worldX..", "..worldY..", "..worldZ, 255, 0, 0, false)
                    if not param2 then
                        if not element then
                            outputChatBox("No object could be retrieved. Try again or maybe give the world model modelid if you intended to delete a world model.", 255, 0, 0, false)
                        else
                            for i,v in ipairs (episode.Objects) do
                                if
                                    v.modelid == element.modelid
                                    and v.interior == element.interior
                                    and math.abs(Vector3(v.position.x, v.position.y, v.position.z) - element.position) < 0.1
                                then
                                    v:Destroy()
                                    table.remove(episode.Objects, i)
                                    outputChatBox("Object found in current episode and deleted", 255, 0, 0, false)
                                    return
                                end
                            end
                            outputChatBox("Object not found in current episode", 255, 0, 0, false)
                        end
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
        elseif command == "add" then
            if param1 == "poi" then
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
                    outputChatBox("Object modelid expected: Ex: episode add object 2281 painting", 255, 0, 0, false)
                    return
                end
                local description = table.concat( arg, " " )
                if not description then
                    outputChatBox("Object description expected: Ex: episode add object 2281 painting", 255, 0, 0, false)
                    return
                end

                outputChatBox("Select the position of the object to be created.", 255, 0, 0, false)
                showCursor(true, true)
                function onClick(button, state, absoluteX, absoluteY, worldX, worldY, worldZ, element)
                    outputChatBox("Clicked at "..worldX..", "..worldY..", "..worldZ, 255, 0, 0, false)
                    local modelId = tonumber(param2)

                    local function addObjectToCreate(obj)
                        showCursor(false)
                        removeEventHandler("onElementDoneEditing", getRootElement(), addObjectToCreate)
                        local object = SampStoryObjectBase {
                            description = description,
                            modelid = obj.modelid,
                            position = obj.position:unpack(),
                            rotation = obj.rotation:unpack(),
                            interior = obj.interior
                        }
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
            end
        elseif command == "help" then
            outputChatBox("episode new: discards the currently loaded episode and initializes a new episode", 255, 0, 0, false)
            outputChatBox("episode load episode_name: discards the currently loaded episode and loads a new episode", 255, 0, 0, false)
            outputChatBox("episode save episode_name [o]: saves the current episode; optional: o overwrites an existing episode", 255, 0, 0, false)
            outputChatBox("episode setgraph graph_path: sets the current's episode graph path", 255, 0, 0, false)
            outputChatBox("episode delete object: mark map objects to be deleted", 255, 0, 0, false)
        end
	end
)

addCommandHandler("eadd",
	function (commandName, what, param1, param2)
        if what == "node" then
            local mapId = #json
            local groundZ = getGroundPosition (localPlayer.position.x, localPlayer.position.y, localPlayer.position.z)
            if not groundZ or groundZ == 0 then
                groundZ = localPlayer.position.z - 1
            end
            table.insert(json, {id = mapId, x = localPlayer.position.x, y = localPlayer.position.y, z = groundZ, edges = {}})
            outputChatBox("Node "..mapId.." added", 255, 0, 0, false)
        elseif what == "edge" then
            if param1 and param2 then
                local id1 = tonumber(param1)
                local id2 = tonumber(param2)
                local idx1 = id1+1
                local idx2 = id2+1
    
                local node1 = json[idx1]
                local node2 = json[idx2]

                markers[idx1]:setColor(0,255,0,128)
                markers[idx2]:setColor(0,255,0,128)
    
                local v2 = Vector3(node2["x"], node2["y"], node2["z"])
                local v1 = Vector3(node1["x"], node1["y"], node1["z"])
                local edgeV = v2 - v1
                table.insert(json[idx1]["edges"], {id2, math.abs(math.floor(edgeV.length))})
                table.insert(json[idx2]["edges"], {id1, math.abs(math.floor(edgeV.length))})
            else
                outputConsole("Parameter id1 or id2 not provided. Ex: add edge 0 1")
            end
		end
	end
)