Food = class(SampStoryObjectBase, function(o, params)
    params.description = "food"
    SampStoryObjectBase.init(o, params)
    o:updateDescription()
    o:updatePositionOffset()
    o:updateRotOffset()
end
)

function Food:updateDescription()
    if self.modelid == Food.eModel.Shawarma then
        self.Description = "a shawarma"
    elseif self.modelid == Food.eModel.Burger then
        self.Description = "a burger"
    end
    return self.Description
end

function Food:updatePositionOffset()
    if self.modelid == Food.eModel.Shawarma then
        self.PosOffset = Vector3(-0.02, 0.05, 0.08)
    elseif self.modelid == Food.eModel.Burger then
        self.PosOffset = Vector3(-0.01, 0.09, 0.05)
    end
    return self.Description
end

function Food:updateRotOffset()
    if self.modelid == Food.eModel.Shawarma then
        self.RotOffset = Vector3(90, 0, 0)
    elseif self.modelid == Food.eModel.Burger then
        self.RotOffset = Vector3(90, 0, 0)
    end
    return self.Description
end

Food.eModel = 
{
    Shawarma = 2769,
    Burger = 2703
}