SampStoryObjectBase = class(StoryObjectBase, function(o, params)
    params.description = params.description or ''
    StoryObjectBase.init(o, params.description)
    o.type = params.type or 'SampStoryObjectBase'
    o.modelid = params.modelid
    o.position = Vector3(params.position)
    o.rotation = Vector3(params.rotation)
    o.noCollisions = params.noCollisions or false
    o.interior = params.interior or 0
    o.instance = nil
    o.size = params.size or 2.5
    o.scale = params.scale or 1
    o.PosOffset = params.posOffset or params.PosOffset or Vector3(0,0,0)
    o.RotOffset = params.rotOffset or params.RotOffset or Vector3(0,0,0)
    o.Region = {}
    if not params.pluralTemplate and params.description and params.description ~= '' then
        o:SetSimplePluralTemplate()
    else
        o.pluralTemplate = params.pluralTemplate or ''
    end
    local noCollisionStr = 'false'
    if o.noCollisions then
        noCollisionStr = 'true'
    end

    o.isRandomModelId = params.isRandomModelId or false

    if params.noRandomId ~= true then

        if o.modelid == nil or o.modelid < 0 then
            o.isRandomModelId = true
        end

        if o.isRandomModelId then
            math.randomseed(os.clock()*100000000000)
            math.random(); math.random(); math.random()
            math.randomseed(os.clock()*100000000000)
            math.random(); math.random(); math.random()

            o.modelid = loadstring('return '..o.type..'.eModel[PickRandom('..o.type..'.eModel)]')()
        end
    end

    print("Object "..o.type)
    o.dynamicString = 'return '..o.type..'{description="'..params.description..'", noCollisions='..noCollisionStr..', modelid='..o.modelid..', isRandomModelId='..tostring(params.isRandomModelId)..', noRandomId=true' .. ', interior='..params.interior..', position=Vector3('..params.position.x..','..params.position.y..','..params.position.z..'), rotation=Vector3('..params.rotation.x..','..params.rotation.y..','..params.rotation.z..'), posOffset=Vector3('..o.PosOffset.x..','..o.PosOffset.y..','..o.PosOffset.z..'), rotOffset=Vector3('..o.RotOffset.x..','..o.RotOffset.y..','..o.RotOffset.z..')}'
    if DEBUG_OBJECTS then
        print("\nObject: Creating object class - " .. o.dynamicString .. "\n")
    end

end)

function SampStoryObjectBase:SetSimplePluralTemplate()
    local words = {}
    words[1], words[2] = self.Description:match("(%w+) (.+)")
    if not words[1] then
        words[1] = self.Description
        words[2] = ''
    end
    self.pluralTemplate = '{count} ' ..  words[1] .. 's' .. words[2]
end

function SampStoryObjectBase:__tostring()
    local noCollisionsStr = 'false'
    if self.noCollisions then
        noCollisions = 'true'
    end
    local instance = 'none'
    if self.instance then
        instance = 'instantiated'
    end
    return "\n{\n"..
        "\tDescription = ".. self.Description ..
        "\t type = ".. self.type ..
        "\t modelid = ".. self.modelid ..
        "\t isRandomModelId=".. tostring(self.isRandomModelId)..
        "\t position = ".. Vector3.__tostring(self.position) ..
        "\t rotation = ".. Vector3.__tostring(self.rotation) ..
        "\t noCollisions = ".. noCollisionsStr ..
        "\t instance = ".. instance ..
        "\t interior = ".. self.interior ..
        "\t size = ".. self.size ..
        "\t scale = ".. self.scale ..
        "\t dynamicString = ".. self.dynamicString ..
        "\t modelid = ".. self.modelid
    .."\n}"
  end

function SampStoryObjectBase:UpdateData(unpack)
    if self.instance then
        if self.modelid then
            self.modelid = self.instance.model
        end
        self.position = self.instance.position
        self.rotation = self.instance.rotation
        self.interior = self.instance.interior
    end
    if unpack then
        if self.position and self.position.unpack then
            self.position = self.position:unpack()
        end
        if self.rotation and self.rotation.unpack then
            self.rotation = self.rotation:unpack()
        end
        if self.PosOffset and self.PosOffset.unpack then
            self.PosOffset = self.PosOffset:unpack()
        end
        if self.RotOffset and self.RotOffset.unpack then
            self.RotOffset = self.RotOffset:unpack()
        end
    end
    local noCollisionStr = 'false'
    if self.noCollisions then
        noCollisionStr = 'true'
    end
    local modelid = self.modelid
    if self.isRandomModelId then
        modelid = self.type..'.eModel[PickRandom('..self.type..'.eModel)]'
    end
    self.metadata = {}
    self.dynamicString = 'return '..self.type..'{description="'..self.Description..'", noCollisions='..noCollisionStr..', modelid='..(modelid or 'nil')..', isRandomModelId='.. tostring(self.isRandomModelId) .. ', interior='..self.interior..', position=Vector3('..self.position.x..','..self.position.y..','..self.position.z..'), rotation=Vector3('..self.rotation.x..','..self.rotation.y..','..self.rotation.z..'), posOffset=Vector3('..self.PosOffset.x..','..self.PosOffset.y..','..self.PosOffset.z..'), rotOffset=Vector3('..self.RotOffset.x..','..self.RotOffset.y..','..self.RotOffset.z..')}'
end

SampStoryObjectBase.eModel = {None = -1}

function SampStoryObjectBase:setData(key, value)
    if self.instance then
        self.instance:setData(key, value)
    else
        self.metadata[key] = value
    end
end

function SampStoryObjectBase:getData(key)
    if self.instance then
        return self.instance:getData(key)
    else
        return self.metadata[key]
    end
    return nil
end

function SampStoryObjectBase:Create(...)
    self.instance = Object(self.modelid, self.position, self.rotation, self.noCollisions)
    self.instance:setInterior(self.interior)

    setObjectScale(self.instance, self.scale)
end

function SampStoryObjectBase:Destroy(...)
    if self.instance then
        self.instance:destroy()
    end
end

function SampStoryObjectBase:ChangeModel(newModelid)
    self:Destroy()
    self.modelid = newModelid
    if self.instance ~= nil then
        self:Create()
    end
    if self.updateDescription then
        self:updateDescription()
    end
end

function SampStoryObjectBase:Destroy()
    if isElement(self.instance) then
        self.instance:setInterior(0)
        self.instance:destroy()
    end
end