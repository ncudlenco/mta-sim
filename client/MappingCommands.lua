
local json = {}
local markers = {}
local function text_render ( )
    for i, node in pairs ( json ) do
        if #markers == #json and i > 100 then
            break
        end
        local x = node["x"]
        local y = node["y"]
        local z = node["z"]
        local id = node["id"]
        local sx, sy, _ = getScreenFromWorldPosition ( x, y, z )

        local playerZ = localPlayer.position.z
        if (localPlayer.position - Vector3(x, y, z)).length < 10 then
            if sx then
                local sw, sh = guiGetScreenSize ( )
                dxDrawText ( id.." "..toJSON(node["edges"]), sx, sy, sw, sh, tocolor ( 255, 200, 0, 255 ), 1.0, "default-bold" )
            end
        end

        if #markers < #json then
            local r = 255
            local g = 0
            if #node["edges"] > 0 then
                r = 0
                g = 255
            end
            local marker = Marker(x, y, z, "cylinder", 1, r, g, 0, 128)
            marker.interior = localPlayer.interior
            table.insert(markers, marker)
        end
    end
end

addCommandHandler("graph",
    function (commandName, command, param1)
        if command == "new" then
            removeEventHandler("onClientRender", getRootElement(), text_render)
            json = {}
            for _, marker in pairs ( markers ) do
                marker:destroy()
            end
            markers = {}
            outputChatBox("New graph initialized", 255, 0, 0, false)
		    addEventHandler("onClientRender", getRootElement(), text_render)
        elseif command == "load" then
            if param1 then
                file = fileOpen("files/paths/"..param1..".json")
                if file then
                    local jsonStr = fileRead(file, fileGetSize(file))
                    jsonStr = jsonStr:gsub("%[%s*{", "%[ %[ {"):gsub("}%s*]", "} ] ]")
                    json = fromJSON(jsonStr)
                    fileClose(file)
                    outputChatBox("Loaded files/paths/"..param1..".json", 255, 0, 0, false)
                else
                    outputChatBox("File not found files/paths/"..param1..".json", 255, 0, 0, false)
                end
            else
                outputChatBox("Parameter graph_name not provided. Ex: graph load graph_name", 255, 0, 0, false)
            end
        elseif command == "save" then
            if param1 then
                local fileHandle = fileCreate("files/paths/"..param1..".json")
                if fileHandle then
                    local jsonStr = toJSON(json)
                    jsonStr = jsonStr:gsub("%[%s*%[%s*{", "%[ {"):gsub("}%s*]%s*]", "} ]")
                    fileWrite(fileHandle, jsonStr)
                    fileClose(fileHandle)
                    outputChatBox("Saved files/paths/"..param1..".json", 255, 0, 0, false)
                end
            else
                outputChatBox("Parameter graph_name not provided. Ex: graph load graph_name", 255, 0, 0, false)
            end
        end
	end
)

addCommandHandler("modify",
function (commandName, what, param1, param2)
    if what == "node" then
        if not param1 then
            outputChatBox("A node id was expected: Ex: modify node 5")
            return
        end

        local id = tonumber(param1)
        local groundZ = getGroundPosition (localPlayer.position.x, localPlayer.position.y, localPlayer.position.z)
        if not groundZ or groundZ == 0 then
            groundZ = localPlayer.position.z - 1
        end
        json[id].x = localPlayer.position.x
        json[id].y = localPlayer.position.y
        json[id].z = groundZ
    end
end
)

addCommandHandler("add",
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