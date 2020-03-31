using SampSharp.GameMode;
using SampSharp.GameMode.SAMP.Commands;
using SampSharp.GameMode.World;
using SampSharp.Streamer.World;
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;

namespace SampSharp.Cimulator.Test
{
    public class GameMode : BaseMode
    {
        protected static DynamicObject[] obj = new DynamicObject[10];
        protected static DynamicObject projectile = null;

        [Command("shoot")]
        public static async void CreateCommand(BasePlayer player)
        {
            player.SendClientMessage($"Delay...");
            await Task.Delay(100);

            if (projectile != null && DynamicObject.Find(projectile.Id) != null)
            {
                Cimulator.RemoveDynamicCol(projectile);
                projectile = null;
            }

            projectile = new DynamicObject(19342, new Vector3(player.Position.X + 5 * Math.Sin(ConvertToRadians(-player.Angle)), player.Position.Y + 5 * Math.Cos(ConvertToRadians(-player.Angle)), player.Position.Z));
            Cimulator.CreateDynamicColisionVolume(projectile, 19342, new Vector3(1.5, player.Position.X + 5 * Math.Sin(ConvertToRadians(-player.Angle)), player.Position.Y + 5 * Math.Cos(ConvertToRadians(-player.Angle))), new Vector3(player.Position.Z, 0, 0));
            Streamer.Streamer.Update(player);
            Cimulator.SetLinearVelocity(projectile, new Vector3(15 * Math.Sin(ConvertToRadians(-player.Angle)), 15 * Math.Cos(ConvertToRadians(-player.Angle)), 1.7));
        }

        protected override void OnInitialized(EventArgs e)
        {
            base.OnInitialized(e);

            Console.WriteLine("\n----------------------------------");
            Console.WriteLine(" Cimulator game mode test");
            Console.WriteLine("----------------------------------\n");

            Cimulator.Load(); //loads the collision map of SanAndreas, don't use it if you don't want the map to be loaded
            Cimulator.SetWorldGravity(new Vector3(0, 0, -3.5));//applies gravity on the Z axis
            SetGameModeText("blowup");
            AddPlayerClass(250, new Vector3(132.3336, -67.6250, 1.5781), 270.0000f);
            Cimulator.EnableSimulation();//enables the simulation

            obj[0] = new DynamicObject(1221, new Vector3(135.68100, -91.73073, 1.06152));
            obj[1] = new DynamicObject(1221, new Vector3(134.53696, -91.79777, 1.06152));
            obj[2] = new DynamicObject(1221, new Vector3(133.09566, -91.88223, 1.06152));
            obj[3] = new DynamicObject(1221, new Vector3(131.76138, -91.96041, 1.06152));
            obj[4] = new DynamicObject(1221, new Vector3(134.45720, -91.80853, 3.18867));
            obj[5] = new DynamicObject(1221, new Vector3(133.84770, -91.83816, 2.07358));
            obj[6] = new DynamicObject(1221, new Vector3(132.42287, -91.92165, 2.07358));
            obj[7] = new DynamicObject(1221, new Vector3(135.06685, -91.76672, 2.07358));
            obj[8] = new DynamicObject(1221, new Vector3(133.13399, -91.89931, 3.18867));
            obj[9] = new DynamicObject(1221, new Vector3(133.73849, -91.85670, 4.15000));

            //creating collision volumes to simulate ingame objects
            Cimulator.CreateDynamicColisionVolume(obj[0], 1221, new Vector3(1.5, 135.68100, -91.73073), new Vector3(1.06152, 0.00000, 0.00000));
            Cimulator.CreateDynamicColisionVolume(obj[1], 1221, new Vector3(1.5, 134.53696, -91.79777), new Vector3(1.06152, 0.00000, 0.00000));
            Cimulator.CreateDynamicColisionVolume(obj[2], 1221, new Vector3(1.5, 133.09566, -91.88223), new Vector3(1.06152, 0.00000, 0.00000));
            Cimulator.CreateDynamicColisionVolume(obj[3], 1221, new Vector3(1.5, 131.76138, -91.96041), new Vector3(1.06152, 0.00000, 0.00000));
            Cimulator.CreateDynamicColisionVolume(obj[4], 1221, new Vector3(1.5, 134.45720, -91.80853), new Vector3(3.18867, 0.00000, 0.00000));
            Cimulator.CreateDynamicColisionVolume(obj[5], 1221, new Vector3(1.5, 133.84770, -91.83816), new Vector3(2.07358, 0.00000, 0.00000));
            Cimulator.CreateDynamicColisionVolume(obj[6], 1221, new Vector3(1.5, 132.42287, -91.92165), new Vector3(2.07358, 0.00000, 0.00000));
            Cimulator.CreateDynamicColisionVolume(obj[7], 1221, new Vector3(1.5, 135.06685, -91.76672), new Vector3(2.07358, 0.00000, 0.00000));
            Cimulator.CreateDynamicColisionVolume(obj[8], 1221, new Vector3(1.5, 133.13399, -91.89931), new Vector3(3.18867, 0.00000, 0.00000));
            Cimulator.CreateDynamicColisionVolume(obj[9], 1221, new Vector3(1.5, 133.73849, -91.85670), new Vector3(4.15000, 0.00000, 0.00000));
            Console.WriteLine("\n----------------------------------");
            Console.WriteLine(" End initialize");
            Console.WriteLine("----------------------------------\n");
        }

        protected static double ConvertToRadians(double angle)
        {
            return (Math.PI / 180) * angle;
        }
    }
}
