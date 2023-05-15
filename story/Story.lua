Story = class(StoryBase, function(o, spectators, maxActions, logData)
    StoryBase.init(o, spectators, maxActions)
    o.LogData = logData
    o.Episodes = {
        -- House1(),
        -- House3(),
        -- House8(),
        -- House10(),
        -- House12()
    }
    o.DynamicEpisodes = {
        -- "house1_sweet",
        -- "house1_preloaded",
        -- "house3_preloaded",
        -- "house7",
        -- "house8_preloaded",
        -- "house9",
        -- "house10_preloaded",
        "house12_preloaded",
        -- "garden",
        -- "office",
        -- "office2",
        -- "common"
        --   "gym1",
        --   "gym2",
        --   "gym3"
    }
    o.SpawnableObjects = {
        "Cigarette",
        "MobilePhone",
        "Drinks",
        "Food"
    }
    o.Interactions = {
        "Handshake",
        "Talk",
        "Kiss",
        "Hug",
        "Laugh",
        "Give",
        "INV-Give",
        "Receive"
    }
    o.actionsQueues = {}
    for _,spectator in ipairs(o.Spectators) do
        if #o.Spectators < 1 or not spectator then
            outputConsole("Error: Not enough spectators registered for story "..o.Id)
        end
        spectator:setData('storyId', o.Id)
    end
    o.Loggers = Select(spectators, function(spectator) return Logger('data/'..o.Id..'/'..spectator:getData('id'), true, o, spectator) end)
    o.lastEvents = {}
    o.lastLocations = {}
    o.validMemo = {}

    o.Disposed = false

    if not CURRENT_STORY then
        CURRENT_STORY = o
    end
end)

function Story:Play()
    if DEBUG then
        print("Story: Loading dynamic episodes..")
    end

    math.randomseed(os.clock()*100000000000)
    math.random(); math.random(); math.random()

    for i,episode_name in ipairs(self.DynamicEpisodes) do
        print(episode_name)
        local episode = DynamicEpisode(episode_name)
        local success = episode:LoadFromFile()

        table.insert(self.Episodes, episode)
    end

    local worldObjects = Element.getAllByType('object')
    for i, o in ipairs(worldObjects) do
        o.collisions = false
    end

    self.StartTime = os.time()
    if self.LogData then
        self.RecorderTimer = Timer(
            function (playerId, storyId)
                local story = CURRENT_STORY
                local player = story.Actor

                if not story.Disposed then
                    if player:getData('takenShots') then
                        player:setData('takenShots', 1 + player:getData('takenShots'))
                    else
                        player:setData('takenShots', 1)
                    end
                    player:takeScreenShot(1920, 1080, playerId..player:getData('storyId')..player.name, 50)
                else
                    local requestedShots = player:getData('takenShots')
                    local actuallyTaken = SCREENSHOTS[player:getData('id')][story.Id]

                    if DEBUG then
                        outputConsole("RecorderTimer - waiting to download all the screenshots: " .. actuallyTaken .. " / " .. requestedShots)
                    end

                    if actuallyTaken >= requestedShots then
                        if DEBUG then
                            outputConsole("RecorderTimer - DONE")
                        end
                        story.RecorderTimer:destroy()
                        terminatePlayer(player, "story ended")
                    end
                end
        	end
        , LOG_FREQUENCY, 0, self.Actor:getData('id'), self.Id)
    end

    if DEBUG then
        print("Story: Loading a random episode...")
    end
    math.randomseed(os.clock()*100000000000)
    math.random(); math.random(); math.random()
    math.randomseed(os.clock()*100000000000)
    math.random(); math.random(); math.random()
    self.CurrentEpisode = PickRandom(self.Episodes)
    print(self.CurrentEpisode.name)
    self.CurrentEpisode:Initialize(false)

    if DEBUG then
        print("Story: Playing the picked episode...")
    end
    self.CurrentEpisode:Play()
    -- self.Actor:fadeCamera (true)

    if DEBUG then
        print("Story: Play - chosen random skin and episode. Playing episode")
    end
end

function Story:End()
    if DEBUG then
        print("Story: End")
        outputConsole("Story:End")
    end

    self.CurrentEpisode:Destroy()
    self.CameraHandler:Reset()
    self.Disposed = true
end