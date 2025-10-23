PedHandler = {
    PED_ZOO = {},
    -- Internal table for tracking spawnable object instances (avoids setData with complex types)
    inventoryInstances = {}
}

function PedHandler:ReInitialize()
    for i,ped in ipairs(self.PED_ZOO) do
        self:Dispose(ped)
    end
    for i,skin in ipairs(SetPlayerSkin.PlayerSkins) do
        skin.isTaken = false
    end
end

function PedHandler:InitializePed(ped)
    local g = Guid()
    ped:setData("id", g.Id)
    ped:setData("isPed", true)
    ped:setData("isSpawned", false)
    ped:setData("isReadyForInteraction", false)
    ped:setData('pickedObjects', {})
    ped:setData('hasFocus', false)
    ped:setData('paused', false)
    ped:setData('mappedChainId', nil)


    -- Guarantee all actors have phone and cigarette in inventory
    ped:setData('inventory_1', 'mobilephone')
    ped:setData('inventory_2', 'cigarette')

end

--- Check if ped has item type in any inventory slot
-- @param ped The ped element to check
-- @param itemType The type of item to search for (e.g., 'phone', 'cigarette')
-- @return The slot number if found, nil otherwise
function PedHandler:HasInInventory(ped, itemType)
    for i = 1, 2 do
        local slot = ped:getData('inventory_' .. i)
        if slot and slot:lower() == itemType:lower() then
            return i
        end
    end
    return nil
end

--- Get the spawned instance for an inventory item
-- @param ped The ped element
-- @param slotNumber The inventory slot number (1 or 2)
-- @return The object instance or nil
function PedHandler:GetInventoryInstance(ped, slotNumber)
    local pedId = ped:getData('id')
    if not pedId or not self.inventoryInstances[pedId] then
        return nil
    end
    return self.inventoryInstances[pedId][slotNumber]
end

--- Set the spawned instance for an inventory item
-- @param ped The ped element
-- @param slotNumber The inventory slot number (1 or 2)
-- @param instance The object instance to store
function PedHandler:SetInventoryInstance(ped, slotNumber, instance)
    local pedId = ped:getData('id')
    if not pedId then
        return
    end
    if not self.inventoryInstances[pedId] then
        self.inventoryInstances[pedId] = {}
    end
    self.inventoryInstances[pedId][slotNumber] = instance
end

--- Clear the spawned instance for an inventory item
-- @param ped The ped element
-- @param slotNumber The inventory slot number (1 or 2)
function PedHandler:ClearInventoryInstance(ped, slotNumber)
    local pedId = ped:getData('id')
    if not pedId or not self.inventoryInstances[pedId] then
        return
    end

    -- Destroy the object instance if it exists
    local instance = self.inventoryInstances[pedId][slotNumber]
    if instance and instance.Destroy then
        instance:Destroy()
    end

    self.inventoryInstances[pedId][slotNumber] = nil
end

function PedHandler:GetOrCreatePed(modelId, x, y, z, angle)
    print('Get or create ped '..modelId)
    outputConsole('Get or create ped '..modelId)
    local ped = nil
    -- for i,p in ipairs(self.PED_ZOO) do
    --     if p and not p:getData('assigned') then
    --         self:Reset(p)
    --         p.model = modelId
    --         p.position = Vector3(x,y,z)
    --         p.rotation = Vector3(0,0,angle)
    --         p:setData('assigned', true)
    --         ped = p
    --         print('Found non-assigned ped')
    --         outputConsole('Found non-assigned ped')
    --         break
    --     end
    -- end

    if not ped then
        print('Creating a new ped')
        outputConsole('Creating a new ped')
        ped = Ped(modelId, x, y, z, angle)
        if not ped then
            error('Error while creating the ped '..modelId)
        end
        ped:setData('assigned', true)
        table.insert(self.PED_ZOO, ped)
    end
    self:InitializePed(ped)
    return ped
end

function PedHandler:Reset(ped)
    -- Clean up spawnable object instances
    local pedId = ped:getData('id')
    if pedId and self.inventoryInstances[pedId] then
        for _, instance in pairs(self.inventoryInstances[pedId]) do
            if instance and instance.Destroy then
                instance:Destroy()
            end
        end
        self.inventoryInstances[pedId] = nil
    end

    ped.interior = 0
    ped.position = Vector3(0,0,0)
    for sData, _ in pairs( getAllElementData( ped ) ) do
        removeElementData( ped, sData )
    end
end

function PedHandler:Dispose(ped)
    -- Clean up spawnable object instances
    local pedId = ped:getData('id')
    if pedId and self.inventoryInstances[pedId] then
        for _, instance in pairs(self.inventoryInstances[pedId]) do
            if instance and instance.Destroy then
                instance:Destroy()
            end
        end
        self.inventoryInstances[pedId] = nil
    end

    ped.interior = 0
    ped.position = Vector3(0,0,0)
    ped:kill()
end