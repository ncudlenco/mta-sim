ArmChair = class(SampStoryObjectBase, function(o, params)
    params.description = "armchair"
    params.type = 'ArmChair'

    SampStoryObjectBase.init(o, params)
end
)

ArmChair.eModel = {
    Couch01 = 1755,
}