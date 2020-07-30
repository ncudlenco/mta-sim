Drinks = class(SampStoryObjectBase, function(o, params)
    params.description = "drink"

    if ( params.modelid == Drinks.eModel.AppleJuice or params.modelid == Drinks.eModel.OrangeJuice or 
         params.modelid == Drinks.eModel.MilkCarton or params.modelid == Drinks.eModel.MilkBottle) then
        params.position.z = params.position.z - 0.02
    elseif params.modelid == Drinks.eModel.CoffeCup then
        params.position.z = params.position.z + 0.04
    elseif params.modelid == Drinks.eModel.SodaCup then
        params.position.z = params.position.z + 0.08
    elseif params.modelid == Drinks.eModel.BottleAlcohol1 then
        params.position.z = params.position.z + 0.1
    elseif params.modelid == Drinks.eModel.BottleAlcohol2 or params.modelid == Drinks.eModel.BottleAlcohol3 then
        params.position.z = params.position.z + 0.15
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
    elseif self.modelid == Drinks.eModel.MilkCarton then
        self.Description = "milk from carton"
    elseif self.modelid == Drinks.eModel.CoffeCup then
        self.Description = "a cup of coffe"
    elseif self.modelid == Drinks.eModel.SodaCup then
        self.Description = "a cup of soda"
    elseif self.modelid == Drinks.eModel.MilkBottle then
        self.Description = "milk from bottle"
    elseif self.modelid == Drinks.eModel.BottleAlcohol1 or self.modelid == Drinks.eModel.BottleAlcohol2 or 
           self.modelid == Drinks.eModel.BottleAlcohol3 or self.modelid == Drinks.eModel.BottleAlcohol4 then
        self.Description = "alcohol from bottle"
    end

    return self.Description
end

function Drinks:updatePositionOffset()
    if (self.modelid == Drinks.eModel.AppleJuice or self.modelid == Drinks.eModel.OrangeJuice or 
        self.modelid == Drinks.eModel.MilkCarton) then
        self.PosOffset = Vector3(-0.15, 0.09, 0.11)
    elseif (self.modelid == Drinks.eModel.CoffeCup) then
        self.PosOffset = Vector3(0, 0.07, 0.09)
    elseif self.modelid == Drinks.eModel.SodaCup then
        self.PosOffset = Vector3(-0.06, 0.07, 0.09)
    elseif self.modelid == Drinks.eModel.MilkBottle then
        self.PosOffset = Vector3(-0.20, 0.09, 0.11)
    elseif self.modelid == Drinks.eModel.BottleAlcohol1 or self.modelid == Drinks.eModel.BottleAlcohol2 or 
           self.modelid == Drinks.eModel.BottleAlcohol3 then
        self.PosOffset = Vector3(-0.04, 0.03, 0.08)
    elseif self.modelid == Drinks.eModel.BottleAlcohol4 then
        self.PosOffset = Vector3(-0.23, 0.03, 0.08)
    end

    return self.Description
end

function Drinks:updateRotOffset()
    if (self.modelid == Drinks.eModel.AppleJuice or self.modelid == Drinks.eModel.OrangeJuice or 
        self.modelid == Drinks.eModel.MilkCarton or self.modelid == Drinks.eModel.MilkBottle)  then
        self.RotOffset = Vector3(0, 90, 0)
    elseif (self.modelid == Drinks.eModel.CoffeCup or self.modelid == Drinks.eModel.SodaCup) then
        self.RotOffset = Vector3(0, 90, 0)
    elseif self.modelid == Drinks.eModel.BottleAlcohol1 or self.modelid == Drinks.eModel.BottleAlcohol2 or 
           self.modelid == Drinks.eModel.BottleAlcohol3 or self.modelid == Drinks.eModel.BottleAlcohol4 then
        self.RotOffset = Vector3(0, 90, 0)
    end

    return self.Description
end

Drinks.eModel = 
{
    AppleJuice = 3113,
    OrangeJuice = 3788,
    MilkCarton = 3789,
    CoffeCup = 3013,
    SodaCup = 2647,
    MilkBottle = 3016,
    BottleAlcohol1 = 1486,
    BottleAlcohol2 = 1512,
    BottleAlcohol3 = 1517,
    BottleAlcohol4 = 1520
}