using SampSharp.SyntheticGameMode.Extensions;
using SyntheticVideo2language.Story.Api;
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace SampSharp.SyntheticGameMode.Story.Actions
{
    public class GetOffBed : StoryActionBase
    {
        public override string Description { get => " gets off "; set { } }
        public override IStoryActor Performer { get; set; }
        public override IStoryItem TargetItem { get; set; }

        public override async Task<bool> ApplyAsync(params object[] parameters)
        {
            SampStory.Instance.History.Add(this);
            var player = Performer as Player;
            SampStory.Instance.Logger.Log(player.Description + " " + this.Description + " the " + TargetItem.Description + ".", player);
            player.ApplyAnimation("INT_HOUSE", "BED_Out_L", 4.1f, false, false, false, true, 3000, true);
            player.Angle += 180;
            Thread.Sleep(3000);
            player.Position = (NextLocation as Location).Position;
            player.Angle = (NextLocation as Location).Angle;

            return await (NextLocation as Location).GetNextRandomValidAction().ApplyAsync();
        }
    }
}
