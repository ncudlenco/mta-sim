using SampSharp.GameMode;
using SampSharp.Streamer.World;
using SyntheticVideo2language.Story.Api;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace SampSharp.SyntheticGameMode.Story.Actions
{
    public class LayOnObject : StoryActionBase
    {
        public override string Description { get => " is laying back "; set { } }

        public override IStoryActor Performer { get; set; }
        public override IStoryItem TargetItem { get; set; }

        public static List<IStoryItem> GetAllValidTargetItems()
        {
            List<IStoryItem> validItems = new List<IStoryItem>();

            validItems.AddRange(Objects.Towel.TOWELL_IDS.Select(id => new Objects.Towel(id)));
            validItems.AddRange(Objects.BeachLounger.BEACH_LOUNGER_IDS.Select(id => new Objects.BeachLounger(id)));
            return validItems;
        }

        public async override Task<bool> ApplyAsync(params object[] parameters)
        {
            await Task.Delay(100);

            var player = Performer as Player;
            DynamicObject targetDynamicObject = null;
            Objects.SampStoryObjectBase storyObjectBase = TargetItem as Objects.SampStoryObjectBase;
            if (storyObjectBase != null)
            {
                targetDynamicObject = storyObjectBase.ObjectInstance;
            }

            if (targetDynamicObject == null)
            {
                return false;
            }

            SampStory.Instance.Logger.Log(player.Description + " " + this.Description + " on a " + TargetItem.Description + ".", player);
            player.Position = new Vector3(targetDynamicObject.Position.X, targetDynamicObject.Position.Y, player.Position.Z + (storyObjectBase == null ? 0 : storyObjectBase.SittingHeight));
            player.Rotation = storyObjectBase.Rotation;
            player.ApplyAnimation("BEACH", "Lay_Bac_Loop", 4.1f, true, false, false, false, int.MaxValue);
            player.PutCameraBehindPlayer();
            await Task.Delay(100);
            Thread.Sleep(10000);
            await Task.Delay(100);

            return true;
        }
    }
}
