Hug = class(InteractionActionBase, function(o, params)
    params.description = " hug each other "
    params.name = 'Hug'
    params.interactionOffset = Vector3(-0.5, -0.5, 0)

    InteractionActionBase.init(o, params)
end)

function Hug:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)

    -- -- Also add to TargetPlayer's history
    -- -- Hug is symmetric - both actors perform the same action
    -- -- This ensures both actors have the correct action name for event publication
    -- table.insert(story.History[self.TargetPlayer:getData('id')], self)

    StoryActionBase.Apply(self)

    local time = 2400

    -- Synchronize actors: rotation → delay → position check → animations
    self:SyncActors(
        self.Performer,
        self.TargetPlayer,
        self.InteractionOffset,
        function()
            -- Actors are now properly positioned and facing each other
            StoryActionBase.GetLogger(self, story):Log(" and " .. self.TargetPlayer:getData('name') .. self.Description, self)

            self.Performer:setAnimation("gangs", "hndshkfa_swt", time, false, false, false, false)
            self.TargetPlayer:setAnimation("gangs", "hndshkfa_swt", time, false, false, false, false)

            if DEBUG then
                outputConsole("Hug:Apply")
            end

            -- Schedule action completion
            OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
            OnGlobalActionFinished(time, self.TargetPlayer:getData('id'), self.TargetPlayer:getData('storyId'))
        end
    )
end

function Hug:GetDynamicString()
    return 'return Hug{}'
end