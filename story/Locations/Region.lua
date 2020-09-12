Region = class(function(o, params)
    o.name = params.name or ""
    o.Description = params.Description or params.description or ""
    o.instance = nil
    o.vertexes = params.vertexes or {}
    o.center = params.center or nil
    o.isExplored = params.isExplored or false
    o.Episode = nil
    o.Id = Guid().Id
    o.Objects = params.Objects or params.objects or {}
    o.POI = params.POI or params.poi or {}
    o.cameras = params.cameras or {}
end)

function Region.VertexToVector3(v)
    return Vector3(v.x, v.y, v.z)
end

function Region:GetNormal()
    local a = Region.VertexToVector3(self.vertexes[1])
    local b = Region.VertexToVector3(self.vertexes[2])
    local c = Region.VertexToVector3(self.vertexes[3])

    local n = (a - b):cross(c - b)
    n:normalize()
    return n
end

function Region:GetDistanceByNormal(point)
    local plane = Plane3(self.center, self:GetNormal())
    return plane:distanceTo(point)
end

function Region:MapObjectsLocations(pointOfView, forward, up)
    local locationMap = {
        right={},
        left={},
        front={},
        unknown={}
    }
    for _,o in ipairs(self.Objects) do
        if o.position then
            local angle = forward:angleAboutAxis(o.position - pointOfView, up)
            angle = math.deg(angle)
--between -15 and 15 the object is in front of the player
            if math.abs(angle) <= 15 then
                table.insert(locationMap.front, o)
--between 15 and 180 the object is on the left side
            elseif angle > 0 and angle <= 135 then
                table.insert(locationMap.left, o)
--between -180 and -15 the object is on the right side
            elseif angle < 0 and angle >= -135 then
                table.insert(locationMap.right, o)
            end
        else
            table.insert(locationMap.unknown, o)
        end
    end
    return locationMap
end
   
--     The function will return true if the point is inside the polygon, or
--     false if it is not.  If the point is exactly on the edge of the polygon,
--     then the function may return true or false.
--     Note that this only works in 2D, so the point should be coplanar to the polygon
--     
--     Note that division by zero is avoided because the division is protected
--     by the "if" clause which surrounds it.
    
function Region:IsPointInside(_testPoint, transformToPolygonCoordinates)
    local testPoint = _testPoint
    local vertexes = self.vertexes

    if transformToPolygonCoordinates then
        local o = Region.VertexToVector3(self.vertexes[2])
        local oX = Region.VertexToVector3(self.vertexes[3]) - Region.VertexToVector3(self.vertexes[2])
        local oY = Region.VertexToVector3(self.vertexes[1]) - Region.VertexToVector3(self.vertexes[2])
        local oZ = oX:cross(oY)
        oY = oZ:cross(oX)
        oX:normalize()
        oY:normalize()
        oZ:normalize()

        function transformCoordinates(p, o, oX, oY, oZ)
            local t = p - o
            return Vector3(oX:dot(t), oY:dot(t), oZ:dot(t))
        end

        local plane = Plane3(self.center, self:GetNormal())

        testPoint = transformCoordinates(plane:project(_testPoint), o, oX, oY, oZ)
        vertexes = {}
        for _,v in ipairs(self.vertexes) do
            table.insert(vertexes, transformCoordinates(Region.VertexToVector3(v), o, oX, oY, oZ))
        end
    end

    local i = 1
    local j = #vertexes
    local oddNodes = false

    while i <= #vertexes do
        if vertexes[i].y < testPoint.y and vertexes[j].y >= testPoint.y
            or  vertexes[j].y < testPoint.y and vertexes[i].y >= testPoint.y then
            if vertexes[i].x + (testPoint.y - vertexes[i].y) / (vertexes[j].y - vertexes[i].y) * (vertexes[j].x - vertexes[i].x) < testPoint.x then
                oddNodes = not oddNodes
            end
        end
        j=i
        i = i+1
    end

    return oddNodes
end

