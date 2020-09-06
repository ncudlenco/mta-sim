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

    local n = (b - a):cross(c - a)
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

--     Globals which should be set before calling this function:
--     
--     int    polyCorners  =  how many corners the polygon has (no repeats)
--     float  polyX[]      =  horizontal coordinates of corners
--     float  polyY[]      =  vertical coordinates of corners
--     float  x, y         =  point to be tested
--     
--     (Globals are used in this example for purposes of speed.  Change as
--     desired.)
--     
--     The function will return YES if the point x,y is inside the polygon, or
--     NO if it is not.  If the point is exactly on the edge of the polygon,
--     then the function may return YES or NO.
--     
--     Note that division by zero is avoided because the division is protected
--     by the "if" clause which surrounds it.
    
function Region:IsPointInside(testPoint)

    local i = 1
    local j = #self.vertexes
    local oddNodes = false

    while i <= #self.vertexes do
        if self.vertexes[i].y < testPoint.y and self.vertexes[j].y >= testPoint.y
            or  self.vertexes[j].y < testPoint.y and self.vertexes[i].y >= testPoint.y then
            if self.vertexes[i].x + (testPoint.y - self.vertexes[i].y) / (self.vertexes[j].y - self.vertexes[i].y) * (self.vertexes[j].x - self.vertexes[i].x) < testPoint.x then
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
        if math.abs(r:GetDistanceByNormal(point)) < range then
            table.insert(filtered, r)
        end
    end
    return filtered
end

function Region.GetClosest(element, regions, isInstance)
    local minDistance = 9999999;
    local closestRegion = nil
    for k,r in ipairs(regions) do
        if r:IsPointInside(element.position) then
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

    if not self.isExplored then
        if not previousRegion then
            story.Logger:Log(player:getData('skinDescription').. ' is in the ' .. self.name, player, true)
        end
        
        local locationMap = self:MapObjectsLocations(player.position, player.matrix.forward, player.matrix.up)

        self.isExplored = true
        --describe it here
        -- if self.Description and self.Description ~= '' then
        --     story.Logger:Log(self.Description, player, true)
        -- elseif self.Objects and #self.Objects > 0 then
            local objectsDescription = story.Logger:DescribeObjects(player, self.name, self.Objects, locationMap, true)
            story.Logger:Log(objectsDescription, player, true)
        -- end
    end
--TODO: change the current camera and so on and so forth
    if STATIC_CAMERA and self.cameras and #self.cameras > 0 then
        local cameraPos = PickRandom(self.cameras)
        player:setCameraMatrix(cameraPos.x, cameraPos.y, cameraPos.z, cameraPos.lx, cameraPos.ly, cameraPos.lz, cameraPos.roll, cameraPos.fov)
    end

end