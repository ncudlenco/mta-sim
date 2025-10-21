CommonInterior = class(SampStoryObjectBase, function(o, params)
    params.description = PickRandom({"object", "item"})
    params.type = 'CommonInterior'

    SampStoryObjectBase.init(o, params)
end
)

CommonInterior.eModel = {
    Set01 = 14509
}