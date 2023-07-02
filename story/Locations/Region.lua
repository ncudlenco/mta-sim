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
    o.EvaluatingRegion = false
end)

function Region.VertexToVector3(v)
    return Vector3(v.x, v.y, v.z)
end

--looks at the vertexes in a region and makes sure all points are coplanar
--projects all outliers on the majoritary common plane
function Region.ProcessVertexesPlane(region)
    --Takes points three by three, counts how many points are not on the plane
    --Choose the plane with the most points on it
    local bestFittingPlane = nil
    local bestPointsOnPlane = -1
    for i = 1, #region.vertexes do
        local j = i % #region.vertexes + 1
        local k = j % #region.vertexes + 1
        outputChatBox('i: '..i..' j: '..j..' k: '..k)
        local a = Region.VertexToVector3(region.vertexes[i])
        local b = Region.VertexToVector3(region.vertexes[j])
        local c = Region.VertexToVector3(region.vertexes[k])

        local n = (a - b):cross(c - b)
        n:normalize()
        local plane = Plane3(b, n)
        local pointsOnPlane = 0
        for _, v in ipairs(region.vertexes) do
            if plane:isPointOnPlane(Region.VertexToVector3(v)) then
                pointsOnPlane = pointsOnPlane + 1
            end
        end
        if pointsOnPlane > bestPointsOnPlane then
            bestFittingPlane = plane
            bestPointsOnPlane = pointsOnPlane
        end
    end
    --Project all the other points on this plane
    --Recompute the center
    region.center = Vector3(0,0,0)
    for i = 1, #region.vertexes do
        local v = bestFittingPlane:project(Region.VertexToVector3(region.vertexes[i]))
        region.vertexes[i] = v:unpack()
        region.center = region.center + v
    end
    region.center = (region.center / #region.vertexes):unpack()
    return region
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

function Region:MapObjectsAndPedsLocations(pointOfView, forward, up)
    local locationMap = {
        right={},
        left={},
        front={},
        unknown={}
    }
    local function mapElement(o, ignoreMap)
        if o.position then
            local angle = forward:angleAboutAxis(o.position - pointOfView, up)
            angle = math.deg(angle)
--between -15 and 15 the object is in front of the player
            if math.abs(angle) <= 15 then
                if not ignoreMap then
                    table.insert(locationMap.front, o)
                end
                if o.setData then
                    o:setData('relativePosition', 'front')
                end
--between 15 and 180 the object is on the left side
            elseif angle > 0 and angle <= 135 then
                if not ignoreMap then
                    table.insert(locationMap.left, o)
                end
                if o.setData then
                    o:setData('relativePosition', 'left')
                end
                --between -180 and -15 the object is on the right side
            elseif angle < 0 and angle >= -135 then
                if not ignoreMap then
                    table.insert(locationMap.right, o)
                end
                if o.setData then
                    o:setData('relativePosition', 'right')
                end
            end
        else
            if not ignoreMap then
                table.insert(locationMap.unknown, o)
            end
            if o.setData then
                o:setData('relativePosition', 'unknown')
            end
        end
    end
    for _,o in ipairs(self.Objects) do
        mapElement(o)
    end
    for _,ped in ipairs(CURRENT_STORY.CurrentEpisode.peds) do
        if ped:getData('currentRegionId') == self.Id then
            mapElement(ped, true)
        end
    end
    for _,poi in ipairs(self.POI) do
        mapElement(poi, true)
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

--https://rosettacode.org/wiki/Ray-casting_algorithm#Lua
function Region:IsPointInside2(testPoint)
    local plane = Plane3(self.center, self:GetNormal())

    testPoint = plane:project(testPoint)
    local points = {}
    for _,v in ipairs(self.vertexes) do
        table.insert(points, plane:project(Region.VertexToVector3(v)))
    end

    local odd, eps = false, 1e-9
    local function rayseg(p, a, b)
        if a.y > b.y then a, b = b, a end
        if p.y == a.y or p.y == b.y then p.y = p.y + eps end
        if p.y < a.y or p.y > b.y or p.x > math.max(a.x, b.x) then return false end
        if p.x < math.min(a.x, b.x) then return true end
        local red = a.x == b.x and math.huge or (b.y-a.y)/(b.x-a.x)
        local blu = a.x == p.x and math.huge or (p.y-a.y)/(p.x-a.x)
        return blu >= red
    end
    for i, a in ipairs(points) do
        local b = points[i%#points+1]
        if rayseg(testPoint, a, b) then odd = not odd end
    end
    return odd
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

MALFUNCTIONS = 0
OUT_OF = 0
function Region.GetClosest(element, regions, isInstance)
    local minDistance = 9999999;
    local closestRegion = nil
    for k,r in ipairs(regions) do
        if (isInstance and element and isElementWithinColShape(element, r.instance)) or r:IsPointInside2(element.position) then
            local distance = math.abs(r:GetDistanceByNormal(element.position))
            if distance < minDistance then
                minDistance = distance
                closestRegion = r
            end
        end
    end
    OUT_OF = OUT_OF + 1
    if closestRegion == nil then
        MALFUNCTIONS = MALFUNCTIONS + 1
        print("[WARNING!] IsPointInside malfunctioned "..MALFUNCTIONS..' times out of '..OUT_OF)
    end
    return closestRegion
end

function Region.GetClosestByVertex(element, regions)
    local minDistance = 9999999;
    local closestRegion = nil
    for k,r in ipairs(regions) do
        local distance = math.abs(r:GetDistanceByNormal(element.position))
        if distance < minDistance then
            minDistance = distance
            closestRegion = r
        end
    end
    return closestRegion
end

function Region:SetRandomStaticCamera()
    if STATIC_CAMERA and self.cameras and #self.cameras > 0 then
        local cameraPos = PickRandom(self.cameras)
        local story = CURRENT_STORY
        for _, spectator in ipairs(story.Spectators) do
            spectator:setCameraMatrix(cameraPos.x, cameraPos.y, cameraPos.z, cameraPos.lx, cameraPos.ly, cameraPos.lz, cameraPos.roll, cameraPos.fov)
            -- print('CHANGING SPECTATORS INTERIORS AND POSITION to '..self.Episode.name)
            spectator.position = self.Episode.POI[1].position + Vector3(0,0,3)
            spectator.interior = self.Episode.InteriorId
        end
    end
end

function Region:AssignFocus()
    CURRENT_STORY.CurrentEpisode.CurrentRegion = self
    CURRENT_STORY.CurrentFocusedEpisode = self.Episode
    self:SetRandomStaticCamera()
end

function Region:OnPlayerHit(player)
    if player:getData('storyEnded') or not player:getData('isPed') then
        return
    end
    if DEBUG then
        outputConsole('[Region]:OnPlayerHit - '..self.name)
        print('[Region]:OnPlayerHit - '..self.name)
    end
    player:setData('currentRegion', self.name)
    player:setData('currentRegionId', self.Id)
    player:setData('currentEpisode', self.Episode.name)

    if DEBUG then
        print("["..player:getData('id').."] Set 'currentRegion' to "..(player:getData('currentRegion') or 'null').." 'currentRegionId' to "..(player:getData('currentRegionId') or 'null').." 'currentEpisode' to "..(player:getData('currentEpisode') or 'null'))
    end
    local story = CURRENT_STORY

    if self.EvaluatingRegion then
        return
    end
    if CURRENT_STORY.CurrentEpisode.CurrentRegion == self then
        return
    end

    self.EvaluatingRegion = true
    --delay so that all the regionHit events are processed
    -- Timer(function()
        local actorsInRegions = {}
        local maxValue = 0

        local maxRegionId = self.Id

        for _,ped in ipairs(CURRENT_STORY.CurrentEpisode.peds) do
            local rid = ped:getData('currentRegionId')
            if rid then
                local region = FirstOrDefault(CURRENT_STORY.CurrentEpisode.Regions, function(r) return r.Id == rid end)
                if not actorsInRegions[rid] then
                    actorsInRegions[rid] = {ped}
                else
                    table.insert(actorsInRegions[rid], ped)
                end
                if #actorsInRegions[rid] > maxValue or PRIORITIZE_CAMERA and PRIORITIZE_CAMERA == region.name then
                    maxValue = #actorsInRegions[rid]
                    maxRegionId = rid
                end
            end
        end

        local logger = FirstOrDefault(story.Loggers)
        if logger ~= nil then
            --If the region is not explored then describe the objects in it
            --if there are some players that weren't introduced before, then describe them
            local actorsDescription = logger:DescribeRegion(self.name, actorsInRegions[self.Id])
            if actorsDescription then
                logger:AddEnvironmentDescription(actorsDescription)
            end
            if not self.isExplored then
                local pointOfView = player.position
                local pointOfViewForward = player.matrix.forward
                if STATIC_CAMERA and player:getData('hasFocus') then
                    local x, y, z, lx, ly, lz = logger.Spectator:getCameraMatrix()
                    pointOfView = Vector3(x,y,z)
                    pointOfViewForward = Vector3(lx,ly,lz) - pointOfView
                else
                    pointOfView = Vector3(player.position.x, player.position.y, player.position.z + 1)
                    pointOfViewForward = player.matrix.forward
                end
                local locationMap = self:MapObjectsAndPedsLocations(pointOfView, pointOfViewForward, player.matrix.up)

                self.isExplored = true
                --describe it here
                -- if self.Description and self.Description ~= '' then
                --     logger:Log(self.Description, player, true)
                -- end
                if self.Objects and #self.Objects > 0 then
                    local objectsDescription = logger:DescribeObjects(player, self.name, self.Objects, locationMap, true)
                    logger:AddEnvironmentDescription(objectsDescription)
                end
            end
        else
            print("Could not find a logger for actor "..player:getData('id'..'!'))
        end

        self.EvaluatingRegion = false
    -- end, 100, 1, player)
end