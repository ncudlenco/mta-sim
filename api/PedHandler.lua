PedHandler = {
    PED_ZOO = {}
}

function PedHandler:ReInitialize()
    for i,p in ipairs(self.PED_ZOO) do
        p:setData('assigned', false)
        ped.interior = 0
        ped.position = Vector3(0,0,0)
    end
end

function PedHandler:GetOrCreatePed(modelId, x, y, z, angle)
    print('Get or create ped '..modelId)
    outputConsole('Get or create ped '..modelId)
    local ped = nil
    for i,p in ipairs(self.PED_ZOO) do
        if not p:getData('assigned') then
            p.model = modelId
            p.position = Vector3(x,y,z)
            p.rotation = Vector3(0,0,angle)
            p.setData('assigned', true)
            ped = p
            print('Found non-assigned ped')
            outputConsole('Found non-assigned ped')
    break
        end
    end

    if not ped then
        print('Creating a new ped')
        outputConsole('Creating a new ped')
        ped = Ped(modelId, x, y, z, angle)
        if not ped then
            error('Error while creating the ped '..i)
        end
        ped:setData('assigned', true)
        table.insert(self.PED_ZOO, ped)
    end
    return ped
end

function PedHandler:Reset(ped)
    ped.interior = 0
    ped.position = Vector3(0,0,0)
    ped:setData('assigned', false)
end