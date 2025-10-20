Basketball = class(SampStoryObjectBase, function(o, params)
    params.description = "basketball"
    params.type = 'Basketball'
    SampStoryObjectBase.init(o, params)
end
)

Basketball.eModel = 
{
    Basketball01 = 2114,
    Basketball02 = 3065,
    -- Basketball03 = 14866, -> too big and scale is not working
}