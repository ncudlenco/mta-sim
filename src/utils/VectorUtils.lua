VectorUtils = {}

VectorUtils.Rotate = function (self, rotation)
    local yaw = math.rad(rotation.z);
    local pitch = math.rad(rotation.y);
    local roll = math.rad(rotation.x);

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

function VectorUtils.angle(vec1, vec2)
    local len1 = vec1.length
    local len2 = vec2.length
    local denominator = len1 * len2

    -- Handle near-zero length vectors
    if denominator < 0.0001 then
        return 0
    end

    local cosAngle = vec1:dot(vec2) / denominator

    -- Clamp to [-1, 1] to handle floating-point errors
    cosAngle = math.max(-1, math.min(1, cosAngle))

    return math.acos(cosAngle)
end

Vector3.angle = VectorUtils.angle

function VectorUtils.signedAngle(me, other, normal)
    local angle = me:angle(other)
    local cross = me:cross(other)
    if normal:dot(cross) < 0 then
        angle = -angle;
    end
    return angle;
end
Vector3.signedAngle = VectorUtils.signedAngle

function VectorUtils.projectOnAxis(me, axis)
    local axisMagnitude = axis.length
    local multValue = me:dot(axis) / (axisMagnitude * axisMagnitude)
    return Vector3(axis.x * multValue, axis.y * multValue, axis.z * multValue)
end
Vector3.projectOnAxis = VectorUtils.projectOnAxis

function VectorUtils.projectOnPlane(me, normal)
    return me - me:projectOnAxis(normal)
end
Vector3.projectOnPlane = VectorUtils.projectOnPlane

--Returns the angle between two vectors around a given axis
function VectorUtils.angleAboutAxis(me, other, axis)
    axis = axis:getNormalized()
    return me:projectOnPlane(axis):signedAngle(other:projectOnPlane(axis), axis)
end
Vector3.angleAboutAxis = VectorUtils.angleAboutAxis


--- Rotates a vector around an axis by a given angle
---@param me table
---@param axis table
---@param angle number
---@return table
function VectorUtils.rotateAroundAxis(me, axis, angle)
    local cosTheta = math.cos(angle)
    local sinTheta = math.sin(angle)
    local dot = me:dot(axis)
    return Vector3(
        cosTheta * me.x + sinTheta * (axis.y * me.z - axis.z * me.y) + (1 - cosTheta) * dot * axis.x,
        cosTheta * me.y + sinTheta * (axis.z * me.x - axis.x * me.z) + (1 - cosTheta) * dot * axis.y,
        cosTheta * me.z + sinTheta * (axis.x * me.y - axis.y * me.x) + (1 - cosTheta) * dot * axis.z
    )
end
Vector3.rotateAroundAxis = VectorUtils.rotateAroundAxis