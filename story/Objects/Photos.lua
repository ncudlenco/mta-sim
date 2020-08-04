Photos = class(SampStoryObjectBase, function(o, params)
    params.description = "photos"
    params.type = 'Photos'

    SampStoryObjectBase.init(o, params)
end
)

Photos.eModel = 
{
    Unknown1 = 2603,
}