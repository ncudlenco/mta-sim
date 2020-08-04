Sink = class(SampStoryObjectBase, function(o, params)
    params.description = "sink"
    params.type = 'Sink'

    SampStoryObjectBase.init(o, params)
end
)

Sink.eModel = 
{
    bathroomSink01 = 2523,
}