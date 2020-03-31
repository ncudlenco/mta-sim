using SyntheticVideo2language.StoryGenerator.Api;
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Vision2language.StoryGenerator.Api;

namespace SampSharp.SyntheticGameMode.Story.Actions
{
    public class Smoke : IGenericStoryItem
    {
        public string Description { get => " is smoking "; set { } }
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
            player.SetCameraNextToPlayer(3, 0, 2);
            player.SpecialAction = GameMode.Definitions.SpecialAction.SmokeCiggy;
            await Task.Delay(100);
            //player.SendClientMessage("M_smk_in"); //Lights up the cigar
            player.ApplyAnimation("SMOKING", "M_smk_in", 4.1f, false, true, true, true, 3000, true);
            Thread.Sleep(3000);
            for (int i = 0; i < 3; i++)
            {
                //player.SendClientMessage("M_smk_drag"); //Actual smokking
                player.ApplyAnimation("SMOKING", "M_smk_drag", 4.1f, false, true, true, true, 2000, true);
                Thread.Sleep(2000);
                //player.SendClientMessage("M_smk_loop"); //Idle
                player.ApplyAnimation("SMOKING", "M_smk_loop", 4.1f, true, true, true, true, 2000, true);
                Thread.Sleep(2000);
                //player.SendClientMessage("M_smk_tap"); //Taps the cigar
                player.ApplyAnimation("SMOKING", "M_smk_tap", 4.1f, false, true, true, true, 2000, true);
                Thread.Sleep(2000);
            }
            //player.SendClientMessage("F_smklean_loop"); //Needs proper spawn location, with something to lean on in the left side
            //player.ApplyAnimation("SMOKING", "F_smklean_loop", 4.1f, true, true, true, true, 10000, true);
            //Thread.Sleep(10000);
            //player.SendClientMessage("M_smklean_loop"); //Needs proper spawn location, with something to lean on in the back
            //player.ApplyAnimation("SMOKING", "M_smklean_loop", 4.1f, true, true, true, true, 10000, true);
            //Thread.Sleep(10000);
            //player.SendClientMessage("M_smkstnd_loop"); //Smokes from the left hand
            //player.ApplyAnimation("SMOKING", "M_smkstnd_loop", 4.1f, true, true, true, true, 10000, true);
            //Thread.Sleep(10000);

            //player.SendClientMessage("M_smk_out"); //Last smoke then throws the cigar
            player.ApplyAnimation("SMOKING", "M_smk_out", 4.1f, false, true, true, true, 3000, true);
            Thread.Sleep(3000);
            player.SpecialAction = GameMode.Definitions.SpecialAction.None;
            player.ClearAnimations();
            await Task.Delay(100);
            return true;
        }
    }
}
