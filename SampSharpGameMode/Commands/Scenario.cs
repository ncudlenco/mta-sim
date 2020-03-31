//using SampSharp.Cimulator;
using SampSharp.GameMode;
using SampSharp.GameMode.SAMP.Commands;
using SampSharp.Streamer;
using SampSharp.Streamer.World;
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;
using System.Linq;
using SampSharp.ColAndreas;
using SampSharp.SyntheticGameMode.Story;
using Objects = SampSharp.SyntheticGameMode.Story.Objects;
using SampSharp.SyntheticGameMode.Enums;

namespace SampSharp.SyntheticGameMode.Commands
{
    [CommandGroup("scenario")]
    public class Scenario
    {
        public static readonly List<int> TOWELLS = new List<int> { 1640, 1641, 1642, 1643 };

        [Command("goto", "beach")]
        private static async void RunBeachScenario(Player player, string location)
        {
            await Task.Delay(100);
            switch (location)
            {
                case "beach":
                    SpawnPoint.SetPlayerSpawnPoint(player, (int)City.LosSantos, 32);
                    break;
                default:
                    break;
            }
        }

        [Command("animation", "sleep")]
        private static void ApplyAnimations(Player player, string param)
        {
            switch (param)
            {
                case "sleep":
                    player.ApplyAnimation("BEACH", "Lay_Bac_Loop", 4.1f, true, false, false, false, int.MaxValue);
                    break;
                case "end":
                    player.ClearAnimations();
                    break;
                default:
                    break;
            }
        }

        [Command("getCoordinates")]
        private static async void GetCoordinates(Player player)
        {
            await Task.Delay(100);
            player.SendClientMessage("coordinates: " + player.Position.ToString() + " angle: " + player.Angle.ToString());
        }

        [Command("placeonground")]
        private static async void PlaceOnGround(Player player, string objectType)
        {
            await Task.Delay(100);
            foreach (var item in DynamicObject.All)
            {
                item.Dispose();
            }
            await Task.Delay(100);
            var modelId = 0;
            if (objectType == "towel")
            {
                modelId = Objects.Towel.TOWELL_IDS.PickRandom();
            }
            else if(objectType == "lounger")
            {
                modelId = Objects.BeachLounger.BEACH_LOUNGER_IDS.PickRandom();
            }
            var position = player.GetXYAroundPlayer(1);
            var colAndreas = BaseMode.Instance.Services.GetService<ColAndreas.ColAndreas>();
            position = colAndreas.FindZ_For2DCoord(position);
            double zCoords = position.Z + 0.05;
            Vector3 min, max;
            if (colAndreas.GetModelBoundingBox(modelId, out min, out max) && (!min.IsEmpty || !max.IsEmpty))
            {
                //zCoords = max.Z;
            }
            position = new Vector3(position.X, position.Y, zCoords);
            var rotation = colAndreas.GetGroundRotation(position);
            rotation = new Vector3(rotation.X, rotation.Y, player.Angle);
            player.SendClientMessage("The rotation is " + rotation);
            await Task.Delay(100);
            var towell = new DynamicObject(modelId, position, rotation);
            var streamer = BaseMode.Instance.Services.GetService<IStreamer>();
            streamer.ProcessActiveItems();
            player.OnUpdate(new SampSharp.GameMode.Events.PlayerUpdateEventArgs() { PreventPropagation = false });
            streamer.Update(player, player.Position);
        }

        [Command("end")]
        private static void End(Player player)
        {
            foreach (var item in DynamicObject.All)
            {
                item.Dispose();
            }
            var streamer = BaseMode.Instance.Services.GetService<IStreamer>();
            streamer.Update(player, player.Position);
        }
    }
}
