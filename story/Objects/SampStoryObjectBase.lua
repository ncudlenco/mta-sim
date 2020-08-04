SampStoryObjectBase = class(StoryObjectBase, function(o, params)
    params.description = params.description or ''
    StoryObjectBase.init(o, params.description)
    o.type = params.type or 'SampStoryObjectBase'
    o.modelid = params.modelid
    o.position = params.position
    o.rotation = params.rotation
    o.noCollisions = params.noCollisions or false
    o.interior = params.interior or 0
    o.instance = nil
    o.size = params.size or 2.5
    o.scale = params.scale or 1
    local noCollisionStr = 'false'
    if o.noCollisions then
        noCollisionStr = 'true'
    end
    o.dynamicString = 'return '..o.type..'{description="'..params.description..'", noCollisions='..noCollisionStr..', modelid='..(params.modelid or o.type..'.eModel[PickRandom('..o.type..'.eModel)]')..', interior='..params.interior..', position=Vector3('..params.position.x..','..params.position.y..','..params.position.z..'), rotation=Vector3('..params.rotation.x..','..params.rotation.y..','..params.rotation.z..')}'
    if o.modelid == nil or o.modelid < 0 then
        o.modelid = loadstring('return '..o.type..'.eModel[PickRandom('..o.type..'.eModel)]')()
    end
    local modelid = o.modelid
    local type = o.type
    local i = 5
end)

function StoryActionBase:__tostring()
    return "{\n"..
        "\tDescription = ".. self.Description ..
        "\tStoryItemType = ".. self.StoryItemType ..
        "\t type = ".. self.type ..
        "\t modelid = ".. self.modelid ..
        "\t position = ".. self.position ..
        "\t rotation = ".. self.rotation ..
        "\t noCollisions = ".. self.noCollisions ..
        "\t interior = ".. self.interior ..
        "\t instance = ".. self.instance ..
        "\t size = ".. self.size ..
        "\t scale = ".. self.scale ..
        "\t dynamicString = ".. self.dynamicString ..
        "\t modelid = ".. self.modelid
    .."\n}"
  end

function SampStoryObjectBase:UpdateData(unpack)
    if not self.instance then
        return nil
    end
    if self.modelid then
        self.modelid = self.instance.modelid
    end
    if unpack then
        self.position = self.instance.position:unpack()
        self.rotation = self.instance.rotation:unpack()        
    else
        self.position = self.instance.position
        self.rotation = self.instance.rotation
    end
    self.interior = self.instance.interior
    o.dynamicString = 'return '..o.type..'{description="'..self.description..'", modelid='..(self.modelid or 'nil')..', interior='..self.interior..', position=Vector3('..self.position.x..','..self.position.y..','..self.position.z..'), rotation=Vector3('..self.rotation.x..','..self.rotation.y..','..self.rotation.z..')}'
end

SampStoryObjectBase.eModel = {None = -1}

function SampStoryObjectBase:Create(...)
    self.instance = Object(self.modelid, self.position, self.rotation, self.noCollisions)
    self.instance:setInterior(self.interior)
    setObjectScale(self.instance, self.scale)
end

function SampStoryObjectBase:Destroy(...)
    if self.instance ~= nil then
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