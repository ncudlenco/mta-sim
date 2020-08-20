Region = class(StoryLocationBase, function(o, params)
    o.Description = params.description
    o.Objects = params.objects    
end)