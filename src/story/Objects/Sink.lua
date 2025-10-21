Sink = class(SampStoryObjectBase, function(o, params)
    params.description = "sink"
    params.type = 'Sink'

    SampStoryObjectBase.init(o, params)
end
)

Sink.eModel =
{
    bathroomSink01 = 2523,
    bathroomSink02 = 2515,
    bathroomSink03 = 2518,
    bathroomSink04 = 2524,
    bathroomSink05 = 2739,
}