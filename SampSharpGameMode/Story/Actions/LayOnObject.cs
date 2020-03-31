using SampSharp.GameMode;
using SampSharp.Streamer.World;
using SyntheticVideo2language.StoryGenerator.Api;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Vision2language.StoryGenerator.Api;

namespace SampSharp.SyntheticGameMode.Story.Actions
{
    public class LayOnObject : IGenericStoryItem
    {
        public string Description { get => " is laying back "; set { } }
        public int TopologicalOrder { get; set; }

        public eStoryItemType StoryItemType => eStoryItemType.Action;

        public List<IGenericStoryItem> StoryItems { get; set; }
        public static List<IGenericStoryItem> GetAllValidObjects()
        {
            List<IGenericStoryItem> validItems = new List<IGenericStoryItem>();

            validItems.AddRange(Objects.Towel.TOWELL_IDS.Select(id => new Objects.Towel(id)));
            validItems.AddRange(Objects.BeachLounger.BEACH_LOUNGER_IDS.Select(id => new Objects.BeachLounger(id)));
            return validItems;
        }

        public async Task<bool> ApplyInGameAsync(params object[] parameters)
        {
            if (parameters.Length < 1)
            {
                return false;
            }

            await Task.Delay(100);

            var player = parameters[0] as Player;
            DynamicObject targetDynamicObject = null;
            var targetObject = this.StoryItems.FirstOrDefault();
            Objects.StoryObjectBase storyObjectBase = targetObject as Objects.StoryObjectBase;
            if (storyObjectBase != null)
            {
                targetDynamicObject = storyObjectBase.ObjectInstance;
            }

            if (targetDynamicObject == null)
            {
                return false;
            }

            player.SendClientMessage(player.Description + " " + this.Description + " on a " + targetObject.Description + ".");
            player.Position = new Vector3(targetDynamicObject.Position.X, targetDynamicObject.Position.Y, player.Position.Z + (storyObjectBase == null ? 0 : storyObjectBase.SittingHeight));
            player.Rotation = storyObjectBase.Rotation;
            player.ApplyAnimation("BEACH", "Lay_Bac_Loop", 4.1f, true, false, false, false, int.MaxValue);
            player.PutCameraBehindPlayer();
            await Task.Delay(100);
            Thread.Sleep(10000);
            await Task.Delay(100);

            return true;
        }

        public LayOnObject(IGenericStoryItem targetObject)
        {
            this.StoryItems = new List<IGenericStoryItem>()
            {
                targetObject
            };
        }
    }
}
