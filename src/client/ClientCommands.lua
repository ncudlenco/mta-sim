addCommandHandler("cmarker",
	function (commandName)
		outputDebugString("Got: "..commandName)
        local thePlayer = localPlayer
        local x = thePlayer.position.x + 3
        local y = thePlayer.position.y
        local z = thePlayer.position.z
		local marker = Marker(x, y, z, "cylinder", 1, 255, 0, 0, 128)
		marker.interior = thePlayer.interior
	end
)

addCommandHandler("visibleTextures",
    function (commandName)
        outputDebugString("Visible textures:")
        local visibleTextures = engineGetVisibleTextureNames()
        for _, texName in ipairs(visibleTextures) do
            outputDebugString(" - " .. texName)
        end
    end
)

addCommandHandler("cmarker_hide",
    function (commandName)
        local thePlayer = localPlayer
        -- get all objects of type marker
        for i, marker in ipairs(getElementsByType("marker")) do
            local dimension = getElementDimension(marker)
            outputDebugString(string.format("Marker %d: Position=(%.2f, %.2f, %.2f), Dimension=%d", i, marker.position.x, marker.position.y, marker.position.z, dimension))

            -- Move marker to another dimension which will hopefully make it invisible
            setElementDimension(marker, dimension + 1)
        end
    end
)

addCommandHandler("cmarker_show",
    function (commandName)
        local thePlayer = localPlayer
        -- get all objects of type marker
        for i, marker in ipairs(getElementsByType("marker")) do
            local dimension = getElementDimension(marker)
            outputDebugString(string.format("Marker %d: Position=(%.2f, %.2f, %.2f), Dimension=%d", i, marker.position.x, marker.position.y, marker.position.z, dimension))

            -- Move marker to another dimension which will hopefully make it invisible
            setElementDimension(marker, dimension - 1)
        end
    end
)