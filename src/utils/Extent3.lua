Extent3 = class(function(o, min, max)
    o.Min = min
    o.Max = max
    o.CoordinateOrigin = Vector3(0,0,0)
end)

function Extent3:GetCenter()
    return Vector3((self.Min.x + self.Max.x) / 2, (self.Min.y + self.Max.y) / 2, (self.Min.z + self.Max.z) / 2)
end

function Extent3:ChangeOrigin(newOrigin, rotation)
    self.Min = self.Min - CoordinateOrigin
    self.Max = self.Max - CoordinateOrigin

    self.Min = self.Min:Rotate(rotation)
    self.Max = self.Max:Rotate(rotation)
    self.Min = self.Min + newOrigin
    self.Max = self.Max + newOrigin

    self.CoordinateOrigin = newOrigin
end