--- Action for taking out a spawnable object from actor's inventory
--- Creates the 3D object instance and attaches it to the actor
--- @classmod TakeOut
TakeOut = class(StoryActionBase, function(o, params)
    params.description = " takes out "
    params.name = 'TakeOut'

    StoryActionBase.init(o, params)
end)

--- Apply the TakeOut action
--- Instantiates 3D object from class instance and attaches to actor's hand
function TakeOut:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)

    -- Mark actor as holding spawnable to prevent displacement until Stash
    self.Performer:setData('isHoldingSpawnable', true)

    local objectType = self.TargetItem.type

    -- Find inventory slot
    local inventoryType = objectType:lower() == "mobilephone" and "mobilephone" or objectType:lower()
    local slotNumber = PedHandler:HasInInventory(self.Performer, inventoryType)
    if not slotNumber then
        print('[ERROR] TakeOut: Actor does not have ' .. inventoryType .. ' in inventory')
        return
    end

    -- Instantiate 3D object (Location created the class instance)
    self.TargetItem:Create()

    -- Attach to actor's right hand (bone 12)
    attachElementToBone(self.TargetItem.instance, self.Performer, 12,
                        self.TargetItem.PosOffset.x or 0,
                        self.TargetItem.PosOffset.y or 0,
                        self.TargetItem.PosOffset.z or 0,
                        self.TargetItem.RotOffset.x or 0,
                        self.TargetItem.RotOffset.y or 0,
                        self.TargetItem.RotOffset.z or 0)

    -- Store instance in inventory
    PedHandler:SetInventoryInstance(self.Performer, slotNumber, self.TargetItem)

    -- Add to pickedObjects (exactly like PickUp action)
    local pickedObjects = self.Performer:getData('pickedObjects')
    if type(pickedObjects) == 'boolean' or not pickedObjects then
        pickedObjects = {}
    end
    table.insert(pickedObjects, {self.TargetItem.ObjectId, self.TargetItem.Description})
    self.Performer:setData('pickedObjects', pickedObjects)

    -- Log narrative
    StoryActionBase.GetLogger(self, story):Log(
        self.Description .. " " .. getWordPrefix(self.TargetItem.Description) .. " " ..
        self.TargetItem.Description .. " from " .. self.Performer:getData('genderGenitive') .. " pocket",
        self
    )

    if DEBUG then
        outputConsole("TakeOut:Apply - Created and attached " .. objectType)
    end

    OnGlobalActionFinished(1000, self.Performer:getData('id'), self.Performer:getData('storyId'))
end

function TakeOut:GetDynamicString()
    return 'return TakeOut{}'
end
