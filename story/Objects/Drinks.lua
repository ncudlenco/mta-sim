Drinks = class(SampStoryObjectBase, function(o, params)
    params.description = "drink"

    if ( params.modelid == Drinks.eModel.AppleJuice or params.modelid == Drinks.eModel.OrangeJuice or 
         params.modelid == Drinks.eModel.MilkCarton or params.modelid == Drinks.eModel.MilkBottle) then
        params.position.z = params.position.z - 0.02
    elseif params.modelid == Drinks.eModel.CoffeCup or params.modelid == Drinks.eModel.SodaCup2 then
        params.position.z = params.position.z + 0.04
    elseif params.modelid == Drinks.eModel.SodaCup1 then
        params.position.z = params.position.z + 0.05
        params.scale = 0.6
    elseif params.modelid == Drinks.eModel.BottleAlcohol1 then
        params.position.z = params.position.z + 0.1
    elseif params.modelid == Drinks.eModel.BottleAlcohol2 or params.modelid == Drinks.eModel.BottleAlcohol3 then
        params.position.z = params.position.z + 0.15
    elseif params.modelid == Drinks.eModel.BottleCider1 or params.modelid == Drinks.eModel.BottleCider2 then
        params.position.z = params.position.z - 0.03
    elseif params.modelid == Drinks.eModel.BottleWine then
        params.position.z = params.position.z + 0.1
    elseif params.modelid == Drinks.eModel.GlassBeer then
        params.position.z = params.position.z + 0.05
    elseif params.modelid == Drinks.eModel.GlassWine then
        params.position.z = params.position.z + 0.07
    elseif params.modelid == Drinks.eModel.BottleVodka then
        params.position.z = params.position.z + 0.13
    elseif params.modelid == Drinks.eModel.BottleBeer1 or params.modelid == Drinks.eModel.BottleBeer2 then
        params.position.z = params.position.z + 0.1
        params.scale = 0.7
    end

    SampStoryObjectBase.init(o, params)

    o:updateDescription()
    o:updatePositionOffset()
    o:updateRotOffset()
end
)

function Drinks:updateDescription()
    if self.modelid == Drinks.eModel.AppleJuice then
        self.Description = "green apple juice from carton"
    elseif self.modelid == Drinks.eModel.OrangeJuice then
        self.Description = "orange juice from carton"
    elseif self.modelid == Drinks.eModel.MilkCarton then
        self.Description = "milk from carton"
    elseif self.modelid == Drinks.eModel.CoffeCup then
        self.Description = "a cup of coffe"
    elseif self.modelid == Drinks.eModel.SodaCup1 or self.modelid == Drinks.eModel.SodaCup2 then
        self.Description = "a cup of soda"
    elseif self.modelid == Drinks.eModel.MilkBottle then
        self.Description = "milk from a bottle"
    elseif self.modelid == Drinks.eModel.BottleAlcohol1 or self.modelid == Drinks.eModel.BottleAlcohol2 or 
           self.modelid == Drinks.eModel.BottleAlcohol3 or self.modelid == Drinks.eModel.BottleAlcohol4 then
        self.Description = "alcohol from a bottle"
    elseif self.modelid == Drinks.eModel.BottleCider1 or self.modelid == Drinks.eModel.BottleCider2 then
        self.Description = "cider from a bottle"
    elseif self.modelid == Drinks.eModel.BottleWine then
        self.Description = "wine from a bottle"
    elseif self.modelid == Drinks.eModel.GlassBeer then
        self.Description = "beer from a glass"
    elseif self.modelid == Drinks.eModel.GlassWine then
        self.Description = "wine from a glass"
    elseif self.modelid == Drinks.eModel.BottleVodka then
        self.Description = "vodka from a bottle"
    elseif self.modelid == Drinks.eModel.BottleBeer1 or self.modelid == Drinks.eModel.BottleBeer2 then
        self.Description = "beer from a bottle"
    end

    return self.Description
end

