-- see https://wiki.multitheftauto.com/wiki/Weather for details
Weather = class(StoryWeatherBase, function(o, id, description)
    StoryWeatherBase.init(o, description)
    o.Id = id
end)

Weather.WeatherTypes = { 
    Weather (0, "very warm"),
    Weather (1, "warm"),
    Weather (2, "very warm with smog"),
    Weather (3, "warm with smog"),
    Weather (4, "cloudy"),
    Weather (5, "warm"),
    Weather (6, "very warm"),
    Weather (7, "cloudy"),
    Weather (8, "rainy"),
    Weather (9, "foggy"),
    Weather (10, "warm"),
    Weather (11, "very warm with heat weaves"),
    Weather (12, "cloudy"),
    Weather (13, "very warm"),
    Weather (14, "warm"),
    Weather (15, "cloudy"),
    Weather (16, "rainy"),
    Weather (17, "very warm"),
    Weather (18, "warm"),
    Weather (19, "dust storm"),
    Weather (20, "underwater"),
    Weather (21, "purple in-house"),
    Weather (22, "black and white in-house")
}

function Weather:Apply(...)
    local player = nil
    for i,v in ipairs(arg) do
        player = v
        break
    end

    setWeather(self.Id)

    local id = player:getData("id")
    local scenarioId = player:getData("scenarioId")
    local story = CURRENT_STORY

    if not story then
        outputConsole("Error: the story is null "..id.." ---> "..scenarioId)
    end
    for _, logger in ipairs(story.Loggers) do
        logger:Log(" " .. self.Description, player)
    end
end