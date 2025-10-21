PutIn = class(StoryActionBase, function(o, params)
    params.description = " puts "
    params.name = 'PutIn'

    StoryActionBase.init(o,params)
    o.Where = params.where
end)

function PutIn:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)

    StoryActionBase.GetLogger(self, story):Log(self.Description .. self.TargetItem.Description .. " in " .. self.Where, self)
    -- self.TargetItem.instance:setCollisionsEnabled(false)

    self.Performer:setAnimation("INT_SHOP", "shop_loop", 500, true, true, false, true)
    detachElementFromBone(self.TargetItem.instance)
    self.TargetItem:Destroy()

    if DEBUG then
        outputConsole("PutIn:Apply")
    end

    OnGlobalActionFinished(500, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function PutIn:GetDynamicString()
    return 'return PutIn{where = "'..self.Where..'"}'
end