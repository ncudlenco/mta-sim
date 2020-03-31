using SampSharp.GameMode;
using SampSharp.Streamer.World;
using System;
using System.Collections.Generic;
using System.Text;

namespace SampSharp.SyntheticGameMode.Story.Objects
{
    public partial class StoryObjectBase
    {
        public int Id { get; set; }
        public DynamicObject ObjectInstance { get; set; }
        public virtual double SittingHeight { get => 0; }
        public virtual Vector3 Rotation { get => ObjectInstance == null ? new Vector3() : ObjectInstance.Rotation; }

    }
}
