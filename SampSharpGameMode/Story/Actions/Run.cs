using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using SampSharp.GameMode;
using SyntheticVideo2language.Story.Api;

namespace SampSharp.SyntheticGameMode.Story.Actions
{
    public class Run : StoryActionBase
    {
        public override string Description { get => " is running "; set { } }

        public override IStoryActor Performer { get; set; }
        public override IStoryItem TargetItem { get; set; }

        public async override Task<bool> ApplyAsync(params object[] parameters)
        {
            var player = Performer as Player;
            SampStory.Instance.Logger.Log(player.Description + " " + Description, player);
            await Task.Delay(100);
            var position = player.Position;
            player.ApplyAnimation("ped", "run_civi", 4.1f, true, true, true, true, 20000, true);
            Thread.Sleep(20000);
            player.ClearAnimations();
            await Task.Delay(100);
            return true;
        }
    }
}
