using SampSharp.GameMode;
using SampSharp.Streamer;
using SampSharp.Streamer.World;
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;

namespace SampSharp.SyntheticGameMode.Story.Objects
{
    public class Bed : SampStoryObjectBase
    {
        public override string Description { get => "bed"; set { } }
        public static readonly List<int> BEDS_MODEL_IDS = new List<int> { 2603, 1771, 2302, 1794, 14866, 11720, 1700, 2300, 2301, 2090, 14446, 2298, 2299, 1812, 1797, 1701, 1745, 1793, 1796, 1795, 1798, 1799, 1800, 1801, 1802, 1803 };

        public async override Task<bool> CreateAsync(params object[] parameters)
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
    }
}
