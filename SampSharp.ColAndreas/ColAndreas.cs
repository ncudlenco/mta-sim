using SampSharp.GameMode;
using SampSharp.GameMode.Helpers;
using SampSharp.GameMode.World;
using SampSharp.Streamer.World;
using SampSharpGameMode.Extensions;
using SampSharpGameMode.Utils;
using System;

namespace SampSharp.ColAndreas
{
    public partial class ColAndreas : IService
    {
        public BaseMode GameMode { get; set; }

        public ColAndreas(BaseMode baseMode)
        {
            this.GameMode = baseMode;
            baseMode.Services.AddService(this);
            this.Init();
        }

        public Vector3 RayCastLine(Vector3 startPoint, Vector3 endPoint)
        {
            float x, y, z;
            Internal.CA_RayCastLine(startPoint.X, startPoint.Y, startPoint.Z, endPoint.X, endPoint.Y, endPoint.Z, out x, out y, out z);
            return new Vector3(x, y, z);
        }

        public Vector3 FindZ_For2DCoord(Vector2 coordinates)
        {
            float x,y,z;
            Internal.CA_FindZ_For2DCoord(coordinates.X, coordinates.Y, out x, out y, out z);
            return new Vector3(x, y, z);
        }

        public Vector3 FindZ_For2DCoord(Vector3 coordinates)
        {
            float x,y,z;
            Internal.CA_FindZ_For2DCoord(coordinates.X, coordinates.Y, out x, out y, out z);
            return new Vector3(x, y, z);
        }

        public void Init()
        {
            Internal.CA_Init();
        }

        public bool GetModelBoundingBox(int modelId, out Vector3 min, out Vector3 max)
        {
            float minx, miny, minz, maxx, maxy, maxz;
            var res = Internal.CA_GetModelBoundingBox(modelId, out minx, out miny, out minz, out maxx, out maxy, out maxz);
            min = new Vector3(minx, miny, minz);
            max = new Vector3(maxx, maxy, maxz);
            return res == 1;
        }

        public Vector3 AlignObjectWithGround(int modelId, Vector3 position)
        {
            Vector3 min, max;
            Vector3 rotation = new Vector3();
            if (GetModelBoundingBox(modelId, out min, out max) && (!min.IsEmpty || !max.IsEmpty))
            {
                //Bring the min, max coordinates in the object coordinates
                min = position + min;
                max = position + max;

                //compute the min, max intersections on the x plane
                return GetGroundRotation(min, max);
            }
            return rotation;
        }

        public Vector3 GetGroundRotation(Vector3 position)
        {
            var p1 = FindZ_For2DCoord(new Vector3(position.X, position.Y - 1, position.Z));
            var p2 = FindZ_For2DCoord(new Vector3(position.X, position.Y + 1, position.Z));

            var alignmentX = p2 - p1;
            var xRotation = alignmentX.AngleAboutAxisTo(alignmentX.GetGlobalYaxis(), alignmentX.GetGlobalXaxis());

            var p3 = FindZ_For2DCoord(new Vector3(position.X - 1, position.Y, position.Z));
            var p4 = FindZ_For2DCoord(new Vector3(position.X + 1, position.Y, position.Z));

            var alignmentY = p4 - p3;
            var yRotation = alignmentY.AngleAboutAxisTo(alignmentY.GetGlobalXaxis(), alignmentY.GetGlobalYaxis());

            var rotation = new Vector3(-MathUtils.ToDegrees(xRotation), -MathUtils.ToDegrees(yRotation));
            return rotation;
        }

        public Vector3 GetGroundRotation(Vector3 startPoint, Vector3 endPoint)
        {
            var minIntersection = FindZ_For2DCoord(startPoint);
            var maxIntersection = FindZ_For2DCoord(endPoint);

            var vector = maxIntersection - minIntersection;
            //yOz normal
            var xAxis = new Vector3(1, 0, 0);
            var yAxis = new Vector3(0, 1, 0);

            var xRotation = MathUtils.ToDegrees(vector.AngleAboutAxisTo(yAxis, xAxis));
            var yRotation = MathUtils.ToDegrees(vector.AngleAboutAxisTo(xAxis, yAxis));
            return new Vector3(180 - xRotation, yRotation);
        }

        public DynamicObject CreateObjectOnGround(int modelId, Vector3 position)
        {
            position = FindZ_For2DCoord(position);
            var rotation = AlignObjectWithGround(modelId, position);
            return new DynamicObject(modelId, position, rotation);
        }

        public int CreateObjectCollision(int modelId, Vector3 position, Vector3 rotation)
        {
            return Internal.CA_CreateObject(modelId, position.X, position.Y, position.Z, rotation.X, rotation.Y, rotation.Z, true);
        }

