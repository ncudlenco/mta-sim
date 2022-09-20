PedHandler = {
    PED_ZOO = {}
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
    ped:setData('pickedObjects', {})
    ped:setData('hasFocus', false)
    ped:setData('paused', false)

    math.randomseed(os.clock()*100000000000)
    math.random(); math.random(); math.random()
    math.randomseed(os.clock()*100000000000)
    math.random(); math.random(); math.random()
    local chance = math.random(0, 1)
    if chance < 0.5 then
        ped:setData('inventory_1', 'phone')
        ped:setData('inventory', '1')
    end
    math.randomseed(os.clock()*100000000000)
    math.random(); math.random(); math.random()
    math.randomseed(os.clock()*100000000000)
    math.random(); math.random(); math.random()
    chance = math.random(0, 1)
    if chance < 0.5 then
        ped:setData('inventory_2', 'cigarette')
        ped:setData('inventory', '2')
    end

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
    ped.interior = 0
    ped.position = Vector3(0,0,0)
    for sData, _ in pairs( getAllElementData( ped ) ) do
        removeElementData( ped, sData )
    end
end

function PedHandler:Dispose(ped)
    ped.interior = 0
    ped.position = Vector3(0,0,0)
    ped:kill()
end