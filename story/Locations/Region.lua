Region = class(function(o, params)
    o.name = params.name or ""
    o.Description = params.Description or params.description or ""
    o.instance = nil
    o.vertexes = params.vertexes or {}
    o.center = params.center or nil
    o.isExplored = params.isExplored or false
    o.Episode = nil
    o.Id = Guid().Id
    o.Objects = {}
end)

function Region:__tostring()
    return self.name
  end

function Region:__eq(other)
    return other and other:is_a(Region) and self.Id == other.Id
end

function Region.GetClosest(element, regions)
    local minDistance = 9999999;
    local closestRegion = nil;
    for k,r in ipairs(regions) do
        if isElementWithinColShape(element, r.instance) then
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
            self.Objects = {}
            for i,o in ipairs(self.Episode.Objects) do
                if o.instance then
                    local r = Region.GetClosest(o.instance, self.Episode.Regions)
                    if r == self then
                        table.insert(self.Objects, o)
                    end
                end
            end
        end
        self.isExplored = true
        --describe it here
        if self.Description and self.Description ~= '' then
            story.Logger:Log(self.Description, player)
        elseif self.Objects and #self.Objects > 0 then
            local objectsDescription = story.Logger:DescribeObjects(self.Objects)
            story.Logger:Log("In the " .. self.name .. " was " .. objectsDescription, player)
        end
    end
--TODO: change the current camera and so on and so forth
end