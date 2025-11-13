globalActionIdCounter = 0
StoryActionBase = class(IStoryItem, function(o, params)
    IStoryItem.init(o, params.description or params.Description or '', eStoryItemType.Action)
    o.Performer = params.performer or params.Performer or nil
    o.TargetItem = params.targetItem or params.TargetItem or nil
    o.NextLocation = params.nextLocation or params.NextLocation or nil
    o.Prerequisites = params.prerequisites or params.Prerequisites or {}
    o.ClosingAction = params.closingAction or params.ClosingAction or nil
    o.NextAction = params.nextAction or params.NextAction or nil
    math.randomseed(os.clock()*100000000000)
    math.random(); math.random(); math.random()
    math.randomseed(os.clock()*100000000000)
    math.random(); math.random(); math.random()
    globalActionIdCounter = globalActionIdCounter + 1
    o.ActionId = globalActionIdCounter..''
    o.TopologicalOrder = params.topologicalOrder or params.TopologicalOrder or -1
    o.Penalties = params.penalties or params.Penalties or {}
    o.Rewards = params.rewards or params.Rewards or {}
    o.IsClosingAction = params.isClosingAction or params.IsClosingAction or false
    o.Buffer = {}
    o.Name = params.name or ''
    o.AnimationSpeed = params.animationSpeed or ANIMATION_SPEED or 1
end)

function StoryActionBase:__tostring()
    return self.Description
  end

function StoryActionBase:__eq(other)
    return other and other:is_a(StoryActionBase) and self.ActionId == other.ActionId
end

function StoryActionBase:Apply(...)
    if DEBUG then
        print("StoryActionBase:Apply - "..self.Name)
    end
    local story = GetStory(self.Performer)
    local playerId = self.Performer:getData('id')
    if not DEFINING_EPISODES then
        -- Background actors should not request camera focus
        if not self.Performer:getData("isbackgroundactor") then
            story.CameraHandler:requestFocus(playerId)
        end
    end
    if self.Performer and self.NextLocation and self.NextLocation.LocationId then
        if DEBUG then
            print("Setting nextTargetLocation for actor "..tostring(playerId).." to "..tostring(self.NextLocation.LocationId))
        end
        self.Performer:setData('nextTargetLocation', self.NextLocation.LocationId)
    end
    self.Performer:setData('currentAction', self.Name)
end

function StoryActionBase:GetLogger(story)
    --TODO when implementing perspectives define logger strategy
    return FirstOrDefault(story.Loggers)
end

function StoryActionBase:pause(actor)
end

function StoryActionBase:resume(player)
end