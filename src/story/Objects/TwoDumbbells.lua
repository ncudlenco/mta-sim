TwoDumbbells = class(SampStoryObjectBase, function(o, params)
    params.description = "two dumbbells"
    params.type = 'TwoDumbbells'

    SampStoryObjectBase.init(o, params)
end
)

TwoDumbbells.eModel = {
    TwoDumbbells1 = 2915
}