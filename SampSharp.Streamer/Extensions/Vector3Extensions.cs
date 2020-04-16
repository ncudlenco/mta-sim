using SampSharp.GameMode;
using System;
using System.Collections.Generic;
using System.Text;

namespace SampSharpGameMode.Extensions
{
    public static class Vector3Extensions
    {
        public static Vector3 GetGlobalXaxis(this Vector3 me)
        {
            return new Vector3(1, 0, 0);
        }

        public static Vector3 GetGlobalYaxis(this Vector3 me)
        {
            return new Vector3(0, 1, 0);
        }

        public static Vector3 GetGlobalZaxis(this Vector3 me)
        {
            return new Vector3(0, 0, 1);
        }

        public static Vector3 CrossProduct(this Vector3 me, Vector3 other)
        {
            return new Vector3(me.Y * other.Z - me.Z * other.Y, me.Z * other.X - me.X * other.Z, me.X * other.Y - me.Y - other.Z);
        }

        public static double AngleTo(this Vector3 me, Vector3 other)
        {
            var cosAlpha = me.DotProduct(other) / (me.Magnitude() * other.Magnitude());
            //Decimal corrections
            if (cosAlpha > 1)
            {
                cosAlpha = 1;
            }
            if (cosAlpha < -1)
            {
                cosAlpha = -1;
            }
            return Math.Acos(cosAlpha);
        }

        public static double SignedAngleTo(this Vector3 me, Vector3 other, Vector3 normal)
        {
            var angle = me.AngleTo(other);
            var cross = me.CrossProduct(other);
            if (normal.DotProduct(cross) < 0)
            {
                angle = -angle;
            }
            return angle;
        }

        public static double Magnitude(this Vector3 me)
        {
            return Math.Sqrt(me.X * me.X + me.Y * me.Y + me.Z * me.Z);
        }

        public static double DotProduct(this Vector3 me, Vector3 other)
        {
            return me.X * other.X + me.Y * other.Y + me.Z * other.Z;
        }

        public static Vector3 ProjectOnAxis(this Vector3 me, Vector3 axis)
        {
            var axisMagnitude = axis.Magnitude();
            return axis.Mult(me.DotProduct(axis) / (axisMagnitude * axisMagnitude));
        }

        public static Vector3 ProjectOnPlane(this Vector3 me, Vector3 normal)
        {
            return me - ProjectOnAxis(me, normal);
        }

        public static Vector3 Mult(this Vector3 me, double value)
        {
            return new Vector3(me.X * value, me.Y * value, me.Z * value);
        }

        //Returns the angle between two vectors around a given axis
        public static double AngleAboutAxisTo(this Vector3 me, Vector3 other, Vector3 axis)
        {
            axis = axis.Normalized();
            return me.ProjectOnPlane(axis).SignedAngleTo(other.ProjectOnPlane(axis), axis);
        }

        public static Vector3 Rotate(this Vector3 me, Vector3 rotation)
        {
            var yaw = rotation.Z;
            var pitch = rotation.Y;
            var roll = rotation.X;

            var cosa = Math.Cos(yaw);
            var sina = Math.Sin(yaw);

            var cosb = Math.Cos(pitch);
            var sinb = Math.Sin(pitch);

            var cosg = Math.Cos(roll);
            var sing = Math.Sin(roll);

            var Axx = cosa * cosb;
            var Axy = cosa * sinb * sing - sina * cosg;
            var Axz = cosa * sinb * cosg + sina * sing;

            var Ayx = sina * cosb;
            var Ayy = sina * sinb * sing + cosa * cosg;
            var Ayz = sina * sinb * cosg - cosa * sing;

            var Azx = -sinb;
            var Azy = cosb * sing;
            var Azz = cosb * cosg;

            var px = me.X;
            var py = me.Y;
            var pz = me.Z;

            var x = Axx * px + Axy * py + Axz * pz;
            var y = Ayx * px + Ayy * py + Ayz * pz;
            var z = Azx * px + Azy * py + Azz * pz;

            return new Vector3(x, y, z);
        }

        public static string ToString(this Vector3 me)
        {
            return me.X + " " + me.Y + " " + me.Z;
        }

    }
}
