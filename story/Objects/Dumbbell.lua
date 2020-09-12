Dumbbell = class(SampStoryObjectBase, function(o, params)
    params.description = "dumbbell"
    params.type = 'Dumbbell'

    SampStoryObjectBase.init(o, params)
    o:updatePositionOffset()
    o:updateRotOffset()
end
)

function Dumbbell:updatePositionOffset()
    if self.modelid == Dumbbell.eModel.Dumbbell1 then
        self.PosOffset = Vector3(0, 0, 0)
    end
    return self.Description
end

function Dumbbell:updateRotOffset()
    if self.modelid == Dumbbell.eModel.Dumbbell1 then
        self.RotOffset = Vector3(0, 0, 0)
    end
    return self.Description
end

Dumbbell.eModel = 
{
    Dumbbell1 = 2916
}
