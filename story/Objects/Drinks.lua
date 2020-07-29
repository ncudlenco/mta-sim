Drinks = class(SampStoryObjectBase, function(o, params)
    params.description = "drink"

    if ( params.modelid == Drinks.eModel.AppleJuice or params.modelid == Drinks.eModel.OrangeJuice) then
        params.position.z = params.position.z - 0.02
    end

    SampStoryObjectBase.init(o, params)

    o:updateDescription()
    o:updatePositionOffset()
    o:updateRotOffset()
end
)

function Drinks:updateDescription()
    if self.modelid == Drinks.eModel.AppleJuice then
        self.Description = "green apple juice"
    elseif self.modelid == Drinks.eModel.OrangeJuice then
        self.Description = "orange juice"
    end

    return self.Description
end

function Drinks:updatePositionOffset()
    if (self.modelid == Drinks.eModel.AppleJuice or self.modelid == Drinks.eModel.OrangeJuice) then
        self.PosOffset = Vector3(-0.15, 0.09, 0.11)
    end

    return self.Description
end

function Drinks:updateRotOffset()
    if (self.modelid == Drinks.eModel.AppleJuice or self.modelid == Drinks.eModel.OrangeJuice)  then
        self.RotOffset = Vector3(0, 90, 0)
    end

    return self.Description
end

Drinks.eModel = 
{
    AppleJuice = 3113,
    OrangeJuice = 3788
}