using SampSharp.GameMode;
using SampSharp.SyntheticGameMode.Extensions;
using SampSharp.SyntheticGameMode.Story.Objects;
using SyntheticVideo2language.Story.Api;
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace SampSharp.SyntheticGameMode.Story.Actions
{
    public class PickUpObject : StoryActionBase
    {
        public override string Description { get => " picks up "; set { } }
        public override IStoryActor Performer { get; set; }
        public override IStoryItem TargetItem { get; set; }

        public override async Task<bool> ApplyAsync(params object[] parameters)
        {
            SampStory.Instance.History.Add(this);

            var player = Performer as Player;
            SampStory.Instance.Logger.Log(player.Description + this.Description + TargetItem.Description);
            player.ApplyAnimation("INT_SHOP", "shop_loop", 4.1f, true, false, false, true, 500, true);
            Thread.Sleep(500);
            await Task.Delay(500);

            player.SetAttachedObject(
                0, 
                (TargetItem as SampStoryObjectBase).ModelId, 
                GameMode.Definitions.Bone.RightHand,
                (TargetItem as Food).Offset, 
                (TargetItem as Food).Rotation, 
                Vector3.One, GameMode.SAMP.Color.AliceBlue, 
                GameMode.SAMP.Color.AliceBlue
            );

            return await (NextLocation as Location).GetNextRandomValidAction().ApplyAsync();
        }
    }
}