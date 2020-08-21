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
end)

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
        --If point is in the polygon
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

function Region.GetClosest(element, regions, isInstance)
    local minDistance = 9999999;
    for k,r in ipairs(regions) do
        if (isInstance and element and isElementWithinColShape(element, r.instance)) or r:IsPointInsideConvex(element.position) then
            local distance = math.abs((element.position - Vector3(r.center.x, r.center.y, r.center.z)).length)
            if distance < minDistance then
                minDistance = distance
                closestRegion = r
            end
        end
    end
    return closestRegion
end

function Region:OnPlayerHit(player)
    local story = GetStory(player)

    player:setData('currentRegion', self.name)
    if self.isExplored then
        return
    else
        if self.Episode and (not self.Objects or #self.Objects == 0) then
            for i,o in ipairs(self.Episode.Objects) do
                if o.instance then
                    local r = Region.GetClosest(o, self.Episode.Regions, false)
                    if r == self then
                        table.insert(self.Objects, o)
                    end
                end
            end
        end
        self.isExplored = true
        --describe it here
        if self.Description and self.Description ~= '' then
            story.Logger:Log(self.Description, player, true)
        elseif self.Objects and #self.Objects > 0 then
            local objectsDescription = story.Logger:DescribeObjects(self.Objects)
            story.Logger:Log("In the " .. self.name .. " there was " .. objectsDescription, player, true)
        end
    end
--TODO: change the current camera and so on and so forth
end