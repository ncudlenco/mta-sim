using SampSharp.GameMode;
using SampSharp.Streamer.World;
using SyntheticVideo2language.Story.Api;
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;

namespace SampSharp.SyntheticGameMode.Story.Actions
{
    public class EndSimulation : StoryActionBase
    {
        public override string Description { get => ""; set { } }

        public override IStoryActor Performer { get => null; set { } }
        public override IStoryItem TargetItem { get => null; set { } }
        public async override Task<bool> ApplyAsync(params object[] parameters)
        {
            await Task.Delay(100);
            var player = Performer as Player;
            foreach (var item in DynamicObject.All)
            {
                item.Dispose();
            }
            BaseMode.Instance.Dispose();
            BaseMode.Instance.Exit();
            return true;
        }
    }
}
