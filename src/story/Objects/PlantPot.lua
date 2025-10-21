PlantPot = class(SampStoryObjectBase, function(o, params)
    params.description = "plant in a pot"
    params.type = 'PlantPot'

    SampStoryObjectBase.init(o, params)
end
)

PlantPot.eModel = 
{
    PlantPot01 = 2241,
    PlantPot02 = 2811,
    PlantPot03 = 2251,
    PlantPot04 = 2195,
    PlantPot05 = 2240,
    PlantPot06 = 2001,
    PlantPot07 = 949,
    PlantPot08 = 630
}