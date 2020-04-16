using SampSharp.GameMode;
using SampSharpGameMode.Extensions;
using System;
using System.Collections.Generic;
using System.Text;

namespace SampSharp.SyntheticGameMode.Data
{
    public class Extent3
    {
        public Vector3 Min { get; set; }
        public Vector3 Max { get; set; }
        private Vector3 CoordinateOrigin = new Vector3();
        public Vector3 Center => new Vector3((Min.X + Max.X) / 2, (Min.Y + Max.Y) / 2, (Min.Z + Max.Z) / 2);
        public void ChangeOrigin(Vector3 newOrigin, Vector3 rotation)
        {
            Min -= CoordinateOrigin;
            Max -= CoordinateOrigin;

            Min = Min.Rotate(rotation);
            Max = Max.Rotate(rotation);
            Min += newOrigin;
            Max += newOrigin;

            CoordinateOrigin = newOrigin;
            CoordinateOrigin = newOrigin;
        }
    }
}
