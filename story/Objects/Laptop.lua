Laptop = class(SampStoryObjectBase, function(o, params)
    params.description = "laptop"
    SampStoryObjectBase.init(o, params)
    o:updateDescription()
end
)

function Laptop:updateDescription()
    if self.modelid == Laptop.eModel.Closed then
        self.Description = "closed lid laptop"
    elseif self.modelid == Laptop.eModel.Open then
        self.Description = "open lid laptop"
    end
    return self.Description
end

Laptop.eModel = 
{
    Closed = 7188,
    Open = 7187
}