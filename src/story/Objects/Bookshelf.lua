Bookshelf = class(SampStoryObjectBase, function(o, params)
    params.description = "bookshelf"
    params.type = 'Bookshelf'

    SampStoryObjectBase.init(o, params)
end
)

Bookshelf.eModel = 
{
    Unknown01 = 1742
}