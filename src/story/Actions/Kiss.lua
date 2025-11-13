Kiss = class(InteractionActionBase, function(o, params)
    params.description = " kiss each other "
    params.name = 'Kiss'
    params.interactionOffset = Vector3(-0.7, -0.7, 0) -- Kiss uses closer distance

    InteractionActionBase.init(o, params)
end)

function Kiss:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)

    -- -- Also add to TargetPlayer's history
    -- -- Kiss is symmetric - both actors perform the same action
    -- -- This ensures both actors have the correct action name for event publication
    -- table.insert(story.History[self.TargetPlayer:getData('id')], self)

    StoryActionBase.Apply(self)

    local time = 5000

    -- Synchronize actors: rotation → delay → position check → animations
    self:SyncActors(
        self.Performer,
        self.TargetPlayer,
        self.InteractionOffset,
        function()
            -- Actors are now properly positioned and facing each other
            StoryActionBase.GetLogger(self, story):Log(" and " .. self.TargetPlayer:getData('name') .. self.Description, self)

            -- Gender-specific animations
            local performerKissType = nil
            local targetKissType = nil

            if self.Performer:getData('genderNominative') == "he" then
                performerKissType = PickRandom({"playa_kiss_01", "playa_kiss_02", "playa_kiss_03"})
            else
                performerKissType = PickRandom({"grlfrd_kiss_01", "grlfrd_kiss_02", "grlfrd_kiss_03"})
                --reject kiss ; -0.7 | hugged kiss ; -0.7 | intermediate kiss
            end

            if self.TargetPlayer:getData('genderNominative') == "he" then
                targetKissType = PickRandom({"playa_kiss_01", "playa_kiss_02", "playa_kiss_03"})
            else
                targetKissType = PickRandom({"grlfrd_kiss_01", "grlfrd_kiss_02", "grlfrd_kiss_03"})
            end

            self.Performer:setAnimation("kissing", performerKissType, time, false, false, false, false)
            self.TargetPlayer:setAnimation("kissing", targetKissType, time, false, false, false, false)

            if DEBUG then
                outputConsole("Kiss:Apply")
            end

            -- Schedule action completion
            OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
            OnGlobalActionFinished(time, self.TargetPlayer:getData('id'), self.TargetPlayer:getData('storyId'))
        end
    )
end

function Kiss:GetDynamicString()
    return 'return Kiss{}'
end