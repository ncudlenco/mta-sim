using SampSharp.GameMode;
using SampSharp.GameMode.World;
using System;
using System.Collections.Generic;
using System.Text;

namespace SampSharp.SyntheticGameMode.Data
{
    public class DefaultMapObject : IWorldObject
    {
        public Vector3 Position { get; set; }
        public Vector3 Rotation { get; set; }
        public int ModelId { get; set; }

        public Extent3 GetBoundingBox()
        {
            var colAndreas = BaseMode.Instance.Services.GetService<ColAndreas.ColAndreas>();
            if (colAndreas == null)
            {
                return null;
            }
            colAndreas.GetModelBoundingBox(this.ModelId, out Vector3 min, out Vector3 max);
            return new Extent3 { Min = min, Max = max };
        }
    }
}
