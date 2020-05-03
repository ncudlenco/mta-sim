using SampSharp.GameMode;
using SyntheticVideo2language.Story.Api;
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using SampSharpGameMode.Extensions;

namespace SampSharp.SyntheticGameMode.Story.Actions
{
    public class LookAtObject : StoryActionBase
    {
        public override string Description { get => " looking at "; set { } }
        public override IStoryActor Performer { get; set; }
        public override IStoryItem TargetItem { get; set; }

        public override async Task<bool> ApplyAsync(params object[] parameters)
        {
            SampStory.Instance.History.Add(this);
            var player = Performer as Player;
            var theObject = (TargetItem as Objects.SampStoryObjectBase);

            SampStory.Instance.Logger.Log(player.Description + " is " + this.Description + " the " + TargetItem.Description, player);
            
            await Task.Delay(100);
            var playerEyesPosition = player.GetXYAroundPlayer(0, 0, 1.2f);
            //var cameraTargetVector = (theObject.Position - playerEyesPosition).Normalized();
            //var startMovePoint = cameraTargetVector.MovePointAlong(playerEyesPosition, -1.2f);

            //player.InterpolateCameraLookAt(startMovePoint, playerEyesPosition, 1500, GameMode.Definitions.CameraCut.Move);
            //Thread.Sleep(1500);
            player.CameraPosition = playerEyesPosition;
            player.SetCameraLookAt(theObject.Position);
            Thread.Sleep(3000);

            //player.PutCameraBehindPlayer();
            player.PutCameraBehindPlayer();
            return await (NextLocation as Location).GetNextRandomValidAction().ApplyAsync();
        }
    }
}
