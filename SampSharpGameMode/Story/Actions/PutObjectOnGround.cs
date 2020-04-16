using SyntheticVideo2language.Story.Api;
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using System.Linq;
using SampSharp.GameMode;
using SampSharp.ColAndreas;
using System.Threading.Tasks;
using SampSharp.SyntheticGameMode.Story.Objects;

namespace SampSharp.SyntheticGameMode.Story.Actions
{
    public class PutObjectOnGround : StoryActionBase
    {
        public override string Description { get => " is putting on the ground "; set { } }

        public override IStoryActor Performer { get; set; }
        public override IStoryItem TargetItem { get; set; }

        public static List<IStoryItem> GetAllValidObjects()
        {
            List<IStoryItem> validItems = new List<IStoryItem>();

            validItems.AddRange(Objects.Towel.TOWELL_IDS.Select(id => new Objects.Towel(id)));
            validItems.AddRange(Objects.BeachLounger.BEACH_LOUNGER_IDS.Select(id => new Objects.BeachLounger(id)));
            return validItems;
        }

        public async override Task<bool> ApplyAsync(params object[] parameters)
        {
            var player = Performer as Player;
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

            SampStory.Instance.Logger.Log(player.Description + " " + this.Description, player);
            var res = false;
            var target = TargetItem as SampStoryObjectBase;
            await target.CreateAsync(player, position, rotation);
            Thread.Sleep(100);
            return res;
        }
    }
}
