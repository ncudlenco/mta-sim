GymBike = class(SampStoryObjectBase, function(o, params)
    params.description = "gym bike"
    params.pluralTemplate = '{count} gym bikes'
    params.type = 'GymBike'

    SampStoryObjectBase.init(o, params)
end
)

GymBike.eModel = {
    GymBike = 2630
}