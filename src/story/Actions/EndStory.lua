EndStory = class(StoryActionBase, function(o, player)
    local params = {}
    params.performer = player
    StoryActionBase.init(o, params)
    o.IsClosingAction = true
end)

function EndStory:Apply()
    if DEBUG then
        print("EndStory:Apply "..self.Performer:getData('id'))
    end
    if self.Performer:getData('storyEnded') then
        return
    end
    CURRENT_STORY.CameraHandler:clearFocusRequests(self.Performer:getData('id'))

    local areOtherActorsStillPerforming = self:PausePerformer()
    if not areOtherActorsStillPerforming then
        self:EndStory()
    end
end

function EndStory:EndStory()
    Timer(function(self)
        local story = GetStory(self.Performer)

        -- Dispose PedHandler for this actor
        PedHandler:Dispose(self.Performer)

        -- Request story end - story handles collection wait and spectator termination
        if story then
            story:End()
        end
    end, 5000, 1, self)
end

function EndStory:PausePerformer()
    local player = self.Performer
    local otherActorsStillPerforming = false
    if LOAD_FROM_GRAPH then
        if Any(CURRENT_STORY.CurrentEpisode.peds, function(ped) return player:getData('id') ~= ped:getData('id') and not ped:getData('storyEnded') end) then
            if DEBUG then
                print("EndStory:PausePerformer - waiting for the others to finish")
            end
            local unfinishedActors = Where(CURRENT_STORY.CurrentEpisode.peds, function(ped) return player:getData('id') ~= ped:getData('id') and not ped:getData('storyEnded') end)
            print("EndStory:PausePerformer - actor "..player:getData('id').." finished and is waiting for the others to finish. Unfinished actors: "..#unfinishedActors)
            for i,p in ipairs(unfinishedActors) do
                print(p:getData('id'))
            end
            --the episode is ended for the current actor, wait for all the other actors to finish
            otherActorsStillPerforming = #unfinishedActors > 0
        end
    end

    player:setData('storyEnded', true)
    self:ExecuteEndAnimations()

    return otherActorsStillPerforming
end

function EndStory:ExecuteEndAnimations()
    -- Simply leave them
    if DEBUG then
        self.Performer:setAnimation("cop_ambient", "coplook_loop", 0, true, false, false, true)
    end
end

function EndStory:GetDynamicString()
    return 'return EndStory{}'
end