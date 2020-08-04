Cigarette = class(SampStoryObjectBase, function(o, params)
    params.description = "a cigarette"
    params.type = 'Cigarette'

    SampStoryObjectBase.init(o, params)

    o:updatePositionOffsetStandUp()
    o:updateRotOffsetStandUp()
end
)

function Cigarette:updatePositionOffsetStandUp()
    if self.modelid == Cigarette.eModel.Cigarette1 then
        self.PosOffset = Vector3(-0.02, 0.05, 0.1)
    end

    return self.Description
end

function Cigarette:updateRotOffsetStandUp()
    if self.modelid == Cigarette.eModel.Cigarette1 then
        self.RotOffset = Vector3(0, 90, 0)
    end

    return self.Description
end

Cigarette.eModel = 
{
    Cigarette1 = 3027
}