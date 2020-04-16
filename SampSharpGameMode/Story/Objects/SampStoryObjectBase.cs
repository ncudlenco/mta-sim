using SampSharp.GameMode;
using SampSharp.Streamer;
using SampSharp.Streamer.World;
using SampSharp.SyntheticGameMode.Data;
using SyntheticVideo2language.Story.Api;
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;

namespace SampSharp.SyntheticGameMode.Story.Objects
{
    public abstract class SampStoryObjectBase : StoryObjectBase, IDisposable
    {
        private int CollisionId = -1;
        public DynamicObject ObjectInstance { get; set; }
        private int modelId;
        public virtual int ModelId { get => ObjectInstance == null ? modelId : ObjectInstance.ModelId; set { modelId = value; } }
        public virtual double SittingHeight { get => 0; }
        private Vector3 rotation;
        public virtual Vector3 Rotation { get => ObjectInstance == null ? rotation : ObjectInstance.Rotation; set { rotation = value; } }
        private Vector3 position;
        public virtual Vector3 Position { get => ObjectInstance == null ? position : ObjectInstance.Position; set { position = value; } }
        public bool IsDisposed { get; set; }
        public virtual Extent3 GetBoundingBox()
        {
            var colAndreas = BaseMode.Instance.Services.GetService<ColAndreas.ColAndreas>();
            if (colAndreas == null)
            {
                return null;
            }
            colAndreas.GetModelBoundingBox(this.ModelId, out Vector3 min, out Vector3 max);
            return new Extent3 { Min = min, Max = max };
        }

        public override async Task<bool> CreateAsync(params object[] parameters)
        {
            await Task.Delay(100);
            Player player = null;
            if (parameters.Length > 0)
            {
                player = parameters[0] as Player;
            }

            this.ObjectInstance = new DynamicObject(this.ModelId, Position, Rotation);
            var colAndreas = BaseMode.Instance.Services.GetService<ColAndreas.ColAndreas>();
            CollisionId = colAndreas.CreateObjectCollision(this.ModelId, Position, Rotation);
            IsDisposed = false;

            var streamer = BaseMode.Instance.Services.GetService<IStreamer>();
            streamer.ProcessActiveItems();
            if (player != null)
            {
                player.OnUpdate(new SampSharp.GameMode.Events.PlayerUpdateEventArgs() { PreventPropagation = false });
                streamer.Update(player, player.Position);
            }
            return true;
        }

        public override async Task<bool> DestroyAsync(params object[] parameters)
        {
            await Task.Delay(100);
            Player player = null;
            if (parameters.Length > 0)
            {
                player = parameters[0] as Player;
            }

            var colAndreas = BaseMode.Instance.Services.GetService<ColAndreas.ColAndreas>();
            if (this.CollisionId > 0)
            {
                colAndreas.DestroyObjectWithCollision(this.CollisionId);
            }
            else
            {
                this.ObjectInstance.Dispose();
            }
            this.ObjectInstance = null;
            this.position = new Vector3();
            this.rotation = new Vector3();
            this.modelId = -1;
            this.CollisionId = -1;
            IsDisposed = true;

            var streamer = BaseMode.Instance.Services.GetService<IStreamer>();
            streamer.ProcessActiveItems();
            if (player != null)
            {
                player.OnUpdate(new SampSharp.GameMode.Events.PlayerUpdateEventArgs() { PreventPropagation = false });
                streamer.Update(player, player.Position);
            }
            return true;
        }

        public async void Dispose()
        {
            if (!IsDisposed)
            {
                await this.DestroyAsync();
            }
        }
    }
}
