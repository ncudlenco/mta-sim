Book = class(SampStoryObjectBase, function(o, params)
    params.description = "a book"
    params.type = 'Book'
    
    if params.eModel == Book.eModel.Book1 then
        params.scale = 0.8
    end

    SampStoryObjectBase.init(o, params)
end
)

Book.eModel = 
{
    Book1 = 2894
}