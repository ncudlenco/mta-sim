--- Action for stashing a spawnable object back into actor's inventory
--- Destroys the 3D object instance but keeps the inventory slot
--- @classmod Stash
Stash = class(StoryActionBase, function(o, params)
    params.description = " stashes "
    params.name = 'Stash'

    StoryActionBase.init(o, params)
end)

--- Apply the Stash action
--- Detaches and destroys object instance, clears inventory instance reference
function Stash:Apply()
    local story = GetStory(self.Performer)
    table.insert(story.History[self.Performer:getData('id')], self)
    StoryActionBase.Apply(self)

    local objectType = self.TargetItem.type

    -- Find which inventory slot has this item (using lowercase for inventory lookup)
    local inventoryType = objectType:lower() == "mobilephone" and "mobilephone" or objectType:lower()
    local slotNumber = PedHandler:HasInInventory(self.Performer, inventoryType)
    if not slotNumber then
        print('[ERROR] Stash: Actor does not have ' .. objectType .. ' in inventory')
        return
    end

    -- Get the instance
    local objectInstance = PedHandler:GetInventoryInstance(self.Performer, slotNumber)
    if not objectInstance or not objectInstance.instance then
        print('[WARNING] Stash: No instance found for ' .. objectType)
        return
    end

    -- Log narrative (include object description in the log)
    StoryActionBase.GetLogger(self, story):Log(
        self.Description .. "the " .. objectInstance.Description ..
        " in " .. self.Performer:getData('genderGenitive') .. " pocket",
        self
    )

    if DEBUG then
        outputConsole("Stash:Apply - Detaching and destroying " .. objectType)
    end

    -- Perform the stash action after a brief delay
    OnGlobalActionFinished(1000, self.Performer:getData('id'), self.Performer:getData('storyId'), function()
        -- Detach from actor
        detachElementFromBone(objectInstance.instance)

        -- Destroy the 3D instance
        objectInstance:Destroy()

        -- Clear instance reference (but keep inventory slot)
        PedHandler:ClearInventoryInstance(self.Performer, slotNumber)

        -- Remove from pickedObjects (exactly like PutDown action)
        local pickedObjects = self.Performer:getData('pickedObjects') or {}
        for i, value in ipairs(pickedObjects) do
            if value[1] == objectInstance.ObjectId then
                table.remove(pickedObjects, i)
                break
            end
        end
        self.Performer:setData('pickedObjects', pickedObjects)
    end)
end

function Stash:GetDynamicString()
    return 'return Stash{}'
end
