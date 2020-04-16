using SampSharp.GameMode;
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
            Type2 = 3000,
            Type3 = 1598,
            Type4 = 2995,
            Type5 = 3100
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

        public static void ClearDebugObjects()
        {
            foreach (DynamicObject item in DEBUG_OBJECTS)
            {
                item.Dispose();
            }
        }
    }
}
