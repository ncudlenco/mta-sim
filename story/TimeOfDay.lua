TimeOfDay = class(StoryTimeOfDayBase, function(o, hour, minute)
    local time = hour % 24
    if minute >= 30 then
        time = (hour + 1) % 24
    end
    local description = ""
    if (time > 5 and time < 11) then
        description = "in the morning"
    elseif (time == 12) then
        description = "at noon";
    elseif (time > 11 and time < 16) then
        description = "during the day"
    elseif (time > 16 and time < 19) then
        description = "in the evening"
    elseif (time == 0) then
        description = "in the middle of the night"
    else
        description = "during the night"
    end

    StoryTimeOfDayBase.init(o, description)
    o.Hour = hour
    o.Minute = minute
end)

function TimeOfDay:Apply(...)
    local player = nil
    for i,v in ipairs(arg) do
        player = v
        break
    end

    setTime(self.Hour, self.Minute)
    local id = player:getData("id")
    local scenarioId = player:getData("scenarioId")
    local story = STORIES[id][scenarioId]

    if not story then
        outputConsole("Error: the story is null "..id.." ---> "..scenarioId)
    end
    story.Logger.Log(" " .. self.Description, player)
end