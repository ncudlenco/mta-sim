using System;
using System.Collections.Generic;
using System.Text;

namespace SampSharpGameMode.Utils
{
    public static class MathUtils
    {
        public static double ToDegrees(double radians)
        {
            return radians * 180 / Math.PI;
        }

        public static double ToRadians(double degrees)
        {
            return degrees * Math.PI / 180;
        }
    }
}
