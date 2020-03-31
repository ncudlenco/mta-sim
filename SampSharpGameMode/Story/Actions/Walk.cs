using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using SampSharp.GameMode;
using SyntheticVideo2language.StoryGenerator.Api;
using Vision2language.StoryGenerator.Api;

namespace SampSharp.SyntheticGameMode.Story.Actions
{
    public class Walk : IGenericStoryItem
    {
        public string Description { get => " is walking "; set { } }
        public int TopologicalOrder { get; set; }

        public eStoryItemType StoryItemType => eStoryItemType.Action;

        public List<IGenericStoryItem> StoryItems { get; set; }

        public async Task<bool> ApplyInGameAsync(params object[] parameters)
        {
            if (parameters.Length < 1)
            {
                return false;
            }

            var player = parameters[0] as Player;
            player.SendClientMessage(player.Description + " " + Description);
            await Task.Delay(100);
            var position = player.Position;
            player.ApplyAnimation("ped", "WALK_civi", 4.1f, true, true, true, true, 10000, true);
            Thread.Sleep(10000);
            player.ClearAnimations();
            await Task.Delay(100);
            return true;
        }
    }
}
