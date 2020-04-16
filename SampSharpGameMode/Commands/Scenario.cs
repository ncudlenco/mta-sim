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
using SampSharp.SyntheticGameMode.Extensions;
using SampSharp.SyntheticGameMode.Data;
using System.Windows.Forms;

namespace SampSharp.SyntheticGameMode.Commands
{
    [CommandGroup("scenario")]
    public class Scenario
    {
        public static readonly List<int> TOWELLS = new List<int> { 1640, 1641, 1642, 1643 };

        [Command("clear", "debug")]
        private static async void Clear(Player player, string what)
        {
            await Task.Delay(100);
            switch (what)
            {
                case "debug":
                    Debug.ClearDebugObjects();
                    break;
                default:
                    break;
            }
        }

        [Command("teleport")]
        private static async void Teleport(Player player, string where)
        {
            switch (where)
            {
                case "smbeach":
                    await Location.LosSantos[(int)CityLocation.SantaMariaBeach].SpawnPlayerHere();
                    break;
                default:
                    break;
            }
        }

        [Command("bed")]
        private static async void Bed(Player player, string what)
        {
            await Task.Delay(100);
            switch (what)
            {
                case "inL":
                    player.ApplyAnimation("INT_HOUSE", "BED_In_L", 4.1f, false, false, false, true, 3000, true);
                    break;
                case "sleepR":
                    player.ApplyAnimation("INT_HOUSE", "BED_Loop_R", 4.1f, false, false, false, true, 3000, true);
                    break;
                case "sleepL":
                    player.ApplyAnimation("INT_HOUSE", "BED_Loop_L", 4.1f, false, false, false, true, 3000, true);
                    player.Angle += 180;
                    break;
                case "outL":
                    player.ApplyAnimation("INT_HOUSE", "BED_Out_L", 4.1f, false, false, false, true, 3000, true);
                    player.Angle += 180;
                    break;
                case "outR":
                    player.ApplyAnimation("INT_HOUSE", "BED_Out_R", 4.1f, false, false, false, true, 3000, true);
                    break;
                default:
                    break;
            }
        }

        [Command("animation")]
        private static async void Animation(Player player, string what, string animLib, string animId, string loopstr, string lockXstr, string lockYstr, string freezestr, string forceSyncstr, string specialAction)
        {
            await Task.Delay(100);
            switch (what)
            {
                case "sit":
                    player.ApplyAnimation("MISC", "SEAT_LR", 4.1f, false, false, false, true, 3000, true);
                    break;
                case "getup":
                    player.ApplyAnimation("ped", "getup", 4.1f, false, false, false, true, 3000, true);
                    break;
                case "washHands":
                    player.ApplyAnimation("INT_HOUSE", "wash_up", 4.1f, false, false, false, true, 3000, true);
                    break;
                case "custom":
                    try
                    {
                        bool loop = Convert.ToBoolean(loopstr);
                        bool lockX = Convert.ToBoolean(lockXstr);
                        bool lockY = Convert.ToBoolean(lockYstr);
                        bool freeze = Convert.ToBoolean(freezestr);
                        bool forceSync = Convert.ToBoolean(forceSyncstr);
                        player.ApplyAnimation(animLib, animId, 4.1f, loop, lockX, lockY, freeze, 3000, forceSync);
                        await Task.Delay(100);
                        int specialActionId;
                        if (!string.IsNullOrEmpty(specialAction) && Int32.TryParse(specialAction, out specialActionId))
                        {
                            player.SpecialAction = GameMode.Definitions.SpecialAction.Sitting;
                            await Task.Delay(100);
                        }
                    }
                    catch (Exception ex)
                    {
                        player.SendClientMessage(ex.ToString());
                    }
                    break;
                default:
                    break;
            }
        }

        [Command("position")]
        private static async void Position(Player player, string what)
        {
            await Task.Delay(100);
            switch (what)
            {
                case "get":
                    Clipboard.SetText(player.Position.X + "," + player.Position.Y + "," + player.Position.Z + "," + player.Angle, TextDataFormat.Text);
                    player.SendClientMessage(player.Position.X + "," + player.Position.Y + "," + player.Position.Z + "," + player.Angle + " copied to clipboard");
                    break;
                case "up":
                    await Task.Delay(100);
                    player.Position = new Vector3(player.Position.X, player.Position.Y, player.Position.Z + 0.1);
                    player.SendClientMessage(player.Position.ToString());
                    break;
                case "down":
                    await Task.Delay(100);
                    player.Position = new Vector3(player.Position.X, player.Position.Y, player.Position.Z - 0.1);
                    player.SendClientMessage(player.Position.ToString());
                    break;
                case "backward":
                    await Task.Delay(100);
                    player.Position = new Vector3(player.Position.X + 0.1, player.Position.Y, player.Position.Z);
                    player.SendClientMessage(player.Position.ToString());
                    break;
                case "forward":
                    await Task.Delay(100);
                    player.Position = new Vector3(player.Position.X - 0.1, player.Position.Y, player.Position.Z);
                    player.SendClientMessage(player.Position.ToString());
                    break;
                case "right":
                    await Task.Delay(100);
                    player.Position = new Vector3(player.Position.X, player.Position.Y + 0.1, player.Position.Z);
                    player.SendClientMessage(player.Position.ToString());
                    break;
                case "left":
                    await Task.Delay(100);
                    player.Position = new Vector3(player.Position.X, player.Position.Y - 0.1, player.Position.Z);
                    player.SendClientMessage(player.Position.ToString());
                    break;
                default:
                    break;
            }
        }

        [Command("goto", "beach")]
        private static async void RunBeachScenario(Player player, string location)
        {
            await Task.Delay(100);
            switch (location)
            {
                case "beach":
                    Location.SetPlayerSpawnPoint(player, (int)City.LosSantos, 32);
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
