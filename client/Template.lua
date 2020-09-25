Template = class(function(o, params)
    o.poi = params.poi or params.POI or nil
    o.objects = params.objects or params.Objects or {}
    o.locations = params.locations or params.Locations or {}
    o.position = Vector3(o.poi.X, o.poi.Y, o.poi.Z)
end)

function Template:Instantiate(interior, position)
    self.poi.instance = Marker(position.x, position.y, position.z - 1, "cylinder", 1, 255, 0, 255, 128)
    self.poi.instance.interior = interior

    for _,o in pairs(self.objects) do
        local obj = loadstring(o.dynamicString)()
        obj.interior = interior
        obj.position = position + obj.position
        obj:Create()
        o.instance = obj.instance
    end

    for _,p in pairs(self.locations) do
        local relativelyMoved = position + Vector3(p.X, p.Y, p.Z)
        p.instance = Marker(relativelyMoved.x, relativelyMoved.y, relativelyMoved.z - 1, "cylinder", 1, 0, 255, 255, 128)
        p.interior = interior
    end
end

function Template:UpdatePosition(translation, rotation, relativePosition)
    if not self.poi.instance then
        return false
    end
    if translation then
        self.poi.instance.position = self.poi.instance.position + translation
    elseif rotation then
        self.poi.Angle = self.poi.Angle + rotation.z
        if relativePosition then
            local p = self.poi.instance.position - relativePosition
            p = p:Rotate(rotation)
            p = p + relativePosition
            self.poi.instance.position = p
        end
    end
    if not relativePosition then
        relativePosition = self.poi.instance.position
    end
    self.X = self.poi.instance.position.x
    self.Y = self.poi.instance.position.y
    self.Z = self.poi.instance.position.z
    if self.objects then
        for _,v in pairs(self.objects) do
            if v.instance then
                if translation then
                    v.instance.position = v.instance.position + translation
                elseif rotation then
                    v.instance.rotation = v.instance.rotation + rotation
                    local p = v.instance.position - relativePosition
                    p = p:Rotate(rotation)
                    p = p + relativePosition
                    v.instance.position = p
                end
            end
        end
    end
    if self.locations then
        for _,v in pairs(self.locations) do
            if v.instance then
                if translation then
                    v.instance.position = v.instance.position + translation
                elseif rotation then
                    local p = v.instance.position - relativePosition
                    p = p:Rotate(rotation)
                    p = p + relativePosition
                    v.instance.position = p
                end
            end
        end
    end
end