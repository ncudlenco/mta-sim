SampStoryObjectBase = class(StoryObjectBase, function(o, params)
    StoryObjectBase.init(o, params.description)
    o.modelid = params.modelid
    o.position = params.position
    o.rotation = params.rotation
    o.noCollisions = params.noCollisions or false
    o.interior = params.interior or 0
    o.instance = nil
    o.size = params.size or 2.5
end)

function SampStoryObjectBase:Create(...)
    self.instance = Object(self.modelid, self.position, self.rotation, self.noCollisions)
    self.instance:setInterior(self.interior)
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