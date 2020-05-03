using SampSharp.GameMode;
using SampSharp.GameMode.Helpers;
using SampSharp.Streamer;
using SampSharp.Streamer.World;
using SampSharp.SyntheticGameMode.Story;
using System;
using System.Collections.Generic;
using System.Text;

namespace SampSharp.SyntheticGameMode.Data
{
    public static class Debug
    {
        public enum ePointType
        {
            Type1 = 1946,
            Type2 = 1598,
        }
        public static List<DynamicObject> DEBUG_OBJECTS = new List<DynamicObject>();
        public static void DrawPoint(Player player, Vector3 point, ePointType pointType = ePointType.Type1)
        {
            var ball = new DynamicObject((int)pointType, point, new Vector3());
            var streamer = BaseMode.Instance.Services.GetService<IStreamer>();
            streamer.ProcessActiveItems();
            player.OnUpdate(new SampSharp.GameMode.Events.PlayerUpdateEventArgs() { PreventPropagation = false });
            streamer.Update(player, player.Position);
            DEBUG_OBJECTS.Add(ball);
        }

        public static void DrawVector(Player player, Vector3 vector, Vector3 origin)
        {
            var ball = new DynamicObject((int)ePointType.Type1, origin, new Vector3());
            var vv = vector - origin;
            var angle = (float)Math.Atan2(vv.Y, vv.X);
            var cue = new DynamicObject(19631, origin, new Vector3(0, 180, MathHelper.ToDegrees(angle)));

            var streamer = BaseMode.Instance.Services.GetService<IStreamer>();
            streamer.ProcessActiveItems();
            player.OnUpdate(new SampSharp.GameMode.Events.PlayerUpdateEventArgs() { PreventPropagation = false });
            streamer.Update(player, player.Position);
            DEBUG_OBJECTS.Add(ball);
            DEBUG_OBJECTS.Add(cue);
        }

        public static void ClearDebugObjects()
        {
            foreach (DynamicObject item in DEBUG_OBJECTS)
            {
                item.Dispose();
            }
        }
    }
}
