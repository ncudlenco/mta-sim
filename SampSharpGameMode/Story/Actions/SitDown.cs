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
        public enum eHow
        {
            atDesk,
            sofa
        }

        public override string Description { get => " sits down "; set { } }
        public override IStoryActor Performer { get; set; }
        public override IStoryItem TargetItem { get; set; }
        public eHow How { get; set; }

        public override async Task<bool> ApplyAsync(params object[] parameters)
        {
            SampStory.Instance.History.Add(this);

            await Task.Delay(100);
            var player = Performer as Player;
            SampStory.Instance.Logger.Log(player.Description + " " + this.Description + " on the " + TargetItem.Description, player);
            //TODO: move the player in the middle of the target object with the face in the opposite direction
            switch (this.How)
            {
                case eHow.atDesk:
                    player.ApplyAnimation("INT_OFFICE", "OFF_Sit_In", 4.1f, false, false, false, true, 5000, true);
                    break;
                case eHow.sofa:
                    player.ApplyAnimation("INT_HOUSE", "LOU_In", 4.1f, false, false, false, true, 5000, true);
                    break;
                default:
                    break;
            }
            Thread.Sleep(5000);

            return await (NextLocation as Location).GetNextRandomValidAction().ApplyAsync();
        }

        public SitDown(eHow how) : base()
        {
            this.How = how;
        }
    }
}
