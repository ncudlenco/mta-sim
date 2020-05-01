using SampSharp.GameMode;
using SampSharp.Streamer;
using SampSharp.Streamer.World;
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;

namespace SampSharp.SyntheticGameMode.Story.Objects
{
    public class Food : SampStoryObjectBase
    {
        public enum eFoodType
        {
            ePizza = 19580,
            eSmokedLeg = 19847,
            eMilkBottle = 19570
        }

        public override string Description
        {
            get => this.ModelId switch
            {
                19580 => " pizza",
                19847 => " smoked leg ",
                19570 => " milk bottle ",
            };
            set { }
        }
    }
}
