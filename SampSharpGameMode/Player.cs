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
using SampSharpGameMode.Extensions;
using System.Threading;

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
        public Vector3 Destination { get; set; }
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

        public async Task SetPlayerLookAt(Vector3 destination)
        {
            await Task.Delay(100);
            var destinationV = destination - this.Position;
            var angle = MathHelper.ToDegrees((float)Vector3.Forward.AngleAboutAxisTo(destinationV, Vector3.Up));

            this.Angle = angle + 360;
        }

        public Vector3 GetHeadingVector()
        {
            return (GetXYAroundPlayer(10) - this.Position).Normalized();
        }

        public async void SetCameraNextToPlayer(float distance, Vector3 target, float angle = 0, float zOffset = 0)
        {
            //This updates the player position
            await Task.Delay(100);
            this.CameraPosition = GetXYAroundPlayer(distance, angle, zOffset);
            if (target.Equals(Vector3.Zero))
            {
                target = this.Position;
            }
            this.InterpolateCameraLookAt(this.CameraPosition, target, 1000, GameMode.Definitions.CameraCut.Move);
            this.SetCameraLookAt(target, GameMode.Definitions.CameraCut.Move);
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
            if (this.Destination != Vector3.Zero)
            {
                this.SetPlayerLookAt(this.Destination);
                if(MathF.Abs(this.Position.DistanceTo(this.Destination)) <= .3 + float.Epsilon)
                {
                    this.ClearAnimations(true);
                    this.ClearAnimations(true);
                    this.Destination = Vector3.Zero;
                    this.Velocity = Vector3.Zero;
                }
            }
            base.OnUpdate(e);
        }
        #endregion
    }
}