        public int DestroyObjectWithCollision(int collisionId)
        {
            return Internal.CA_DestroyObject(collisionId);
        }


//        /**--------------------------------------------------------------------------**\
//<summary>
//            CA_IsPlayerInWater
//</summary>
//<param name="playerid">The playerid to check</param>
//<param name="&Float:depth">The depth</param>
//<param name="&Float:playerdepth">The depth of the player</param>
//<returns>
//            0 if the player is not in water
//            1 if the player is in water
//</returns>
//\**--------------------------------------------------------------------------**/
//        public bool IsPlayerInWater(BasePlayer player, out float depth, out float playerdepth)
//        {
//            new Float:x, Float: y, Float: z, Float: retx[10], Float: rety[10], Float: retz[10], Float: retdist[10], modelids[10];
//            GetPlayerPos(playerid, x, y, z);
//            new collisions = CA_RayCastMultiLine(x, y, z + 1000.0, x, y, z - 1000.0, retx, rety, retz, retdist, modelids, 10);
//            if (collisions > 0)
//            {
//                for (new i = 0; i < collisions; i++)
//                {
//                    if (modelids[i] == WATER_OBJECT)
//                    {
//                        depth = FLOAT_INFINITY;

//                        for (new j = 0; j < collisions; j++)
//                        {
//                            if (retz[j] < depth)
//                                depth = retz[j];
//                        }

//                        depth = retz[i] - depth;
//                        if (depth < 0.001 && depth > -0.001)
//                            depth = 100.0;
//                        playerdepth = retz[i] - z;

//                        if (playerdepth < -2.0)
//                            return 0;

//                        return 1;
//                    }
//                }
//            }
//            return 0;
//        }

//        /**--------------------------------------------------------------------------**\
//<summary>
//            CA_IsPlayerNearWater
//</summary>
//<param name="playerid">The playerid to check</param>
//<param name="Float:dist = 3.0">The distance to check for water</param>
//<param name="Float:height = 3.0">The height the player can be from the water</param>
//<returns>
//            0 if the player is not in water
//            1 if the player is in water
//</returns>
//<remarks>
//            Checks for water all around the player
//</remarks>
//\**--------------------------------------------------------------------------**/
//        stock CA_IsPlayerNearWater(playerid, Float:dist= 3.0, Float:height= 3.0)
//        {
//            new Float:x, Float: y, Float: z, Float: tmp;
//            GetPlayerPos(playerid, x, y, z);

//            for (new i; i < 6; i++)
//                if (CA_RayCastLine(x + (dist * floatsin(i * 60.0, degrees)), y + (dist * floatcos(i * 60.0, degrees)), z + height, x + (dist * floatsin(i * 60.0, degrees)), y + (dist * floatcos(i * 60.0, degrees)), z - height, tmp, tmp, tmp) == WATER_OBJECT)
//                    return 1;
//            return 0;
//        }

//        /**--------------------------------------------------------------------------**\
//<summary>
//            CA_IsPlayerFacingWater
//</summary>
//<param name="playerid">The playerid to check</param>
//<param name="Float:dist = 3.0">The distance to check for water</param>
//<param name="Float:height = 3.0">The height the player can be from the water</param>
//<returns>
//            0 if the player is not in water
//            1 if the player is in water
//</returns>
//<remarks>
//            Checks for water only in front of the player
//</remarks>
//\**--------------------------------------------------------------------------**/
//        stock CA_IsPlayerFacingWater(playerid, Float:dist= 3.0, Float:height= 3.0)
//        {
//            new Float:x, Float: y, Float: z, Float: r, Float: tmp;
//            GetPlayerPos(playerid, x, y, z);
//            GetPlayerFacingAngle(playerid, r);

//            if (CA_RayCastLine(x + (dist * floatsin(-r, degrees)), y + (dist * floatcos(-r, degrees)), z, x + (dist * floatsin(-r, degrees)), y + (dist * floatcos(-r, degrees)), z - height, tmp, tmp, tmp) == WATER_OBJECT)
//                return 1;
//            return 0;
//        }

//        /**--------------------------------------------------------------------------**\
//<summary>
//            CA_IsPlayerBlocked
//</summary>
//<param name="playerid">The playerid to check</param>
//<param name="Float:dist = 1.5">The distance to check for a wall</param>
//<param name="Float:height = 0.5">The height the wall can be from the ground</param>
//<returns>
//            0 if the player is not blocked
//            1 if the player is blocked
//</returns>
//\**--------------------------------------------------------------------------**/
//        stock CA_IsPlayerBlocked(playerid, Float:dist= 1.5, Float:height= 0.5)
//        {
//            new Float:x, Float: y, Float: z, Float: endx, Float: endy, Float: fa;
//            GetPlayerPos(playerid, x, y, z);
//            z -= 1.0 + height;
//            GetPlayerFacingAngle(playerid, fa);

//            endx = (x + dist * floatsin(-fa, degrees));
//            endy = (y + dist * floatcos(-fa, degrees));
//            if (CA_RayCastLine(x, y, z, endx, endy, z, x, y, z))
//                return 1;
//            return 0;
//        }
    }
}
