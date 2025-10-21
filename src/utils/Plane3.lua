Plane3 = class(function(o, point, normal)
    o.origin = Vector3(point.x, point.y, point.z)
    o.normal = normal
    o.normal:normalize()
    o.a = o.normal.x
    o.b = o.normal.y
    o.c = o.normal.z
    o.d = -o.a * o.origin.x - o.b * o.origin.y - o.c * o.origin.z
end)

function Plane3:isPointOnPlane(point)
    return math.abs((point - self.origin):dot(self.normal)) < 0.01
end

function Plane3:distanceTo(point)
    return math.abs(self.a * point.x + self.b * point.y + self.c * point.z + self.d) / math.sqrt(self.a*self.a + self.b*self.b + self.c*self.c)
    -- local v = point - self.origin
    -- return v:dot(self.normal)
end

function Plane3:project(point)
    return point - self:distanceTo(point) * self.normal
end