using SampSharp.GameMode;
using SampSharp.Streamer;
using SampSharp.Streamer.World;
using SyntheticVideo2language.StoryGenerator.Api;
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;
using Vision2language.StoryGenerator.Api;

namespace SampSharp.SyntheticGameMode.Story.Objects
{
    public class Towel : StoryObjectBase, IGenericStoryItem
    {
        public string Description
        {
            get
            {
                return this.Id switch
                {
                    1640 => "white beach towel with green stripes",
                    1641 => "purple beach towel with a white R letter",
                    1642 => "red beach towel with white circles",
                    1643 => "yellow beach towel with red and black imprint",
                    _ => "beach towel"
                };
            }
            set { }
        }
        public int TopologicalOrder { get; set; }
        public override double SittingHeight { get => 0; }

        public eStoryItemType StoryItemType => eStoryItemType.Object;

        public List<IGenericStoryItem> StoryItems { get; set; }

        public static readonly List<int> TOWELL_IDS = new List<int> { 1640, 1641, 1642, 1643 };

        public async Task<bool> ApplyInGameAsync(params object[] parameters)
        {
            if (parameters.Length < 3)
            {
                return false;
            }
            var player = parameters[0] as Player;
            var position = (Vector3)parameters[1];
            var rotation = (Vector3)parameters[2];

            await Task.Delay(100);

            player.SendClientMessage(" a " + this.Description);
            this.ObjectInstance = new DynamicObject(this.Id, position, rotation);
            var streamer = BaseMode.Instance.Services.GetService<IStreamer>();
            streamer.ProcessActiveItems();
            player.OnUpdate(new SampSharp.GameMode.Events.PlayerUpdateEventArgs() { PreventPropagation = false });
            streamer.Update(player, player.Position);

            return true;
        }

        public Towel(int id)
        {
            this.Id = id;
        }
    }
}
