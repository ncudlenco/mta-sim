using System;
using System.Collections.Generic;
using System.Reflection;
using SampSharp.GameMode;
using SampSharp.GameMode.Helpers;
using SampSharp.GameMode.Pools;
using SampSharp.GameMode.World;
using System.Linq;
using SyntheticVideo2language.Story.Api;
using SampSharp.GameMode.Events;
using SampSharp.Streamer.World;
using System.Threading.Tasks;
using ScreenRecorderLib;
using System.IO;

namespace SampSharp.SyntheticGameMode.Story
{
    [PooledType]
    public class Player : BasePlayer, IStoryActor
    {
        public string Description
        {
            get => this.PlayerSkin.Description;
            set { }
        }
        public eStoryItemType StoryItemType => eStoryItemType.Actor;
        public Actions.SetPlayerSkin PlayerSkin { get; set; }
        public Vector3 CreateVelocity(float speed, float rotation = 0)
        {
            float angle = this.Angle;
            if (this.InAnyVehicle)
            {
                angle = Vehicle.Angle;
            }
            angle += rotation;

            Vector3 result = new Vector3(
                speed * MathF.Sin(MathHelper.ToRadians(-angle)),
                speed * MathF.Cos(MathHelper.ToRadians(-angle)),
                this.Velocity.Z
            );
            return result;
        }
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

        public void SetPlayerLookAt(Vector3 destination)
        {
            var Pa = Math.Abs(Math.Atan((destination.Y - this.Position.Y) / (destination.X - this.Position.X)));
            if (destination.X <= this.Position.X && destination.Y >= this.Position.Y)
                Pa = 180 - Pa;
            else if (destination.X < this.Position.X && destination.Y < this.Position.Y)
                Pa += 180;
            else if (destination.X >= this.Position.X && destination.Y <= this.Position.Y)
                Pa = 360.0 - Pa;
            Pa -= 90.0;
            if (Pa >= 360.0)
                Pa -= 360.0;
            this.Angle = (float)Pa;
        }

        public Vector3 GetForwardVector()
        {
            var dest = GetXYAroundPlayer(1);
            return (dest - this.Position).Normalized();
        }

        public async void SetCameraNextToPlayer(float distance, float angle = 0, float zOffset = 0)
        {
            //This updates the player position
            await Task.Delay(100);
            this.CameraPosition = GetXYAroundPlayer(distance, angle, zOffset);
            this.SetCameraLookAt(this.Position);
        }
        #region Overrides of BasePlayer
        public override void OnConnected(EventArgs e)
        {
            base.OnConnected(e);
        }
        public static bool IsSpawned = false;
        public async override void OnSpawned(SpawnEventArgs e)
        {
            base.OnSpawned(e);
            if (!IsSpawned)
            {
                IsSpawned = true;
                SampStory.Instance.Actor = this;
                await SampStory.Instance.Play().ConfigureAwait(false);
            }
        }
        internal float SmoothVelocity;
        public override void OnUpdate(PlayerUpdateEventArgs e)
        {
            if (this.SmoothVelocity > 0)
            {
                this.Velocity = CreateVelocity(this.SmoothVelocity);
            }
            base.OnUpdate(e);
        }
        #endregion
    }
}