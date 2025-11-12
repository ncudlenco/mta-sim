HandShake = class(InteractionActionBase, function(o, params)
    params.description = " shake their hands"
    params.name = 'HandShake'
    params.interactionOffset = Vector3(-0.5, -0.5, 0)

    InteractionActionBase.init(o, params)
end)

function HandShake:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)

    local time = 2000

    -- Synchronize actors: rotation → delay → position check → animations
    self:SyncActors(
        self.Performer,
        self.TargetPlayer,
        self.InteractionOffset,
        function()
            -- Actors are now properly positioned and facing each other
            StoryActionBase.GetLogger(self, story):Log(" and " .. self.TargetPlayer:getData('name') .. self.Description, self)

            -- Start animations
            local shakeType = PickRandom({"hndshkaa", "hndshkda", "hndshkfa", "prtial_hndshk_biz_01"})
            self.Performer:setAnimation("gangs", shakeType, time, false, false, false, false)
            self.TargetPlayer:setAnimation("gangs", shakeType, time, false, false, false, false)

            if DEBUG then
                outputConsole("HandShake:Apply")
            end

            -- Schedule action completion
            OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
            OnGlobalActionFinished(time, self.TargetPlayer:getData('id'), self.TargetPlayer:getData('storyId'))
        end
    )
end

function HandShake:GetDynamicString()
    return 'return HandShake{}'
end