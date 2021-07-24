Template = class(function(o, params)
    o.poi = params.poi or params.POI or {isEmpty=true}
    o.objects = params.objects or params.Objects or {}
    o.locations = params.locations or params.Locations or {}
    o.name = params.name or ''
    o.position = params.position
    if not params.position and (params.poi or params.POI) then
        o.position = Vector3(o.poi.X, o.poi.Y, o.poi.Z)
    end
    if o.position then
        o.position = Vector3(o.position.x, o.position.y, o.position.z)
    end
    o.globalCentroid = params.globalCentroid or nil
    o.offset = Vector3(0,0,0)
    o.rotationOffset = Vector3(0,0,0)
end)

function Template:ComputeGlobalCentroid()
    self.globalCentroid = Vector3(0,0,0)
    for _,p in pairs(self.locations) do
        self.globalCentroid = self.globalCentroid + Vector3(p.X, p.Y, p.Z)
    end
    for _,o in pairs(self.objects) do
        local obj = loadstring(o.dynamicString)()
        self.globalCentroid = self.globalCentroid + obj.position
    end
    --now the centroid is in coordinates relative to the template.position
    self.globalCentroid = self.globalCentroid / (#self.locations + #self.objects)
    --rebase it in global coordinates
    self.globalCentroid = self.globalCentroid + self.position
end

--poi here is the fixed point, relative to which the coordinates of the objects and locations are saved
--when a template is part of a supertemplate, poi must be equal to the relative point of the supertemplate
function Template:Instantiate(interior, position)
    print('Template:Instantiate interior '..interior)
    self.poi.instance = Marker(position.x, position.y, position.z - 1, "cylinder", 1, 255, 0, 255, 128)
    self.poi.instance.interior = interior

    for _,o in pairs(self.objects) do
        local obj = loadstring(o.dynamicString)()
        obj.interior = interior
        obj.position = position + obj.position
        obj:Create()
        o.instance = obj.instance
    end

    for _,p in pairs(self.locations) do
        local relativelyMoved = position + Vector3(p.X, p.Y, p.Z)
        p.instance = Marker(relativelyMoved.x, relativelyMoved.y, relativelyMoved.z - 1, "cylinder", 1, 0, 255, 255, 128)
        p.instance.interior = interior
        p.interior = interior
    end
end

function Template:Destroy()
    if isElement(self.poi.instance) then
        self.poi.instance:destroy()
    end
    for _,o in pairs(self.objects) do
        if isElement(o.instance) then
            o.instance:destroy()
        end
    end
    for _,p in pairs(self.locations) do
        if isElement(p.instance) then
            p.instance:destroy()
        end
    end
end

function Template:Rebase(newRelativePosition, offsetVector)
    local oldRelativePosition = self.position
    self.position = newRelativePosition
    if self.poi.instance then
        self.poi.instance.position = self.position
    end
    for _,o in pairs(self.objects) do
        local obj = loadstring(o.dynamicString)()
        --             (   global coordinates           )   offseted to another centroid ; compute relative to the new position
        obj.position = oldRelativePosition + obj.position + offsetVector - newRelativePosition
        if obj.instance then
            obj.instance = obj.position
        end
        obj:UpdateData(true)
    end
    for _,p in pairs(self.locations) do
        local newPosition = Vector3(p.X, p.Y, p.Z) + oldRelativePosition + offsetVector - newRelativePosition
        p.X = newPosition.x
        p.Y = newPosition.z
        p.Z = newPosition.z
    end
end

function Template:UpdatePosition(translation, rotation, relativePosition, dontUpdateOffsets)
    if not self.poi.instance then
        return false
    end
    if translation then
        self.poi.instance.position = self.poi.instance.position + translation
        if not dontUpdateOffsets then
            self.offset = self.offset + translation
        end
    elseif rotation then
        if self.poi and self.poi.Angle then
            self.poi.Angle = self.poi.Angle + rotation.z
        end
        if relativePosition then
            local p = self.poi.instance.position - Vector3(self.offset.x, self.offset.y, self.offset.z) - relativePosition
            p = p:Rotate(rotation)
            p = p + Vector3(self.offset.x, self.offset.y, self.offset.z) + relativePosition
            self.poi.instance.position = p
        end
        if not dontUpdateOffsets then
            self.rotationOffset = self.rotationOffset + rotation
        end
    end
    if not relativePosition then
        relativePosition = self.poi.instance.position
    end
    self.X = self.poi.instance.position.x
    self.Y = self.poi.instance.position.y
    self.Z = self.poi.instance.position.z
    self.position = Vector3(self.X, self.Y, self.Z)
    if self.objects then
        for _,v in pairs(self.objects) do
            if v.instance then
                if translation then
                    v.instance.position = v.instance.position + translation
                elseif rotation then
                    v.instance.rotation = v.instance.rotation + rotation
                    local p = v.instance.position - Vector3(self.offset.x, self.offset.y, self.offset.z) - relativePosition
                    p = p:Rotate(rotation)
                    p = p + Vector3(self.offset.x, self.offset.y, self.offset.z) + relativePosition
                    v.instance.position = p
                end
            end
        end
    end
    if self.locations then
        for _,v in pairs(self.locations) do
            if v.instance then
                if translation then
                    v.instance.position = v.instance.position + translation
                elseif rotation then
                    local p = v.instance.position - Vector3(self.offset.x, self.offset.y, self.offset.z) - relativePosition
                    p = p:Rotate(rotation)
                    p = p + Vector3(self.offset.x, self.offset.y, self.offset.z) + relativePosition
                    v.instance.position = p
                end
            end
        end
    end
end

--steps for defining supertemplates
--episode new (clears all current objects)
--supertemplate new name
--supertemplate save name [o]
--+++++++++++++++++++++++++++++++++++++++++++++++++
--++repeat for all the templates in a supertemplate
--+++++++++++++++++++++++++++++++++++++++++++++++++
--++create a template the old way or template insert templates old_template_name
--++template new supertemplate_name template_name
--++template add poi / template add object until done
--++template save supertemplate_name template_name
--+++++++++++++++++++++++++++++++++++++++++++++++++
--up until now we have a supertemplate with templates all placed relative to the first template position (supertemplate position = templates[0].position)
--now we must fine-tune the offsets for all templates relative to this position
--supertemplate insert name or supertemplate load name ; supertemplate insert
--supertemplate position is set to the current player position
--each template will be inserted, the user will translate / rotate the template as needed or set it to be skipped
--when done offsetting the template, the offsets / skip flag are stored serialized inside the supertemplate object
--the supertemplate object is pushed in the supertemplates array of the episode
--[optional] at this point the user may write supertemplate save name o to save the offsets as default (the skip flag is ignored when inserting via supertempalte insert command)
--after the episode initialize (not for editing purposes), the supertemplates are expanded into api objects, pois and actions
-----(for each temlate in the supertemplate, instantiate with offsets relative to the supertemplate position then insert in episode)

function Template:GetSerializedOffsets()
    return {
        skip = self.skip and true or false, --force the type to bool
        offset = self.offset:unpack(),
        rotationOffset = self.rotationOffset:unpack()
    }
end

function Template:Serialize(directory)
    self:ComputeGlobalCentroid()
    local instances = {}
    for _,obj in ipairs(self.objects) do
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
    end

    local template = {
        poi = self.poi, --serialized beforehand
        objects = self.objects,
        locations = self.locations, --these must be serialized beforehand
        globalCentroid = self.globalCentroid:unpack(),
        position = self.position:unpack(),
        name = self.name
    }
    local fileHandle = fileCreate(directory.."/"..self.name..".json")
    if fileHandle then
        local jsonStr = toJSON(template)
        fileWrite(fileHandle, jsonStr)
        fileClose(fileHandle)
        outputChatBox("Saved "..directory.."/"..self.name..".json", 255, 0, 0, false)
    end
    if #instances == #self.objects then
        for i,obj in ipairs(self.objects) do
            obj.instance = instances[i]
        end
    end
end

function Template:InsertInEpisode(episode, deserialize)
    local template = self
    local objectsMap = {}
    local poiMap = {}
    --add the dependent objects in the episode objects list
    for _,o in ipairs(template.objects) do
        local obj = loadstring(o.dynamicString)()
        obj.instance = o.instance
        obj:UpdateData(not (deserialize and true or false))
        table.insert(
            episode.Objects,
            obj
        )
        objectsMap[o.id] = #episode.Objects
    end
    local function addSerializedPoiToTmpList(v, idx)
        v.X = v.instance.position.x
        v.Y = v.instance.position.y
        v.Z = v.instance.position.z + 1
        v.Interior = v.instance.interior
        v.instance:destroy()
        print('v.Interior: '..v.Interior)
        local obj = Location(v.X, v.Y, v.Z, v.Angle, v.Interior, v.Description)
        table.insert(episode.POI, obj)
        poiMap[v.id] = #episode.POI
    end
    local allPoi = {}
    if not template.poi.isEmpty then
        table.insert(allPoi, template.poi)
        --add the current poi in a temporary POI list
        addSerializedPoiToTmpList(template.poi)
    end
    if isElement(template.poi.instance) then
        template.poi.instance:destroy()
    end
    outputChatBox('reached locations processing')
    --add the dependent POI in the temporary POI list
    for _,v in ipairs(template.locations) do
        addSerializedPoiToTmpList(v)
        table.insert(allPoi, v)
    end
    --remap the action target ids in all POI from the temporary list
    for _,rawpoi in ipairs(allPoi) do
        local poi = episode.POI[poiMap[rawpoi.id]]
        --order is important here!
        local deserializedAllActions = {}
        for _,a in ipairs(rawpoi.allActions) do
            local action = loadstring(a.dynamicString)()
            action.id = a.id
            action.TargetItem = nil
            if a.targetItem then
                if a.targetItem.type == "Object" then
                    action.TargetItem = episode.Objects[objectsMap[a.targetItem.id] or a.targetItem.id]
                elseif a.targetItem.type == "Location" then
                    if poiMap[a.targetItem.id] > episode.POI then
                        action.TargetItem = episode.POI[poiMap[a.targetItem.id] or a.targetItem.id]
                    else

                    end
                end
            end
            if a.nextLocation then
                action.NextLocation = episode.POI[poiMap[a.nextLocation.id] or a.nextLocation.id]
            end
            table.insert(deserializedAllActions, action)
        end
        for i,a in ipairs(rawpoi.allActions) do
            local action = deserializedAllActions[i]
            if a.nextAction then
                if isArray(a.nextAction) then
                    action.NextAction = {}
                    for _, na in ipairs(a.nextAction) do
                        table.insert(action.NextAction, deserializedAllActions[na.id])
                    end
                else                    
                    action.NextAction = deserializedAllActions[a.nextAction.id]
                end
            end
            if a.closingAction then
                action.ClosingAction = deserializedAllActions[a.closingAction.id]
            end
        end
        poi.allActions = deserializedAllActions
        local deserializedPossibleActions = {}
        for _,a in ipairs(rawpoi.PossibleActions) do
            table.insert(deserializedPossibleActions, deserializedAllActions[a.id])
        end
        poi.PossibleActions = deserializedPossibleActions
    end
    return true
end

function Template:AddItems(mainPoi, objects, locations)
    -- for _,l in ipairs(objects) do
    --     table.insert(self.objects, o)
    -- end
    -- for _,l in ipairs(locations) do
    --     table.insert(self.locations, o)
    -- end
    if #Where(self.locations, function (x) return x.id == mainPoi.id end) == 0 then
        table.insert(self.locations, mainPoi)
    end
end

function Template.Load(supertemplate, name)
    local file = fileOpen("files/supertemplates/"..supertemplate.."/"..name..".json") 
    if file then
        local jsonStr = fileRead(file, fileGetSize(file))
        local raw = fromJSON(jsonStr)
        fileClose(file)

        if not raw then
            outputChatBox("Something went wrong while loading the template from file")
            return nil
        end
        local template = Template(raw)
        if not template then
            outputChatBox("Something went wrong while deserializing the template")
            return nil
        else
            outputChatBox("Template "..template.name..' was successfully loaded')
            return template
        end
    end
    error("File path expected but got null")
    return nil
end