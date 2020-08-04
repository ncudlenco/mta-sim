Remote = class(SampStoryObjectBase, function(o, params)
    params.description = "remote"
    params.type = 'Remote'

    SampStoryObjectBase.init(o, params)
    o:updatePositionOffset()
    o:updateRotOffset()
end
)

function Remote:updatePositionOffset()
    if self.modelid == Remote.eModel.Remote1 then
        self.PosOffset = Vector3(-0.02, 0.015, 0.15)
    end
    return self.Description
end

function Remote:updateRotOffset()
    if self.modelid == Remote.eModel.Remote1 then
        self.RotOffset = Vector3(270, 0, 0)
    end
    return self.Description
end

Remote.eModel = 
{
    Remote1 = 2344
}