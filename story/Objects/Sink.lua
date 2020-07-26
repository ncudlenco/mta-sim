Sink = class(SampStoryObjectBase, function(o, params)
    params.description = "sink"
    SampStoryObjectBase.init(o, params)
end
)

Sink.eModel = 
{
    bathroomSink01 = 2523,
}