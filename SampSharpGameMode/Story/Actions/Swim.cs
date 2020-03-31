using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Timers;
using SampSharp.GameMode;
using SyntheticVideo2language.StoryGenerator.Api;
using Vision2language.StoryGenerator.Api;

namespace SampSharp.SyntheticGameMode.Story.Actions
{
    public class Swim : IGenericStoryItem
    {
        public string Description { get => " is swimming "; set { } }
        public int TopologicalOrder { get; set; }

        public eStoryItemType StoryItemType => eStoryItemType.Action;

        public List<IGenericStoryItem> StoryItems { get; set; }

        private System.Timers.Timer t;
        private double elapse;
        private Player player;
        public async Task<bool> ApplyInGameAsync(params object[] parameters)
        {
            if (parameters.Length < 1)
            {
                return false;
            }

            this.player = parameters[0] as Player;
            player.SendClientMessage(player.Description + " " + Description);
            await Task.Delay(100);
            var position = player.Position;
            t = new System.Timers.Timer(1000);
            elapse = 0;
            t.Elapsed += TimerTick;
            t.Start();
            player.ApplyAnimation("SWIM", "Swim_Breast", 4.1f, true, true, true, true, 10000, true);
            await Task.Delay(10000);
            return true;
        }

        private void TimerTick(object sender, ElapsedEventArgs e)
        {
            if (elapse >= 10000)
            {
                t.Stop();
                player.ClearAnimations();
                return;
            }
            player.Position = player.GetXYAroundPlayer(1f);
            player.SendClientMessage("Tick + " + player.Position.ToString());
            elapse += t.Interval;
        }
    }
}
