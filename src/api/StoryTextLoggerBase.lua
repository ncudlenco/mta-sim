StoryTextLoggerBase = class(function(o, path)
    o.Path = path
end)

function StoryTextLoggerBase:Log(text, ...)
    print(text)
end