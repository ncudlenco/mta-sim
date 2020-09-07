Plane3 = class(function(o, point, normal)
    o.origin = Vector3(point.x, point.y, point.z)
    o.normal = normal
    o.normal:normalize()
end)

function Plane3:isPointOnPlane(point)
    return math.abs((point - self.origin):dot(self.normal)) < 0.01
end

function Plane3:distanceTo(point)
    local v = point - self.origin
    return v:dot(self.normal)
end

function Plane3:project(point)
    return point - self:distanceTo(point) * self.normal
end