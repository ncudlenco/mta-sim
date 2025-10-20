DynamicAction = class(StoryActionBase, function(o, params)
    StoryActionBase.init(o,params)
    o.block = params.block
    o.anim = params.anim
    o.time = params.time
    o.loop = params.loop
    o.updatePosition = params.updatePosition
    o.interruptable = params.interruptable
    o.freezeLastFrame = params.freezeLastFrame
end)

function DynamicAction:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)

    StoryActionBase.GetLogger(self, story):Log(" " ..self.Description, self)

    setPedAnimation(self.Performer, self.block, self.anim, self.time or 3000, self.loop or true, self.updatePosition or true, self.interruptable or false, self.freezeLastFrame or true)

    if DEBUG then
        outputConsole((self.name or "DynamicAction")..":Apply")
    end

    OnGlobalActionFinished(1000, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function DynamicAction:GetDynamicString()
    return 'return DynamicAction{ block = '..self.block..','..
        'anim = '..self.anim..', '..
        'name = '..self.Name..', '..
        'time = '..(self.time or 'nil')..', '..
        'loop = '..(self.loop or 'nil')..', '..
        'updatePosition = '..(self.updatePosition or 'nil')..', '..
        'interruptable = '..(self.interruptable or 'nil')..', '..
        'freezeLastFrame = '..(self.freezeLastFrame or 'nil')..
    '}'
end