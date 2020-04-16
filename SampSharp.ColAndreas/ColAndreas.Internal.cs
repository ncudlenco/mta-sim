using System;
using System.Collections.Generic;
using System.Text;
using SampSharp.Core.Natives.NativeObjects;

namespace SampSharp.ColAndreas
{
    public partial class ColAndreas
    {
        protected static ColAndreasInternal Internal;

        static ColAndreas()
        {
            Internal = NativeObjectProxyFactory.CreateInstance<ColAndreasInternal>();
        }

        public class ColAndreasInternal
        {
            [NativeMethod(Function = "CA_Init")]
            public virtual int CA_Init()
            {
                throw new NativeNotImplementedException();
            }

            [NativeMethod(Function = "CA_RayCastLine")]
            public virtual int CA_RayCastLine(float StartX, float StartY, float StartZ, float EndX, float EndY, float EndZ, out float x, out float y, out float z)
            {
                throw new NativeNotImplementedException();
            }

            public int CA_FindZ_For2DCoord(float x, float y, out float xx, out float yy, out float z)
            {
                if (CA_RayCastLine(x, y, 700.0f, x, y, -1000.0f, out xx, out yy, out z) != 0) return 1;
                return 0;
            }

            [NativeMethod(Function = "CA_GetModelBoundingBox")]
            public virtual int CA_GetModelBoundingBox(int modelid, out float minx, out float miny, out float minz, out float maxx, out float maxy, out float maxz)
            {
                throw new NativeNotImplementedException();
            }

            [NativeMethod(Function = "CA_CreateObject")]
            public virtual int CA_CreateObject(int modelid, float x, float y, float z, float rx, float ry, float rz, bool add)
            {
                throw new NativeNotImplementedException();
            }

            [NativeMethod(Function = "CA_DestroyObject")]
            public virtual int CA_DestroyObject(int idx)
            {
                throw new NativeNotImplementedException();
            }
        }
    }
}
