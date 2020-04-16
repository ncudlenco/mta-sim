using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Timers;
using SampSharp.GameMode;
using SyntheticVideo2language.Story.Api;

namespace SampSharp.SyntheticGameMode.Story.Actions
{
    public class Swim : StoryActionBase
    {
        public override string Description { get => " is swimming "; set { } }

        public override IStoryActor Performer { get; set; }
        public override IStoryItem TargetItem { get; set; }

        public async override Task<bool> ApplyAsync(params object[] parameters)
        {
            var player = Performer as Player;
            SampStory.Instance.Logger.Log(player.Description + " " + Description, player);
            await Task.Delay(100);
            var interval = 1300;
            player.SmoothVelocity = 0.05f;
            for (int i = 0; i < 10; i++)
            {
                player.ApplyAnimation("SWIM", "Swim_Breast", 6.1f, true, true, true, true, interval);
                await Task.Delay(interval);
            }
            player.ClearAnimations();
            player.SmoothVelocity = 0;
            return true;
        }

    }
}
