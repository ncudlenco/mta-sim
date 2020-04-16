using SampSharp.SyntheticGameMode.Extensions;
using SyntheticVideo2language.Story.Api;
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace SampSharp.SyntheticGameMode.Story.Actions
{
    public class Sleep : StoryActionBase
    {
        public Sleep() : base() { }
        public override string Description { get => " sleeping "; set { } }
        public override IStoryActor Performer { get; set; }
        public override IStoryItem TargetItem { get; set; }

        public override async Task<bool> ApplyAsync(params object[] parameters)
        {
            SampStory.Instance.History.Add(this);

            //The animation is not working on the bed. It moves the player outside of the bed. Must be called after the GetInBed.
            var player = Performer as Player;

            SampStory.Instance.Logger.Log(player.Description + " is " + this.Description + " on the " + TargetItem.Description + ".", player);
            //player.ApplyAnimation("INT_HOUSE", "BED_Loop_L", 4.1f, true, false, false, true, 3000, true);
            Thread.Sleep(3000);

            return await (NextLocation as Location).GetNextRandomValidAction().ApplyAsync();
        }
    }
}
