using System;
using System.Collections.Generic;
using System.Text;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using SampSharp.GameMode;
using SampSharp.GameMode.World;
using SyntheticVideo2language.Story.Api;
using SampSharp.GameMode.Helpers;
using SampSharp.SyntheticGameMode.Data;
using SampSharpGameMode.Extensions;
using SampSharp.SyntheticGameMode.Extensions;

namespace SampSharp.SyntheticGameMode.Story.Actions
{
    public class GetInBed : StoryActionBase
    {
        public override string Description { get => " gets on "; set { } }
        public override IStoryActor Performer { get; set; }
        public override IStoryItem TargetItem { get; set; }
        public async override Task<bool> ApplyAsync(params object[] parameters)
        {
            SampStory.Instance.History.Add(this);

            var player = Performer as Player;
            await Task.Delay(100);

            var theBed = (TargetItem as Objects.SampStoryObjectBase);
            var bbox = theBed.GetBoundingBox();
            bbox.ChangeOrigin(theBed.Position, new Vector3(0, 0, theBed.Rotation.Z));
            var centerTopMiddle = new Vector3(bbox.Center.X, bbox.Center.Y, bbox.Max.Z);
            var across = Vector3.UnitX.Rotate(new Vector3(0, 0, theBed.Rotation.Z));
            var centerTopLeft = centerTopMiddle + across.Normalized().Mult((bbox.Max.X - bbox.Min.X) / 2);

            SampStory.Instance.Logger.Log(player.Description + " " + this.Description + " the " + TargetItem.Description + ".", player);

            player.Position = new Vector3(centerTopLeft.X, centerTopLeft.Y, player.Position.Z);
            player.ApplyAnimation("INT_HOUSE", "BED_In_L", 4.1f, false, false, false, true, 4000, true);
            Thread.Sleep(4000);

            return await (NextLocation as Location).GetNextRandomValidAction().ApplyAsync();
            //player.ApplyAnimation("INT_HOUSE", "BED_In_R", 4.1f, true, true, true, true, 10000, true);
            //Thread.Sleep(10000);
            //player.ApplyAnimation("INT_HOUSE", "BED_Loop_L", 4.1f, true, false, false, false, 10000, true);
            //Thread.Sleep(10000);
            //player.ApplyAnimation("INT_HOUSE", "BED_Loop_R", 4.1f, true, true, true, true, 10000, true);
            //Thread.Sleep(10000);
            //player.ApplyAnimation("INT_HOUSE", "BED_Out_L", 4.1f, true, true, true, true, 10000, true);
            //Thread.Sleep(10000);
            //player.ApplyAnimation("INT_HOUSE", "BED_Out_R", 4.1f, true, true, true, true, 10000, true);
            //Thread.Sleep(10000);
            ////Sit down
            //player.ApplyAnimation("INT_HOUSE", "LOU_In", 4.1f, true, true, true, true, 10000, true);
            //Thread.Sleep(10000);
            ////Sit down loop
            //player.ApplyAnimation("INT_HOUSE", "LOU_Loop", 4.1f, true, true, true, true, 10000, true);
            //Thread.Sleep(10000);
            ////Get up from a seat
            //player.ApplyAnimation("INT_HOUSE", "LOU_Out", 4.1f, true, true, true, true, 10000, true);
            //Thread.Sleep(10000);
            ////Washing
            //player.ApplyAnimation("INT_HOUSE", "wash_up", 4.1f, true, true, true, true, 10000, true);
            //Thread.Sleep(10000);
        }
    }
}
