using SyntheticVideo2language.StoryGenerator.Api;
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using Vision2language.StoryGenerator.Api;
using System.Linq;
using SampSharp.GameMode;
using SampSharp.ColAndreas;
using System.Threading.Tasks;

namespace SampSharp.SyntheticGameMode.Story.Actions
{
    public class PutObjectOnGround : IGenericStoryItem
    {
        public string Description { get => " is putting on the ground "; set { } }
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

            var player = parameters[0] as Player;
            await Task.Delay(100);
            player.ClearAnimations();
            await Task.Delay(100);

            var position = player.GetXYAroundPlayer(1);
            var colAndreas = BaseMode.Instance.Services.GetService<ColAndreas.ColAndreas>();
            position = colAndreas.FindZ_For2DCoord(position);
            position = new Vector3(position.X, position.Y, position.Z + 0.05);
            var rotation = colAndreas.GetGroundRotation(position);
            rotation = new Vector3(rotation.X, rotation.Y, player.Angle);
            await Task.Delay(100);

            player.SendClientMessage(player.Description + " " + this.Description);
            var res = false;
            if (StoryItems != null)
            {
                var allRes = new List<bool>();
                foreach (var item in StoryItems)
                {
                    allRes.Add(await item.ApplyInGameAsync(player, position, rotation));
                }
            }
            Thread.Sleep(100);
            return res;
        }

        public PutObjectOnGround(IGenericStoryItem targetObject)
        {
            this.StoryItems = new List<IGenericStoryItem>()
            {
                targetObject
            };
        }
    }
}
