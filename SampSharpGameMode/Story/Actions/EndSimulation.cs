using SampSharp.GameMode;
using SampSharp.Streamer.World;
using SyntheticVideo2language.StoryGenerator.Api;
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;
using Vision2language.StoryGenerator.Api;

namespace SampSharp.SyntheticGameMode.Story.Actions
{
    public class EndSimulation : IGenericStoryItem
    {
        public string Description { get => ""; set { } }
        public int TopologicalOrder { get; set; }

        public eStoryItemType StoryItemType => eStoryItemType.Action;

        public List<IGenericStoryItem> StoryItems { get; set; }

        public async Task<bool> ApplyInGameAsync(params object[] parameters)
        {
            if (parameters.Length < 1)
            {
                return false;
            }

            await Task.Delay(100);
            var player = parameters[0] as Player;
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
