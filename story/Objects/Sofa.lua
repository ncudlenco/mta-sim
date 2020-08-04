Sofa = class(SampStoryObjectBase, function(o, params)
    params.description = "sofa"
    params.type = 'Sofa'

    SampStoryObjectBase.init(o, params)
end
)

Sofa.eModel = {
    Couch01 = 1760,
    Couch02 = 1703,
}