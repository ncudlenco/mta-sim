Food = class(SampStoryObjectBase, function(o, params)
    params.description = "food"
    params.type = 'Food'

    if params.modelid == Food.eModel.Shawarma then
        params.position.z = params.position.z - 0.02
    elseif params.modelid == Food.eModel.Burger then
        params.rotation = Vector3(270, 0, 200)
    elseif params.modelid == Food.eModel.Pizza then
        params.rotation = Vector3(180, 90, 0)
        params.position.z = params.position.z - 0.06
    elseif (params.modelid == Food.eModel.RedApple or params.modelid == Food.eModel.GreenApple) then
        params.position.z = params.position.z - 0.02
    elseif params.modelid == Food.eModel.Cake then
        params.position.z = params.position.z - 0.05
    elseif params.modelid == Food.eModel.Banana then
        params.position.z = params.position.z - 0.03
    end

    SampStoryObjectBase.init(o, params)

    o:updateDescription()
end
)

function Food:updateDescription()
    local pluralSet = false
    if self.modelid == Food.eModel.Shawarma then
        self.Description = "shawarma"
    elseif self.modelid == Food.eModel.Burger then
        self.Description = "burger"
    elseif self.modelid == Food.eModel.Pizza then
        self.Description = "slice of pizza"
    elseif self.modelid == Food.eModel.RedApple then
        self.Description = "red apple"
        self.pluralTemplate = '{count} red apples'
        pluralSet = true
    elseif self.modelid == Food.eModel.GreenApple then
        self.Description = "green apple"
        self.pluralTemplate = '{count} green apples'
        pluralSet = true
    elseif self.modelid == Food.eModel.Cake then
        self.Description = "slice of cake"
    elseif self.modelid == Food.eModel.Banana then
        self.Description = "banana"
    end
    if not pluralSet then
        self:SetSimplePluralTemplate()
    end
    return self.Description
end

function Food:updatePositionOffsetSitDown()
    if self.modelid == Food.eModel.Shawarma then
        self.PosOffset = Vector3(-0.04, 0.05, 0.08)
    elseif self.modelid == Food.eModel.Burger then
        self.PosOffset = Vector3(-0.01, 0.09, 0.05)
    elseif self.modelid == Food.eModel.Pizza then
        self.PosOffset = Vector3(-0.05, 0.08, 0.12)
    elseif (self.modelid == Food.eModel.RedApple or self.modelid == Food.eModel.GreenApple) then
        self.PosOffset = Vector3(0, 0.04, 0.06)
    elseif self.modelid == Food.eModel.Cake then
        self.PosOffset = Vector3(-0.04, 0.07, 0.05)
    elseif self.modelid == Food.eModel.Banana then
        self.PosOffset = Vector3(-0.01, 0.04, 0.06)
    end

    return self.Description
end

function Food:updateRotOffsetSitDown()
    if self.modelid == Food.eModel.Shawarma then
        self.RotOffset = Vector3(270, 0, 0)
    elseif self.modelid == Food.eModel.Burger then
        self.RotOffset = Vector3(270, 0, 0)
    elseif self.modelid == Food.eModel.Pizza then
        self.RotOffset = Vector3(200, 0, 270)
    elseif (self.modelid == Food.eModel.RedApple or self.modelid == Food.eModel.GreenApple) then
        self.RotOffset = Vector3(0, 270, 0)
    elseif self.modelid == Food.eModel.Cake then
        self.RotOffset = Vector3(0, 90, 0)
    elseif self.modelid == Food.eModel.Banana then
        self.RotOffset = Vector3(0, 180, 0)
    end

    return self.Description
end

function Food:updatePositionOffsetStandUp()
    if self.modelid == Food.eModel.Shawarma then
        self.PosOffset = Vector3(-0.08, 0.02, 0.08)
    elseif self.modelid == Food.eModel.Burger then
        self.PosOffset = Vector3(-0.01, 0.08, 0.08)
    elseif self.modelid == Food.eModel.Pizza then
        self.PosOffset = Vector3(0, 0.1, 0.05)
    elseif (self.modelid == Food.eModel.RedApple or self.modelid == Food.eModel.GreenApple) then
        self.PosOffset = Vector3(0, 0.04, 0.06)
    elseif self.modelid == Food.eModel.Cake then
        self.PosOffset = Vector3(0, 0.07, 0.02)
    elseif self.modelid == Food.eModel.Banana then
        self.PosOffset = Vector3(0, 0.03, 0.01)
    end

    return self.Description
end

function Food:updateRotOffsetStandUp()
    if self.modelid == Food.eModel.Shawarma then
        self.RotOffset = Vector3(0, 0, 210)
    elseif self.modelid == Food.eModel.Burger then
        self.RotOffset = Vector3(270, 0, 0)
    elseif self.modelid == Food.eModel.Pizza then
        self.RotOffset = Vector3(180, 90, 180)
    elseif (self.modelid == Food.eModel.RedApple or self.modelid == Food.eModel.GreenApple) then
        self.RotOffset = Vector3(0, 0, 0)
    elseif self.modelid == Food.eModel.Cake then
        self.RotOffset = Vector3(0, 0, 0)
    elseif self.modelid == Food.eModel.Banana then
        self.RotOffset = Vector3(0, 270, 0)
    end

    return self.Description
end

function Food:removeZOffset()
    if self.modelid == Food.eModel.Shawarma then
        self.position.z = self.position.z + 0.02
    elseif self.modelid == Food.eModel.Burger then
        self.rotation = Vector3(270, 0, 200)
    elseif self.modelid == Food.eModel.Pizza then
        self.rotation = Vector3(180, 90, 0)
        self.position.z = self.position.z + 0.06
    elseif (self.modelid == Food.eModel.RedApple or self.modelid == Food.eModel.GreenApple) then
        self.position.z = self.position.z + 0.02
    elseif self.modelid == Food.eModel.Cake then
        self.position.z = self.position.z + 0.05
    elseif self.modelid == Food.eModel.Banana then
        self.position.z = self.position.z + 0.03
    end
end

Food.eModel = 
{
    Shawarma = 2769,
    Burger = 2703,
    Pizza = 2702,
    RedApple = 1252,
    GreenApple = 2036,
    Cake = 2040,
    Banana = 3082
}