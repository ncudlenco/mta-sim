using SampSharp.GameMode;
using SampSharp.Streamer;
using SampSharp.Streamer.World;
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;

namespace SampSharp.SyntheticGameMode.Story.Objects
{
    public class Laptop : SampStoryObjectBase
    {
        public enum eLaptopModel
        {
            eClosed = 19894,
            eOpen = 19893
        }

        public override string Description
        {
            get => this.ModelId switch
            {
                19894 => " closed laptop",
                19893 => " open laptop",
                _ => " laptop ",
            };
            set { }
        }
    }
}
