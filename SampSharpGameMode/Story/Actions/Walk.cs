using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using SampSharp.GameMode;
using SampSharp.GameMode.Helpers;
using SampSharpGameMode.Extensions;
using SyntheticVideo2language.Story.Api;

namespace SampSharp.SyntheticGameMode.Story.Actions
{
    public class Walk : StoryActionBase
    {
        public override string Description { get => " is walking "; set { } }
        public override IStoryActor Performer { get; set; }
        public override IStoryItem TargetItem { get; set; }
        public async override Task<bool> ApplyAsync(params object[] parameters)
        {
            SampStory.Instance.History.Add(this);

            var player = Performer as Player;
            SampStory.Instance.Logger.Log(player.Description + " " + this.Description +
                (TargetItem == null ? "" : (TargetItem is StoryLocationBase ? " in " : " towards ") + TargetItem.Description), player);

            await Task.Delay(100);
            var position = player.Position;
            Vector3 destination = Vector3.Zero;
            if (TargetItem is Location)
            {
                destination = (TargetItem as Location).Position;
            }

            if (destination != Vector3.Zero)
            {
                var destinationV = destination - player.Position;
                //player.Angle = -MathHelper.ToDegrees((float)Vector3.UnitX.SignedAngleTo(destinationV, Vector3.UnitZ));
                player.SetPlayerLookAt(destination);
            }

            player.ApplyAnimation("ped", "WALK_civi", 4.1f, true, true, true, true, 3000, true);
            Thread.Sleep(3000);
            player.ClearAnimations();
            await Task.Delay(100);

            player.Position = (NextLocation as Location).Position;
            player.Angle = (NextLocation as Location).Angle;
            return await (NextLocation as Location).GetNextRandomValidAction().ApplyAsync();
        }
    }
}
