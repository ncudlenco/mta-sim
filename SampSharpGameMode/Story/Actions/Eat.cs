using SampSharp.SyntheticGameMode.Extensions;
using SyntheticVideo2language.Story.Api;
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using SampSharp.GameMode;

namespace SampSharp.SyntheticGameMode.Story.Actions
{
    public class Eat : StoryActionBase
    {
        public override string Description { get => " is eating " + TargetItem.Description; set { } }
        public override IStoryActor Performer { get; set; }
        public override IStoryItem TargetItem { get; set; }

        public Vector3 Position {get;set;}

        public override async Task<bool> ApplyAsync(params object[] parameters)
        {
            SampStory.Instance.History.Add(this);

            var player = Performer as Player;
            player.Position = this.Position;

            SampStory.Instance.Logger.Log(player.Description + this.Description + " at the " + TargetItem.Description);
            player.ApplyAnimation("FOOD", "FF_Sit_Eat2", 4.1f, true, false, false, true, 3000, true);
            Thread.Sleep(3500);
            player.ClearAnimations();
            await Task.Delay(1000);

            return await (NextLocation as Location).GetNextRandomValidAction().ApplyAsync();
        }
    }
}
