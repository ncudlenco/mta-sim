using SampSharp.SyntheticGameMode.Extensions;
using SyntheticVideo2language.Story.Api;
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace SampSharp.SyntheticGameMode.Story.Actions
{
    public class SitDown : StoryActionBase
    {
        public override string Description { get => " sits down "; set { } }
        public override IStoryActor Performer { get; set; }
        public override IStoryItem TargetItem { get; set; }

        public override async Task<bool> ApplyAsync(params object[] parameters)
        {
            SampStory.Instance.History.Add(this);

            await Task.Delay(100);
            var player = Performer as Player;
            SampStory.Instance.Logger.Log(player.Description + " " + this.Description + " on the " + TargetItem.Description, player);
            //TODO: move the player in the middle of the target object with the face in the opposite direction
            player.ApplyAnimation("INT_OFFICE", "OFF_Sit_In", 4.1f, false, false, false, true, 5000, true);
            Thread.Sleep(5000);

            return await (NextLocation as Location).GetNextRandomValidAction().ApplyAsync();
        }
    }
}
