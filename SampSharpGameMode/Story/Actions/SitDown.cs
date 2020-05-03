using SampSharp.GameMode;
using SampSharp.SyntheticGameMode.Data;
using SampSharp.SyntheticGameMode.Extensions;
using SampSharpGameMode.Extensions;
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
            var targetObject = (TargetItem as Objects.SampStoryObjectBase);
            SampStory.Instance.Logger.Log(player.Description + " " + this.Description + " on the " + TargetItem.Description, player);
            //TODO: move the player in the middle of the target object with the face in the opposite direction
            switch (this.How)
            {
                case eHow.atDesk:
                    player.ApplyAnimation("INT_OFFICE", "OFF_Sit_In", 4.1f, false, false, false, true, 5000, true);
                    break;
                case eHow.sofa:
                    //var bbox = targetObject.GetBoundingBox();
                    //player.SendClientMessage((bbox.Max.X - bbox.Min.X).ToString());
                    //player.SendClientMessage((bbox.Max.Y - bbox.Min.Y).ToString());
                    //bbox.ChangeOrigin(targetObject.Position, new Vector3(0, 0, targetObject.Rotation.Z));
                    //var across = Vector3.UnitY.Rotate(new Vector3(0, 0, targetObject.Rotation.Z));
                    //var along = Vector3.UnitX.Rotate(new Vector3(0, 0, targetObject.Rotation.Z));
                    //var centerTopMiddle = bbox.Min.ProjectOnPlane(along.MovePointAlong(player.Position, 10).Normalized());
                    //var centerTopLeft = centerTopMiddle + across.Normalized().Mult((bbox.Max.X - bbox.Min.X) / 2);
                    //Debug.DrawPoint(player, centerTopLeft, Debug.ePointType.Type2);
                    //player.Position = new Vector3(centerTopLeft.X, centerTopLeft.Y, player.Position.Z);
                    player.Position = player.GetHeadingVector().MovePointAlong(player.Position, -0.6f);
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
