using SampSharp.GameMode;
using SampSharp.GameMode.World;
using SampSharp.Streamer.World;
using System;
using System.Collections.Generic;
using System.Text;

namespace SampSharp.Cimulator
{
    public partial class Cimulator
    {
        public Cimulator()
        {

        }

        public static void EnableSimulation()
        {
            Internal.CR_EnableSimulation();
        }

        public static void Load()
        {
            Internal.CR_Load();
        }

        public static void SetWorldGravity(Vector3 gravity)
        {
            Internal.CR_SetWorldGravity(gravity.X, gravity.Y, gravity.Z);
        }

        public static void CreateDynamicColisionVolume(DynamicObject dynamicObject, float mass, Vector3 position, Vector3 yawPitchRoll, int inertia = 0)
        {
            Internal.CR_CreateDynamicCol(dynamicObject.Id, dynamicObject.ModelId, mass, position.X, position.Y, position.Z, yawPitchRoll.X, yawPitchRoll.Y, yawPitchRoll.Z, inertia);
        }

        public static void RemoveDynamicCol(DynamicObject dynamicObject)
        {
            dynamicObject.Dispose();
            Internal.CR_RemoveDynamicCol(dynamicObject.Id);
        }

        public static void SetLinearVelocity(DynamicObject dynamicObject, Vector3 velocity)
        {
            Internal.CR_SetLinearVelocity(dynamicObject.Id, velocity.X, velocity.Y, velocity.Z);
        }

        public static void GetAAB(DynamicObject dynamicObject, out Vector3 min, out Vector3 max)
        {
            float minx, miny, minz, maxx, maxy, maxz;
            Internal.CR_GetAABB(dynamicObject.ModelId, dynamicObject.Position.X, dynamicObject.Position.Y, dynamicObject.Position.Z, dynamicObject.Rotation.X, dynamicObject.Rotation.Y, dynamicObject.Rotation.Z,
                out minx, out miny, out minz, out maxx, out maxy, out maxz);
            min = new Vector3(minx, miny, minz);
            max = new Vector3(maxx, maxy, maxz);
        }

        public static bool RayCast(Vector3 source, Vector3 destination, out Vector3 collision)
        {
            float x, y, z;
            var result = Internal.CR_RayCast(source.X, source.Y, source.Z, destination.X, destination.Y, destination.Z, out x, out y, out z);
            collision = new Vector3(x, y, z);
            return result == 1;
        }

        // places an object on the ground correctly
        public static void PlaceObjectOnGround(DynamicObject dynamicObject)
        {
            Vector3 min, max;
            GetAAB(dynamicObject, out min, out max);

            float dz = MathF.Abs(dynamicObject.Position.Z - min.Z);
            Vector3 collision;
            if (RayCast(min, new Vector3(min.X, min.Y, -1000.0), out collision))
                dynamicObject.Position = new Vector3(dynamicObject.Position.X, dynamicObject.Position.Y, max.Z + dz);
        }
    }
}
