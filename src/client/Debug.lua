DEBUG = false
if DEBUG then
    addEventHandler("onClientRender", getRootElement(), function()
        local function drawPedId(ped)
            local x = ped.position.x
            local y = ped.position.y
            local z = ped.position.z + 1
            local sx, sy, _ = getScreenFromWorldPosition ( x, y, z )
            if sx then
                local sw, sh = guiGetScreenSize ( )
                dxDrawText ( ped:getData('id')..': '..(ped:getData('name') or "-"), sx, sy, sw, sh, tocolor ( 255, 200, 0, 255 ), 1.0, "default-bold" )
                dxDrawText ( (ped:getData('currentGraphEventId') or '-/-')..': '..(ped:getData('currentGraphActionName') or '-/-'), sx, sy - 10, sw, sh, tocolor ( 255, 0, 0, 255 ), 1.0, "default-bold" )
            end
        end
        for _,ped in ipairs(getElementsByType('ped')) do
            drawPedId(ped)
        end
        drawPedId(localPlayer)
    end)
end