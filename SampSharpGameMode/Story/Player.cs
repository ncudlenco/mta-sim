using System;
using System.Collections.Generic;
using System.Reflection;
using SampSharp.GameMode;
using SampSharp.GameMode.Helpers;
using SampSharp.GameMode.Pools;
using SampSharp.GameMode.World;
using Vision2language.StoryGenerator.Api;
using System.Linq;
using SyntheticVideo2language.StoryGenerator.Api;
using SampSharp.GameMode.Events;
using SampSharp.Streamer.World;
using System.Threading.Tasks;

namespace SampSharp.SyntheticGameMode.Story
{
    [PooledType]
    public class Player : BasePlayer, IGenericStoryItem
    {
        public string Description
        {
            get => this.PlayerSkin.Description;
            set { }
        }

        public Actions.SetPlayerSkin PlayerSkin {get;set;}
        public int TopologicalOrder { get { return 0; } set { } }

        public List<IGenericStoryItem> StoryItems { get; set; }

        public eStoryItemType StoryItemType => eStoryItemType.Player;

        public Vector3 GetXYAroundPlayer(float distance, float rotation = 0, float zOffset = 0)
        {
            float angle = this.Angle;
            if (this.InAnyVehicle)
            {
                angle = Vehicle.Angle;
            }
            angle += rotation;

            Vector3 result = new Vector3(
                this.Position.X + distance * MathF.Sin(MathHelper.ToRadians(-angle)),
                this.Position.Y + distance * MathF.Cos(MathHelper.ToRadians(-angle)),
                this.Position.Z + zOffset
            );
            return result;
        }

        #region Overrides of BasePlayer

        public override void OnConnected(EventArgs e)
        {
            base.OnConnected(e);
        }

        public static bool IsSpawned = false;

        public override void OnSpawned(SpawnEventArgs e)
        {
            base.OnSpawned(e);
            if (!IsSpawned)
            {
                IsSpawned = true;
                SampStoryGenerator.Instance.GenerateRandom(this);
                SampStoryGenerator.Instance.CurrentStory.ForEach(x => x.ApplyInGameAsync());
            }
        }

        public void CopyProperties(BasePlayer source, BasePlayer target)
        {
            foreach (PropertyInfo prop in source.GetType().GetProperties())
            {
                PropertyInfo prop2 = source.GetType().GetProperty(prop.Name);
                prop2.SetValue(target, prop.GetValue(source, null), null);
            }
            foreach (var field in source.GetType().GetFields())
            {
                var field2 = source.GetType().GetField(field.Name);
                field2.SetValue(target, field.GetValue(source));
            }
        }

        public async Task<bool> ApplyInGameAsync(params object[] parameters)
        {
            foreach (var item in DynamicObject.All)
            {
                item.Dispose();
            }

            this.SendClientMessage("A " + this.Description);

            var results = new List<bool>();
            foreach (var item in this.StoryItems)
            {
                results.Add(await item.ApplyInGameAsync(this));
            }
            return results.All(x => x);
        }

        public async void SetCameraNextToPlayer(float distance, float angle = 0, float zOffset = 0)
        {
            //This updates the player position
            await Task.Delay(100);
            this.CameraPosition = GetXYAroundPlayer(distance, angle, zOffset);
            this.SetCameraLookAt(this.Position);
        }

        #endregion
    }
}