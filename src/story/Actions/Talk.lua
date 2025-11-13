Talk = class(InteractionActionBase, function(o, params)
    params.description = " talks to "
    params.name = 'Talk'
    params.interactionOffset = Vector3(-0.5, -0.5, 0)

    InteractionActionBase.init(o, params)
end)

function Talk:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)

    -- -- Also add to TargetPlayer's history
    -- -- Talk is symmetric - both actors perform the same action
    -- -- This ensures both actors have the correct action name for event publication
    -- table.insert(story.History[self.TargetPlayer:getData('id')], self)

    StoryActionBase.Apply(self)

    local time = random(5000, 16000)

    -- Synchronize actors: rotation → delay → position check → animations
    self:SyncActors(
        self.Performer,
        self.TargetPlayer,
        self.InteractionOffset,
        function()
            -- Actors are now properly positioned and facing each other
            StoryActionBase.GetLogger(self, story):Log(self.Description .. self.TargetPlayer:getData('name'), self)

            local talkType = PickRandom({"prtial_gngtlka", "prtial_gngtlkb", "prtial_gngtlkc",
                                         "prtial_gngtlkd", "prtial_gngtlke", "prtial_gngtlkf",
                                         "prtial_gngtlkg", "prtial_gngtlkh"})
            self.Performer:setAnimation("gangs", talkType, time, false, false, false, false)

            talkType = PickRandom({"prtial_gngtlka", "prtial_gngtlkb", "prtial_gngtlkc",
                                   "prtial_gngtlkd", "prtial_gngtlke", "prtial_gngtlkf",
                                   "prtial_gngtlkg", "prtial_gngtlkh"})
            self.TargetPlayer:setAnimation("gangs", talkType, time, false, false, false, false)

            if DEBUG then
                outputConsole("Talk:Apply")
            end

            -- Schedule action completion
            OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
            OnGlobalActionFinished(time, self.TargetPlayer:getData('id'), self.TargetPlayer:getData('storyId'))
        end
    )
end

function Talk:GetDynamicString()
    return 'return Talk{}'
end