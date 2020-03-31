using System;
using SampSharp.Core.Natives.NativeObjects;

namespace SampSharp.Cimulator
{
    public partial class Cimulator
    {
        protected static CimulatorInternal Internal;
        protected const int ACTIVE_TAG = 1;

        static Cimulator()
        {
            Internal = NativeObjectProxyFactory.CreateInstance<CimulatorInternal>();
        }

        public class CimulatorInternal
        {
            /*
             * stops the simulation
             */
            [NativeMethod(Function = "CR_EnableSimulation")]
            public virtual int CR_EnableSimulation()
            {
                throw new NativeNotImplementedException();
            }

            [NativeMethod(Function = "CR_Load")]
            public virtual int CR_Load(float worldrest = 0.0f)
            {
                throw new NativeNotImplementedException();
            }

            [NativeMethod(Function = "CR_SetWorldGravity")]
            public virtual int CR_SetWorldGravity(float x, float y, float z)
            {
                throw new NativeNotImplementedException();
            }

            [NativeMethod(Function = "CR_CreateDynamicCol")]
            public virtual int CR_CreateDynamicCol(int objectid, int modelid, float mass, float x, float y, float z, float yaw, float pitch, float roll, int inertia = 0, int tag = ACTIVE_TAG)
            {
                throw new NativeNotImplementedException();
            }

            [NativeMethod(Function = "CR_RemoveDynamicCol")]
            public virtual int CR_RemoveDynamicCol(int index)
            {
                throw new NativeNotImplementedException();
            }

            [NativeMethod(Function = "CR_SetLinearVelocity")]
            public virtual int CR_SetLinearVelocity(int index, float vx, float vy, float vz)
            {
                throw new NativeNotImplementedException();
            }

            /*
             * returns the axi-aligned bounding box of the modelid
             */
            [NativeMethod(Function = "CR_GetAABB")]
            public virtual int CR_GetAABB(int modelid, float x, float y, float z, float yaw, float pitch, float roll, out float minx, out float miny, out float minz, out float maxx, out float maxy, out float maxz)
            {
                throw new NativeNotImplementedException();
            }
            /*
             * shoots an invisible ray to a specified destination, returns the normal of the hit point if collided
             */
            [NativeMethod(Function = "CR_RayCast")]
            public virtual int CR_RayCast(float x1, float y1, float z1, float x2, float y2, float z2, out float x3, out float y3, out float z3)
            {
                throw new NativeNotImplementedException();
            }
        }
    }
}
