Laugh = class(InteractionActionBase, function(o, params)
    params.description = PickRandom(" laughs at ", " is laughing ")
    params.name = 'Laugh'
    params.interactionOffset = Vector3(-0.5, -0.5, 0)

    InteractionActionBase.init(o, params)
end)

function Laugh:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)

    local time = random(5000, 16000)

    -- Synchronize actors: rotation → delay → position check → animations
    self:SyncActors(
        self.Performer,
        self.TargetPlayer,
        self.InteractionOffset,
        function()
            -- Actors are now properly positioned and facing each other
            StoryActionBase.GetLogger(self, story):Log(self.Description .. self.TargetPlayer:getData('name') .. " joke", self)

            self.Performer:setAnimation("rapping", "laugh_01", time, true, false, false, false)
            self.TargetPlayer:setAnimation("rapping", "laugh_01", time, true, false, false, false)

            if DEBUG then
                outputConsole("Laugh:Apply")
            end

            -- Schedule action completion
            OnGlobalActionFinished(time, self.Performer:getData('id'), self.Performer:getData('storyId'))
            OnGlobalActionFinished(time, self.TargetPlayer:getData('id'), self.TargetPlayer:getData('storyId'))
        end
    )
end

function Laugh:GetDynamicString()
    return 'return Laugh{}'
end