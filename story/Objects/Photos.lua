Photos = class(SampStoryObjectBase, function(o, params)
    params.description = "photos"
    SampStoryObjectBase.init(o, params)
end
)

Photos.eModel = 
{
    Unknown1 = 2603,
}