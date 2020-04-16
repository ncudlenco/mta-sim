using SampSharp.SyntheticGameMode.Extensions;
using SyntheticVideo2language.Story.Api;
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace SampSharp.SyntheticGameMode.Story.Actions
{
    public class WashHands : StoryActionBase
    {
        public override string Description { get => " is washing hands "; set { } }
        public override IStoryActor Performer { get; set; }
        public override IStoryItem TargetItem { get; set; }

        public override async Task<bool> ApplyAsync(params object[] parameters)
        {
            SampStory.Instance.History.Add(this);

            var player = Performer as Player;
            SampStory.Instance.Logger.Log(player.Description + this.Description + " in the " + TargetItem.Description);
            player.ApplyAnimation("INT_HOUSE", "wash_up", 4.1f, true, false, false, true, 3000, true);
            Thread.Sleep(3000);
            player.ClearAnimations();
            
            return await (NextLocation as Location).GetNextRandomValidAction().ApplyAsync();
        }
    }
}
