OfficeChair = class(SampStoryObjectBase, function(o, params)
    params.description = "office chair"
    params.type = 'OfficeChair'

    SampStoryObjectBase.init(o, params)
end
)

OfficeChair.eModel = 
{
    Unknown01 = 1714
}