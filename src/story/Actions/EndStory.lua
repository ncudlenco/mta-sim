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
            story:End("EndStory action executed")
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
            print("EndStory:PausePerformer - actor "..player:getData('id').." finished and is waiting for the others to finish")
            local unfinishedActors = Where(CURRENT_STORY.CurrentEpisode.peds, function(ped) return player:getData('id') ~= ped:getData('id') and not ped:getData('storyEnded') end)
            for i,p in ipairs(unfinishedActors) do
                print(p:getData('id'))
            end
            --the episode is ended for the current actor, wait for all the other actors to finish
            otherActorsStillPerforming = true
        end
    end

    player:setData('storyEnded', true)
    self:ExecuteEndAnimations()

    return otherActorsStillPerforming
end

function EndStory:ExecuteEndAnimations()
    self.Performer:setAnimation("cop_ambient", "coplook_loop", 0, true, false, false, true)
end

function EndStory:GetDynamicString()
    return 'return EndStory{}'
end