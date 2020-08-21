Drinks = class(SampStoryObjectBase, function(o, params)
    params.description = "drink"
    params.type = 'Drinks'

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
    elseif params.modelid == Drinks.eModel.BottleWine1 then
        params.position.z = params.position.z + 0.1
    elseif params.modelid == Drinks.eModel.GlassBeer then
        params.position.z = params.position.z + 0.05
    elseif params.modelid == Drinks.eModel.GlassAlcohol then
        params.position.z = params.position.z + 0.05
    elseif params.modelid == Drinks.eModel.GlassWine1 then
        params.position.z = params.position.z + 0.07
    elseif params.modelid == Drinks.eModel.BottleVodka1 then
        params.position.z = params.position.z + 0.13
    elseif params.modelid == Drinks.eModel.BottleBeer1 or params.modelid == Drinks.eModel.BottleBeer2 then
        params.position.z = params.position.z + 0.1
        params.scale = 0.7
    elseif params.modelid == Drinks.eModel.BottleWine2 then
        params.position.z = params.position.z -0.02
        params.scale = 0.7
    elseif params.modelid == Drinks.eModel.BottleWine3 then
        params.position.z = params.position.z -0.02
        params.scale = 0.7
    elseif params.modelid == Drinks.eModel.BottleVodka2 then
        params.position.z = params.position.z -0.02
        params.scale = 0.7
    elseif params.modelid == Drinks.eModel.BottleAlcohol5 then
        params.position.z = params.position.z -0.02
        params.scale = 0.8
    elseif params.modelid == Drinks.eModel.BottleWine4 then
        params.position.z = params.position.z -0.03
        params.scale = 0.7
    elseif params.modelid == Drinks.eModel.GlassWine2 then
        params.position.z = params.position.z + 0.03
        params.scale = 0.8
    elseif params.modelid == Drinks.eModel.GlassWine3 then
        params.position.z = params.position.z + 0.03
        params.scale = 0.8
    end

    SampStoryObjectBase.init(o, params)

    o:updateDescription()
end
)

function Drinks:updateDescription()
    if self.modelid == Drinks.eModel.AppleJuice then
        self.Description2 = "green apple juice"
        self.Description = "carton of apple juice"
    elseif self.modelid == Drinks.eModel.OrangeJuice then
        self.Description2 = "orange juice from it"
        self.Description = "carton of orange juice"
    elseif self.modelid == Drinks.eModel.MilkCarton then
        self.Description2 = "milk from it"
        self.Description = "carton of milk"
    elseif self.modelid == Drinks.eModel.CoffeCup then
        self.Description2 = "cup of coffe"
        self.Description = "cup of coffe"
    elseif self.modelid == Drinks.eModel.SodaCup1 or self.modelid == Drinks.eModel.SodaCup2 then
        self.Description2 = "cup of soda"
        self.Description = "cup of soda"
    elseif self.modelid == Drinks.eModel.MilkBottle then
        self.Description2 = "milk from it"
        self.Description = "bottle of milk"
    elseif self.modelid == Drinks.eModel.BottleAlcohol1 or self.modelid == Drinks.eModel.BottleAlcohol2 or 
           self.modelid == Drinks.eModel.BottleAlcohol3 or self.modelid == Drinks.eModel.BottleAlcohol4 or
           self.modelid == Drinks.eModel.BottleAlcohol5 then
        self.Description2 = "alcohol from it"
        self.Description = "bottle of alcohol"
    elseif self.modelid == Drinks.eModel.BottleCider1 or self.modelid == Drinks.eModel.BottleCider2 then
        self.Description2 = "cider from it"
        self.Description = "bottle of cider"
    elseif self.modelid == Drinks.eModel.BottleWine1 or self.modelid == Drinks.eModel.BottleWine2 or 
           self.modelid == Drinks.eModel.BottleWine3 or self.modelid == Drinks.eModel.BottleWine4 then
        self.Description2 = "wine from it"
        self.Description = "bottle of wine"
    elseif self.modelid == Drinks.eModel.GlassBeer then
        self.Description2 = "beer from it"
        self.Description = "glass of beer"
    elseif self.modelid == Drinks.eModel.GlassAlcohol then
        self.Description2 = "alcohol from it"
        self.Description = "glass of alcohol"
    elseif self.modelid == Drinks.eModel.GlassWine1 or self.modelid == Drinks.eModel.GlassWine2 or self.modelid == Drinks.eModel.GlassWine3 then
        self.Description2 = "wine from it"
        self.Description = "glass of wine"
    elseif self.modelid == Drinks.eModel.BottleVodka1 or self.modelid == Drinks.eModel.BottleVodka2 then
        self.Description2 = "vodka from it"
        self.Description = "bottle of vodka"
    elseif self.modelid == Drinks.eModel.BottleBeer1 or self.modelid == Drinks.eModel.BottleBeer2 then
        self.Description2 = "beer from it"
        self.Description = "bottle of beer"
    end

    return self.Description
end

function Drinks:updatePositionOffsetStandUp()
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
    elseif self.modelid == Drinks.eModel.BottleWine1 then
        self.PosOffset = Vector3(-0.05, 0.03, 0.08)
    elseif self.modelid == Drinks.eModel.BottleWine2 then
        self.PosOffset = Vector3(-0.32, 0.03, 0.08)
    elseif self.modelid == Drinks.eModel.BottleWine3 then
        self.PosOffset = Vector3(-0.26, 0.03, 0.08)
    elseif self.modelid == Drinks.eModel.BottleWine4 then
        self.PosOffset = Vector3(-0.26, 0.03, 0.08)
    elseif self.modelid == Drinks.eModel.GlassBeer then
        self.PosOffset = Vector3(0, 0.03, 0.08)
    elseif self.modelid == Drinks.eModel.GlassAlcohol then
        self.PosOffset = Vector3(0, 0.03, 0.08)
    elseif self.modelid == Drinks.eModel.GlassWine1 then
        self.PosOffset = Vector3(0, 0.03, 0.08)
    elseif self.modelid == Drinks.eModel.GlassWine2 then
        self.PosOffset = Vector3(-0.1, 0.03, 0.08)
    elseif self.modelid == Drinks.eModel.GlassWine3 then
        self.PosOffset = Vector3(-0.05, 0.03, 0.08)
    elseif self.modelid == Drinks.eModel.BottleVodka1 then
        self.PosOffset = Vector3(-0.08, 0.03, 0.08)
    elseif self.modelid == Drinks.eModel.BottleVodka2 then
        self.PosOffset = Vector3(-0.32, 0.03, 0.08)
    elseif self.modelid == Drinks.eModel.BottleAlcohol5 then
        self.PosOffset = Vector3(-0.20, 0.03, 0.08)
    elseif self.modelid == Drinks.eModel.BottleBeer1 or self.modelid == Drinks.eModel.BottleBeer2 then
        self.PosOffset = Vector3(-0.03, 0.03, 0.08)
    end

    return self.Description
end

function Drinks:updateRotOffsetStandUp()
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
    BottleAlcohol5 = 1247,
    BottleCider1 = 1543,
    BottleCider2 = 1544,
    BottleWine1 = 1664,
    BottleWine2 = 1239,
    BottleWine3 = 1241,
    BottleWine4 = 1254,
    GlassBeer = 1666,
    GlassAlcohol = 1455,
    GlassWine1 = 1667,
    GlassWine2 = 1253,
    GlassWine3 = 1248,
    BottleVodka1 = 1668,
    BottleVodka2 = 1240,
    BottleBeer1 = 1950,
    BottleBeer2 = 1951,
}