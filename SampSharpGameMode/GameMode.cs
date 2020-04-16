using System;
using SampSharp.ColAndreas;
using SampSharp.GameMode;
using SampSharp.GameMode.Events;
using SampSharp.GameMode.World;
using SampSharp.Streamer;
using SampSharp.Streamer.World;
using SampSharp.SyntheticGameMode.Story;

namespace SampSharpGameMode
{
    public class BaseMode : SampSharp.GameMode.BaseMode
    {
        #region Overrides of BaseMode
        protected override void OnInitialized(EventArgs e)
        {
            base.OnInitialized(e);

            var streamer = Services.GetService<IStreamer>();
            streamer.IsErrorCallbackEnabled = true;
            streamer.Error += (sender, args) => { Console.WriteLine("Error CB: " + args.Error); };
            streamer.PrintStackTraceOnError = true;
            ColAndreas colAndreas = new ColAndreas(this);
        }

        #endregion

        protected override void OnPlayerRequestClass(BasePlayer player, RequestClassEventArgs e)
        {
            try
            {
                //This is used to bypass the class selection dialog
                player.SetSpawnInfo(Player.NoTeam, new Random().Next(312), new Vector3(15, 15, 3), 0.0f);
                player.Spawn();
            }
            catch (Exception)
            {
            }
        }

        protected override void OnPlayerSpawned(BasePlayer player, SpawnEventArgs e)
        {
            //custom logic here to determine the spawn point (context)
            base.OnPlayerSpawned(player, e);
        }

        protected override void OnPlayerDisconnected(BasePlayer player, DisconnectEventArgs e)
        {
            foreach (var item in DynamicObject.All)
            {
                item.Dispose();
            }
            base.OnPlayerDisconnected(player, e);
        }

        protected override void OnExited(EventArgs e)
        {
            foreach (var item in DynamicObject.All)
            {
                item.Dispose();
            }
            base.OnExited(e);
        }

    }
}