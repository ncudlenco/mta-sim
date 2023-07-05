--1. De rezolvat bug-urile curente pentru a genera random in toate casele
--2. Interactiuni
--3. Random inter-episode connections

--Random story
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
        "house1_sweet", --V
        -- "house1_preloaded", --V (small bug -> the guy sitting on the sofa is sitting in air)
        -- "house3_preloaded", --V (it ends too soon, 1 error)
        -- [2023-07-04 22:56:55] ERROR: sv2l\api\StoryEpisodeBase.lua:131: Bad argument @ 'setData' [Expected argument at argument 3, got none]
        --"house7", --ends too soon
        --"house8_preloaded",--V
        -- "house9",--V
        -- [2023-07-04 23:28:17] ERROR: sv2l\story\Actions\Give.lua:24: attempt to index field 'TargetPlayer' (a nil value)
        -- "house10_preloaded",--drink action bug loop
        -- "house12_preloaded",--ends too soon
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
    o.Loggers = Select(spectators, function(spectator) return Logger('data_out/'..o.Id..'/'..spectator:getData('id'), true, o, spectator) end)
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
            function ()
                local story = CURRENT_STORY
                local elapsedTime = os.time() - self.StartTime
                print('Elapsed time '..elapsedTime)
                if elapsedTime > MAX_STORY_TIME then
                    for _,spectator in ipairs(story.Spectators) do
                        EndStory(spectator):Apply()
                    end
                end

                for _,spectator in ipairs(story.Spectators) do
                    if not story.Disposed then
                        if spectator:getData('takenShots') then
                            spectator:setData('takenShots', 1 + spectator:getData('takenShots'))
                        else
                            spectator:setData('takenShots', 1)
                        end
                        spectator:takeScreenShot(960, 540, spectator:getData('id')..';'..spectator:getData('storyId')..';'..spectator.name, 50)
                    else
                        local requestedShots = spectator:getData('takenShots')
                        local actuallyTaken = SCREENSHOTS[spectator:getData('id')][spectator:getData('storyId')]

                        if DEBUG then
                            print("RecorderTimer - storyId ".. (spectator:getData('storyId') or "null") .." actorId "..
                                (spectator:getData('id') or "null") .." waiting to download all the screenshots: " ..
                                (actuallyTaken or 'null') .. " / " .. (requestedShots or 'null')
                            )
                        end

                        if actuallyTaken >= requestedShots then
                            if DEBUG then
                                outputConsole("RecorderTimer - DONE")
                            end
                            story.RecorderTimer:destroy()
                            terminatePlayer(spectator, "story ended")
                        end
                    end
                end
            end
        , LOG_FREQUENCY, 0)
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
    if self.Disposed then
        return
    end
    if DEBUG then
        print("Story: End")
        outputConsole("Story:End")
    end

    self.CurrentEpisode:Destroy()
    self.CameraHandler:Reset()
    self.Disposed = true
end