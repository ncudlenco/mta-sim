Sleep = class(StoryActionBase, function(o, params)
    params.description = PickRandom({" starts sleeping on it", " sleeps on it"})
    params.name = 'Sleep'

    StoryActionBase.init(o,params)
    o.how = params.how or Sleep.eHow.Left
end)

function Sleep:Apply()
    local actorId = self.Performer:getData('id')
    local actorPos = self.Performer.position
    local actorLocationId = self.Performer:getData('locationId')
    local targetLocationId = self.NextLocation and self.NextLocation.LocationId or 'nil'

    -- DEBUG TRACE: Capture full state at Sleep execution
    print(string.format("[MIDAIR_DEBUG][Sleep:Apply] EXECUTING actorId=%s", actorId))
    print(string.format("[MIDAIR_DEBUG][Sleep:Apply] actorId=%s locationId=%s targetLocation=%s",
        actorId, tostring(actorLocationId), tostring(targetLocationId)))
    if actorPos then
        print(string.format("[MIDAIR_DEBUG][Sleep:Apply] actorId=%s position=(%.1f, %.1f, %.1f)",
            actorId, actorPos.x, actorPos.y, actorPos.z))
    end
    if self.TargetItem then
        local targetPos = self.TargetItem.instance and self.TargetItem.instance.position
        if targetPos then
            print(string.format("[MIDAIR_DEBUG][Sleep:Apply] actorId=%s targetItem.position=(%.1f, %.1f, %.1f)",
                actorId, targetPos.x, targetPos.y, targetPos.z))
            local dist = math.abs((actorPos - targetPos).length)
            print(string.format("[MIDAIR_DEBUG][Sleep:Apply] actorId=%s distance_to_target=%.2f", actorId, dist))
            if dist > 3.0 then
                print(string.format("[MIDAIR_DEBUG][Sleep:Apply] WARNING: Actor %s is %.1f units away from furniture - MID-AIR SLEEP DETECTED!", actorId, dist))
            end
        end
    else
        print(string.format("[MIDAIR_DEBUG][Sleep:Apply] WARNING: actorId=%s TargetItem is nil!", actorId))
    end

    local story = GetStory(self.Performer)
    table.insert(story.History[actorId], self)
    StoryActionBase.Apply(self)

    StoryActionBase.GetLogger(self, story):Log(self.Description, self, false, true, {" wakes up ", " finishes sleeping "})
    -- self.TargetItem.instance:setCollisionsEnabled(false)
    -- self.Performer.rotation = self.Performer.rotation + Vector3(0,0,180)

    local setupTime = 3000

    -- -- Set indefinite looping animation
    -- if self.how == Sleep.eHow.Left then
    --     self.Performer:setAnimation("INT_HOUSE", "BED_Loop_L", -1, true, true, true, true)
    -- elseif self.how == Sleep.eHow.Right then
    --     self.Performer:setAnimation("INT_HOUSE", "BED_Loop_R", -1, true, true, true, true)
    -- end

    if DEBUG then
        outputConsole("Sleep:Apply")
    end

    OnGlobalActionFinished(setupTime, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function Sleep:GetDynamicString()
    return 'return Sleep{how = '..self.how..'}'
end

Sleep.eHow = {
    Left = 1,
    Right = 2
}