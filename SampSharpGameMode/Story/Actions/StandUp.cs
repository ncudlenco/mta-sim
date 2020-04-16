using SyntheticVideo2language.Story.Api;
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace SampSharp.SyntheticGameMode.Story.Actions
{
    public class StandUp : StoryActionBase
    {
        public override string Description { get => " stands up "; set { } }
        public override IStoryActor Performer { get; set; }
        public override IStoryItem TargetItem { get; set; }

        public override async Task<bool> ApplyAsync(params object[] parameters)
        {
            SampStory.Instance.History.Add(this);
            await Task.Delay(100);
            var player = Performer as Player;
            SampStory.Instance.Logger.Log(player.Description + " " + this.Description + " from the " + TargetItem.Description, player);
            player.ApplyAnimation("INT_OFFICE", "OFF_Sit_2Idle_180", 4.1f, false, false, false, true, 5000, true);
            Thread.Sleep(5000);
            player.ClearAnimations(true);
            player.ClearAnimations();

            return await (NextLocation as Location).GetNextRandomValidAction().ApplyAsync();
        }
    }
}
