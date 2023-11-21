Wait = class(StoryActionBase, function(o, params)
    params.description = PickRandom({" is waiting for something ", " is looking around "})
    params.name = 'Wait'

    StoryActionBase.init(o,params)
    o.Time = params.time
    o.targetInteraction = params.targetInteraction
    o.doNothing = params.doNothing
end)

-- Something real shady is happening here... Leads to sync problems. Some POI are busy from the start and peds are in a waiting state.
function Wait:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)

    StoryActionBase.GetLogger(self, story):Log(self.Description, self)
    StoryActionBase.Apply(self)

    self.Performer:setAnimation("cop_ambient", "coplook_loop", 5000, true, false, false, true) --TODO: do something smarter
    if DEBUG then
        outputConsole("Wait:Apply")
    end
    self.Performer:setData("isWaitingForInteraction", self.targetInteraction)
    self.Performer:getData('isReadyForInteraction', false)

    local function wait()
        --Discard the z coordinate to handle the cases when actors located one next to each other are climbed on a table or another object.
        local distance = math.abs((Vector3(self.Performer.position.x, self.Performer.position.y, 0) - Vector3(self.TargetItem.position.x, self.TargetItem.position.y, 0)).length)
        local otherTargetLocation = self.TargetItem:getData('nextTargetLocation')
        local isOtherPlayerInTargetLocation = otherTargetLocation == self.NextLocation.LocationId
        local isOtherPlayerNearby = distance <= 1.5
        local isOtherPlayerWaitingForSameInteraction = self.TargetItem:getData("isWaitingForInteraction") == self.targetInteraction

        -- When the other actor is not near the current actor, and the other actor is actually coming here to execute an interaction and the actor that does not initiate the interaction
        -- has already waited and is ready to be interacted with
        if not isOtherPlayerNearby or not isOtherPlayerInTargetLocation or not isOtherPlayerWaitingForSameInteraction
        then
            self.Performer:setAnimation("cop_ambient", "coplook_loop", 5000, true, false, false, true) --TODO: do something smarter
            print(self.Performer:getData('id')..": WAIT AGAIN with distance between "..self.Performer:getData('id')..' and '..self.TargetItem:getData('id')..' is '..distance..'. The other target location is '..(otherTargetLocation or 'nil')..' The other interaction is '..(self.TargetItem:getData('isWaitingForInteraction') or 'nil'))
            Timer(wait, 5000, 1)
        elseif not self.doNothing then
            if not self.TargetItem:getData('isReadyForInteraction') then
                print(self.Performer:getData('id')..": My WAIT IS FINISHED but the other is not ready for interaction. Distance between "..self.Performer:getData('id')..' and '..self.TargetItem:getData('id')..' is '..distance..'. The other target location is '..(otherTargetLocation or 'nil')..' The other interaction is '..(self.TargetItem:getData('isWaitingForInteraction') or 'nil'))
                Timer(wait, 5000, 1)
            else
                -- Only the active actor gets here
                print(self.Performer:getData('id')..": WAIT IS FINISHED with distance between "..self.Performer:getData('id')..' and '..self.TargetItem:getData('id')..' is '..distance..'. The other target location is '..(otherTargetLocation or 'nil')..' The other interaction is '..(self.TargetItem:getData('isWaitingForInteraction') or 'nil'))
                OnGlobalActionFinished(1000, self.Performer:getData('id'), self.Performer:getData('storyId'))
            end
        else
            -- Only the passive actor gets here
            self.Performer:setData('isReadyForInteraction', true)
            print(self.Performer:getData('id')..": WAIT IS FINISHED with do nothing (next action is not called) distance between "..self.Performer:getData('id')..' and '..self.TargetItem:getData('id')..' is '..distance..'. The other target location is '..(otherTargetLocation or 'nil')..' The other interaction is '..(self.TargetItem:getData('isWaitingForInteraction') or 'nil'))
        end
    end
    -- self.NextLocation.isBusy = false
    wait()
end

function Wait:GetDynamicString()
    local doNothingStr = 'false'
    if self.doNothing then
        doNothingStr = 'true'
    end
    return 'return Wait{ doNothing = '..doNothingStr..' }'
end