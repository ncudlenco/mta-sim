using SampSharp.GameMode;
using SampSharp.Streamer;
using SampSharp.Streamer.World;
using SampSharp.SyntheticGameMode.Extensions;
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;
using SyntheticVideo2language.Story.Api;

namespace SampSharp.SyntheticGameMode.Story.Objects
{
    public class Food : SampStoryObjectBase, IStoryItem
    {
        public override Vector3 Rotation {
            set { }
            
            get => this.ModelId switch
            {
                2769 => new Vector3(0, 90, 0),
                19847 => new Vector3(0, 0, 0),
                19570 => new Vector3(0, 0, 0),
            }; 
        }

        public Vector3 Offset
        {
            set { }

            get => this.ModelId switch
            {
                // x -> up (-)/down(+), y -> left(+)/right(-), z -> behind(-)/ahead(+)

                2769 => new Vector3(0.08, 0.05, 0.03),
                19847 => new Vector3(0, 0, 0),
                19570 => new Vector3(0, 0, 0),
            };
        }

        public enum eFoodType
        {
            eLittleBooger = 2769,
            //eSmokedLeg = 19847,
            //eMilkBottle = 19570
        }

        public override string Description
        {
            get => this.ModelId switch
            {
                2769 => "little booger",
                19847 => "smoked leg ",
                19570 => "milk bottle ",
            };
            set { }
        }
    }
}
