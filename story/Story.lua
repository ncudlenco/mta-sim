Story = class(StoryBase, function(o, actor, maxActions, logData)
    StoryBase.init(o, actor, maxActions)
    o.LogData = logData
    o.Logger = Logger('data/'..actor:getData('id')..'/'..o.Id..'/labels.txt', true, o)
    o.Episodes = {
        --add an episode here
        -- House1()
        House3()
        -- House8()
        -- House10()
        -- House12()
    }
    o.DynamicEpisodes = {
      -- "house3",
      -- "house1_sweet",
      -- "house7"
      -- "gym1"
      -- "gym2",
      -- "gym3"
    }
    o.Disposed = false
    if not o.Actor then
        outputConsole("Error: Actor is null "..o.Id)
    end
    o.Actor:setData('storyId', o.Id)

    if not STORIES then
        STORIES = {}
    end

    if not STORIES[o.Actor:getData('id')] then
        STORIES[o.Actor:getData('id')] = {}
    end
    STORIES[o.Actor:getData('id')][o.Id] = o

end)

function Story:Play()
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
                local story = STORIES[playerId][storyId]
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
                        player:kick("story ended")
                    end
                end
        	end
        , LOG_FREQUENCY, 0, self.Actor:getData('id'), self.Id)
    end
    local skin = PickRandom(SetPlayerSkin.PlayerSkins)
    skin.TargetItem = self.Actor
    skin.Performer = self.Actor
    skin:Apply()
    self.CurrentEpisode = PickRandom(self.Episodes)

    self.CurrentEpisode:Initialize(self.Actor)
    
    self.Actor:setData('pickedObjects', {})
    self.CurrentEpisode:Play(self.Actor)

    if DEBUG then
        outputConsole("Story:Play - chosen random skin and episode. Playing episode")
    end
end

function Story:End()
    if DEBUG then
        outputConsole("Story:End")
    end

    self.Disposed = true
end