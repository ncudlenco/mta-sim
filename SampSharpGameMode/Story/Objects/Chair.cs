using SampSharp.GameMode;
using SampSharp.Streamer;
using SampSharp.Streamer.World;
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;

namespace SampSharp.SyntheticGameMode.Story.Objects
{
    public class Chair : SampStoryObjectBase
    {
        public enum eChairModel
        {
            eBedroomChair = 2331,
            eSolidWoodenChair = 1811
        }

        public override string Description { get => " chair "; set { } }
    }
}
