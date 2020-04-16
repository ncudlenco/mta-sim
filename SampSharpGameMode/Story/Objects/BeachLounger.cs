using System;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;
using SampSharp.GameMode;
using SampSharp.Streamer;
using SampSharp.Streamer.World;
using SyntheticVideo2language.Story.Api;

namespace SampSharp.SyntheticGameMode.Story.Objects
{
    public class BeachLounger : SampStoryObjectBase
    {
        public override string Description { get => "beach lounger with a striped towel"; set => throw new NotImplementedException(); }
        public override double SittingHeight { get => 0.1082642; }
        public override Vector3 Rotation { get => ObjectInstance == null ? new Vector3() : new Vector3(ObjectInstance.Rotation.X, ObjectInstance.Rotation.Y, ObjectInstance.Rotation.Z > 0 ? ObjectInstance.Rotation.Z - 180 : ObjectInstance.Rotation.Z + 180); }

        public async override Task<bool> CreateAsync (params object[] parameters)
        {
            if (parameters.Length < 3)
            {
                return false;
            }
            var player = parameters[0] as Player;
            var position = (Vector3)parameters[1];
            var rotation = (Vector3)parameters[2];

            await Task.Delay(100);

            SampStory.Instance.Logger.Log(" a " + this.Description, player);
            double oppositeZrotation = rotation.Z > 0 ? rotation.Z - 180 : rotation.Z + 180;
            this.ObjectInstance = new DynamicObject(this.ModelId, position, new Vector3(rotation.X, rotation.Y, oppositeZrotation));
            var streamer = BaseMode.Instance.Services.GetService<IStreamer>();
            streamer.ProcessActiveItems();
            player.OnUpdate(new SampSharp.GameMode.Events.PlayerUpdateEventArgs() { PreventPropagation = false });
            streamer.Update(player, player.Position);

            return true;
        }

        public static readonly List<int> BEACH_LOUNGER_IDS = new List<int> { 1646 };

        public BeachLounger(int modelId)
        {
            this.ModelId = modelId;
        }
    }
}
