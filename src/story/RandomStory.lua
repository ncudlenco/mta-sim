--1. De rezolvat bug-urile curente pentru a genera random in toate casele
--2. Interactiuni
--3. Random inter-episode connections

--Random story
RandomStory = class(StoryBase, function(o, spectators, maxActions, logData, artifactCollectionFactory, artifactManager, eventBus)
    StoryBase.init(o, spectators, maxActions, eventBus)
    o.LogData = logData

    -- Use the pre-configured artifact manager passed from Player.lua
    -- DO NOT create a new manager here - it would be empty!
    o.artifactManager = artifactManager
    if artifactManager and DEBUG then
        print("[RandomStory] Using pre-configured artifact collection manager")
    end

    o.Episodes = {
        -- House1(),
        -- House3(),
        -- House8(),
        -- House10(),
        -- House12()
    }
    o.DynamicEpisodes = {
        -- "house1_sweet", --V
        -- "house1_preloaded", --V
        -- (small bug -> the guy sitting on the sofa is sitting in air) and the sit down action is executed always twice
        -- and the other actions can't be reached randomly: eat, dance, sit down on the other sofa...
        -- "house3_preloaded", --V (it ends too soon)
        -- "house3_rd",
        -- "house7", --ends too soon
        "house8_preloaded",--V
        -- "house9",--V
        -- "house10_preloaded",--drink action bug loop
        -- "house12_preloaded",--ends too soon
        -- "garden",
        -- "office",
        -- "office2",
        -- "common"
        -- "gym1",
        -- "gym2",
        -- "gym3"
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

function RandomStory:Play()
    if DEBUG then
        print("RandomStory: Loading dynamic episodes..")
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
        -- Start artifact collection via artifact manager
        if ARTIFACT_COLLECTION_ENABLED and self.artifactManager then
            self.artifactManager:startScheduledCollection(
                -- Collection callback: build frameContext
                function(frameId, triggerCollection)
                    for _, spectator in ipairs(self.Spectators) do
                        -- Build game-agnostic frameContext (no spectator entity!)
                        local frameContext = {
                            playerId = spectator:getData('id'),
                            storyId = self.Id, -- Use story's ID
                            playerName = spectator.name,
                            timestamp = getTickCount and getTickCount() or 0,
                            cameraId = spectator:getData('id')
                        }
                        triggerCollection(frameContext)
                    end
                end,
                -- Completion callback
                function()
                    if DEBUG_SCREENSHOTS then
                        print("[RandomStory] All artifact collection finished")
                    end

                    if self.pendingTermination then
                        self:_completeTermination()
                    end
                end
            )
        end

        -- MAX_STORY_TIME timeout timer
        self.StoryTimeoutTimer = Timer(function()
            local elapsedTime = os.time() - self.StartTime
            print('Elapsed time '..elapsedTime)
            if elapsedTime > MAX_STORY_TIME then
                self:End("MAX_STORY_TIME exceeded")
                self.StoryTimeoutTimer:destroy()
            end
        end, 1000, 0)
    end

    if DEBUG then
        print("RandomStory: Loading a random episode...")
    end
    math.randomseed(os.clock()*100000000000)
    math.random(); math.random(); math.random()
    math.randomseed(os.clock()*100000000000)
    math.random(); math.random(); math.random()
    self.CurrentEpisode = PickRandom(self.Episodes)
    print(self.CurrentEpisode.name)
    self.CurrentEpisode:Initialize(false)

    if DEBUG then
        print("RandomStory: Playing the picked episode...")
    end
    self.CurrentEpisode:Play()
    -- self.Actor:fadeCamera (true)

    if DEBUG then
        print("RandomStory: Play - chosen random skin and episode. Playing episode")
    end
end

--- Request story termination
--- If artifact collection is active, waits for it to finish
--- @param reason string Reason for termination
function RandomStory:End(reason)
    if self.Disposed then
        return
    end

    if DEBUG then
        print("RandomStory: End - " .. (reason or "story completed"))
        outputConsole("RandomStory:End")
    end

    -- Phase 1: Immediate cleanup
    if self.StoryTimeoutTimer then
        self.StoryTimeoutTimer:destroy()
        self.StoryTimeoutTimer = nil
    end

    if self.CurrentEpisode then
        self.CurrentEpisode:Destroy()
    end

    if self.CameraHandler then
        self.CameraHandler:Reset()
    end

    self.Disposed = true

    -- Phase 2: Wait for collection, then terminate spectators
    if self.artifactManager and self.artifactManager:isScheduling() then
        if DEBUG then
            print("[RandomStory] Waiting for artifact collection to finish...")
        end

        self.pendingTermination = {
            reason = reason or "story completed successfully"
        }

        self.artifactManager:stopScheduledCollection()
    else
        self:_completeTermination(reason or "story completed successfully")
    end
end

--- Complete termination after collection finishes
--- @param reason string Reason for termination (optional, uses pendingTermination if available)
function RandomStory:_completeTermination(reason)
    local terminationReason = reason
    if self.pendingTermination then
        terminationReason = self.pendingTermination.reason
        self.pendingTermination = nil
    end

    if DEBUG then
        print("[RandomStory] Completing termination: " .. terminationReason)
    end

    for _, spectator in ipairs(self.Spectators) do
        terminatePlayer(spectator, terminationReason)
    end
end