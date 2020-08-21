VectorUtils = {}

VectorUtils.Rotate = function (self, rotation)
    local yaw = rotation.z;
    local pitch = rotation.y;
    local roll = rotation.x;

    local cosa = math.cos(yaw);
    local sina = math.sin(yaw);

    local cosb = math.cos(pitch);
    local sinb = math.sin(pitch);

    local cosg = math.cos(roll);
    local sing = math.sin(roll);

    local Axx = cosa * cosb;
    local Axy = cosa * sinb * sing - sina * cosg;
    local Axz = cosa * sinb * cosg + sina * sing;

    local Ayx = sina * cosb;
    local Ayy = sina * sinb * sing + cosa * cosg;
    local Ayz = sina * sinb * cosg - cosa * sing;

    local Azx = -sinb;
    local Azy = cosb * sing;
    local Azz = cosb * cosg;

    local px = self.x;
    local py = self.y;
    local pz = self.z;

    local x = Axx * px + Axy * py + Axz * pz;
    local y = Ayx * px + Ayy * py + Ayz * pz;
    local z = Azx * px + Azy * py + Azz * pz;

    return Vector3(x, y, z);
end

Vector3.Rotate = VectorUtils.Rotate

function Vector3:unpack( )
    return { x=self.x, y=self.y, z=self.z }
end

function Vector3:__tostring()
    return "("..self.x..", "..self.y..", "..self.z..")"
end