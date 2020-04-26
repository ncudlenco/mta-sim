using System;
using System.Collections.Generic;
using System.Drawing.Printing;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using SampSharp.GameMode;
using SampSharp.GameMode.Helpers;
using SampSharp.SyntheticGameMode.Data;
using SampSharpGameMode.Extensions;
using SyntheticVideo2language.Story.Api;

namespace SampSharp.SyntheticGameMode.Story.Actions
{
    public class Walk : StoryActionBase
    {
        public override string Description { get => " is walking "; set { } }
        public override IStoryActor Performer { get; set; }
        public override IStoryItem TargetItem { get; set; }

        public float Angle { get; set; }
        public async override Task<bool> ApplyAsync(params object[] parameters)
        {
            SampStory.Instance.History.Add(this);

            var player = Performer as Player;
            SampStory.Instance.Logger.Log(player.Description + " " + this.Description + " towards " + TargetItem.Description);
                // (TargetItem == null ? "" : (TargetItem is StoryLocationBase ? " in " : " towards ") + TargetItem.Description), player);

            await Task.Delay(100);
            var position = player.Position;
            Vector3 destination = Vector3.Zero;
            if (TargetItem is Location)
            {
                destination = (TargetItem as Location).Position;
            }

            if (destination != Vector3.Zero)
            {
                player.Angle = this.Angle;
            }

            var eps = 1;
            while (!(player.Position.X <= (NextLocation as Location).Position.X + eps &&
                     player.Position.X >= (NextLocation as Location).Position.X - eps &&
                     player.Position.Y <= (NextLocation as Location).Position.Y + eps &&
                     player.Position.Y >= (NextLocation as Location).Position.Y - eps &&
                     player.Position.Z <= (NextLocation as Location).Position.Z + eps &&
                     player.Position.Z >= (NextLocation as Location).Position.Z - eps))
            {
                player.ApplyAnimation("ped", "WALK_civi", 4.1f, true, true, true, true, 10, true);
                await Task.Delay(10);
            }

            /*
            player.Destination = destination;
            var walking_angle = player.Angle;
            var interval = 100;
            var max_ticks = 20;
            int i = 0;
            // var walking_angle = (player.Angle + (NextLocation as Location).Angle) / 2;
            while (player.Destination != Vector3.Zero)
            {
                if (player.Angle == walking_angle)
                {
                    player.SetPlayerLookAt(destination);
                    walking_angle = player.Angle;
                    // player.ApplyAnimation("ped", "walk_civi", 4.1f, true, true, true, true, interval);
                    Console.WriteLine(walking_angle);
                    await Task.Delay(10);
                }
                else
                {
                    player.SetPlayerLookAt(destination);
                    walking_angle = player.Angle;
                    Console.WriteLine(walking_angle);
                }
            }*/

            player.Destination = Vector3.Zero;
            player.ClearAnimations();
            player.ClearAnimations();
            await Task.Delay(500);

            player.Position = (NextLocation as Location).Position;
            player.Angle = (NextLocation as Location).Angle;
            return await (NextLocation as Location).GetNextRandomValidAction().ApplyAsync();
        }
    }
}