function Drinks:updatePositionOffset()
    if (self.modelid == Drinks.eModel.AppleJuice or self.modelid == Drinks.eModel.OrangeJuice or 
        self.modelid == Drinks.eModel.MilkCarton) then
        self.PosOffset = Vector3(-0.15, 0.09, 0.11)
    elseif (self.modelid == Drinks.eModel.CoffeCup) then
        self.PosOffset = Vector3(0, 0.07, 0.09)
    elseif self.modelid == Drinks.eModel.SodaCup1 then
        self.PosOffset = Vector3(0, 0.03, 0.09)
    elseif self.modelid == Drinks.eModel.MilkBottle then
        self.PosOffset = Vector3(-0.20, 0.09, 0.11)
    elseif self.modelid == Drinks.eModel.BottleAlcohol1 or self.modelid == Drinks.eModel.BottleAlcohol2 or 
           self.modelid == Drinks.eModel.BottleAlcohol3 then
        self.PosOffset = Vector3(-0.04, 0.03, 0.08)
    elseif self.modelid == Drinks.eModel.BottleAlcohol4 then
        self.PosOffset = Vector3(-0.23, 0.03, 0.08)
    elseif self.modelid == Drinks.eModel.BottleCider1 or self.modelid == Drinks.eModel.BottleCider2 then
        self.PosOffset = Vector3(-0.25, 0.03, 0.08)
    elseif self.modelid == Drinks.eModel.SodaCup2 then
        self.PosOffset = Vector3(0, 0.07, 0.09)
    elseif self.modelid == Drinks.eModel.BottleWine then
        self.PosOffset = Vector3(-0.05, 0.03, 0.08)
    elseif self.modelid == Drinks.eModel.GlassBeer then
        self.PosOffset = Vector3(0, 0.03, 0.08)
    elseif self.modelid == Drinks.eModel.GlassWine then
        self.PosOffset = Vector3(0, 0.03, 0.08)
    elseif self.modelid == Drinks.eModel.BottleVodka then
        self.PosOffset = Vector3(-0.08, 0.03, 0.08)
    elseif self.modelid == Drinks.eModel.BottleBeer1 or self.modelid == Drinks.eModel.BottleBeer2 then
        self.PosOffset = Vector3(-0.03, 0.03, 0.08)
    end

    return self.Description
end

function Drinks:updateRotOffset()
    --if (self.modelid == Drinks.eModel.AppleJuice or self.modelid == Drinks.eModel.OrangeJuice or 
     --   self.modelid == Drinks.eModel.MilkCarton or self.modelid == Drinks.eModel.MilkBottle)  then
      --  self.RotOffset = Vector3(0, 90, 0)
  --  elseif (self.modelid == Drinks.eModel.CoffeCup or self.modelid == Drinks.eModel.SodaCup) then
   --     self.RotOffset = Vector3(0, 90, 0)
    --elseif self.modelid == Drinks.eModel.BottleAlcohol1 or self.modelid == Drinks.eModel.BottleAlcohol2 or 
       --    self.modelid == Drinks.eModel.BottleAlcohol3 or self.modelid == Drinks.eModel.BottleAlcohol4 or
       --    self then
       -- self.RotOffset = Vector3(0, 90, 0)
    --end
    self.RotOffset = Vector3(0, 90, 0)

    return self.Description
end

Drinks.eModel = 
{
    AppleJuice = 3113,
    OrangeJuice = 3788,
    MilkCarton = 3789,
    CoffeCup = 3013,
    SodaCup1 = 2647,
    SodaCup2 = 1546,
    MilkBottle = 3016,
    BottleAlcohol1 = 1486,
    BottleAlcohol2 = 1512,
    BottleAlcohol3 = 1517,
    BottleAlcohol4 = 1520,
    BottleCider1 = 1543,
    BottleCider2 = 1544,
    BottleWine = 1664,
    GlassBeer = 1666,
    GlassWine = 1667,
    BottleVodka = 1668,
    BottleBeer1 = 1950,
    BottleBeer2 = 1951
}