using SampSharp.SyntheticGameMode.Extensions;
using SyntheticVideo2language.Story.Api;
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace SampSharp.SyntheticGameMode.Story.Actions
{
    public class Teleport : StoryActionBase
    {
        public override string Description { get => " is "; set { } }
        public override IStoryActor Performer { get; set; }
        public override IStoryItem TargetItem { get; set; }

        public override async Task<bool> ApplyAsync(params object[] parameters)
        {
            SampStory.Instance.History.Add(this);

            var player = Performer as Player;
            var nextPlace = NextLocation as Location;

            SampStory.Instance.Logger.Log(player.Description + this.Description + (nextPlace.Interior > 0 ? "inside" : "at") + " the " + nextPlace.Description, player);
            player.Position = nextPlace.Position;
            player.Angle = nextPlace.Angle;
            player.PutCameraBehindPlayer();
            Thread.Sleep(3000);

            return await (NextLocation as Location).GetNextRandomValidAction().ApplyAsync();
        }
    }
}