function Region:IsPointInsideConvex(testPoint)
    --Check if a triangle or higher n-gon
    if DEBUG and #self.vertexes < 3 then
        outputConsole("Region - IsPointInsideConvex: Error, less than 3 vertexes! "..self.name)
    end
    --n>2 Keep track of cross product sign changes
    local pos = 0;
    local neg = 0;

    for i,vv in ipairs(self.vertexes) do
        local v = Vector3(vv.x,vv.y,vv.z)
        --If point is a polygon vertex
        if math.abs((v - testPoint).length) < 0.0001 then
            return true
        end

        --Form a segment between the i'th point
        local x1 = v.x;
        local y1 = v.y;

        --And the i+1'th, or if i is the last, with the first point
        local i2 = 1
        if i < #self.vertexes then i2 = i + 1 end

        local x2 = self.vertexes[i2].x;
        local y2 = self.vertexes[i2].y;

        local x = testPoint.x;
        local y = testPoint.y;

        --Compute the cross product
        local d = (x - x1)*(y2 - y1) - (y - y1)*(x2 - x1)

        if d > 0 then pos = pos + 1 end
        if d < 0 then neg = neg + 1 end

        --If the sign changes, then point is outside
        if pos > 0 and neg > 0 then
            return false
        end
    end
    --If no change in direction, then on same side of all segments, and thus inside
    return true
end

function Region:__tostring()
    return self.name
  end

function Region:__eq(other)
    return other and other:is_a(Region) and self.Id == other.Id
end

function Region.FilterWithinRange(point, regions, range)
    local filtered = {}
    for k,r in ipairs(regions) do
        local dist = r:GetDistanceByNormal(point)
        if math.abs(dist) < range then
            table.insert(filtered, r)
        end
    end
    return filtered
end

function Region.GetClosest(element, regions, isInstance)
    local minDistance = 9999999;
    local closestRegion = nil
    for k,r in ipairs(regions) do
        if (isInstance and element and isElementWithinColShape(element, r.instance)) or r:IsPointInside(element.position) then
            local distance = math.abs(r:GetDistanceByNormal(element.position))
            if distance < minDistance then
                minDistance = distance
                closestRegion = r
            end
        end
    end
    return closestRegion
end

function Region:OnPlayerHit(player)
    if DEBUG then
        outputConsole('Region:OnPlayerHit - '..self.name)
    end
    local story = GetStory(player)

    local previousRegion = player:getData('currentRegion')
    player:setData('currentRegion', self.name)
    player:setData('currentRegionId', self.Id)

    self.Episode.CurrentRegion = self
    --TODO: change the current camera and so on and so forth
    if STATIC_CAMERA and self.cameras and #self.cameras > 0 then
        local cameraPos = PickRandom(self.cameras)
        player:setCameraMatrix(cameraPos.x, cameraPos.y, cameraPos.z, cameraPos.lx, cameraPos.ly, cameraPos.lz, cameraPos.roll, cameraPos.fov)
    end

    if not self.isExplored then
        if not previousRegion then
            story.Logger:Log(player:getData('skinDescription').. ' is in the ' .. self.name, player, true)
        end
        
        local pointOfView = player.position
        local pointOfViewForward = player.matrix.forward
        if STATIC_CAMERA and self.cameras and #self.cameras > 0 then
            local x, y, z, lx, ly, lz = player:getCameraMatrix()
            pointOfView = Vector3(x,y,z)
            pointOfViewForward = Vector3(lx,ly,lz) - pointOfView
        end
        local locationMap = self:MapObjectsLocations(pointOfView, pointOfViewForward, player.matrix.up)

        self.isExplored = true
        --describe it here
        -- if self.Description and self.Description ~= '' then
        --     story.Logger:Log(self.Description, player, true)
        -- elseif self.Objects and #self.Objects > 0 then
            local objectsDescription = story.Logger:DescribeObjects(player, self.name, self.Objects, locationMap, true)
            story.Logger:Log(objectsDescription, player, true)
            story.Logger.PreviousObjectDescription = true
        -- end
    end
end