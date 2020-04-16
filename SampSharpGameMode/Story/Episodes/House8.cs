using SampSharp.GameMode;
using SampSharp.GameMode.World;
using SampSharp.Streamer;
using SampSharp.SyntheticGameMode.Extensions;
using SampSharp.SyntheticGameMode.Story.Actions;
using SampSharp.SyntheticGameMode.Story.Objects;
using SyntheticVideo2language.Story.Api;
using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Text;
using System.Threading.Tasks;

namespace SampSharp.SyntheticGameMode.Story.Episodes
{
    public class House8 : StoryEpisodeBase, IDisposable
    {
        //We don't care about the time of day and the weather while inside the house. They are not visible.
        public override StoryTimeOfDayBase StoryTimeOfDay { get; set; }
        public override StoryWeatherBase StoryWeather { get; set; }
        public override StoryLocationBase StartingLocation { get; set; }
        public List<SampStoryObjectBase> Objects { get; set; }
        public override List<StoryLocationBase> ValidStartingLocations { get; protected set; }

        private readonly int InteriorId = 8;
        public override async Task<bool> Initialize(params object[] parameters)
        {
            if (parameters.Length < 1)
            {
                return false;
            }
            Player player = parameters[0] as Player;
#region Episode objects
            //Remove the porn painting from the bedroom wall
            GlobalObject.Remove(player, 2255, new Vector3(2361.5703, -1122.1484, 1052.2109), 0.25f);
            //Add a painting (San Fierro bridge) on the bedroom wall
            new GlobalObject(2281, new Vector3(2361.59473, -1122.49927, 1051.87500), new Vector3(360.00000, 0.00000, 90.00000));
            new GlobalObject(2281, new Vector3(2361.59473, -1122.49927, 1051.87500), new Vector3(360.00000, 0.00000, 90.00000));
            //Remove the chair from the buro in bedroom 1
            GlobalObject.Remove(player, 2331, new Vector3(2367.3672, -1123.1563, 1050.1172), 0.25f);
            //
            var bedroomChair = new Chair { ModelId = (int)Chair.eChairModel.eBedroomChair, Position = new Vector3(2367.20923, -1122.79114, 1050.11719), Rotation = new Vector3(356.85840, 0.00000, 359.39059) };
            await bedroomChair.CreateAsync(player);
            //Create a closed laptop on the table
            var laptop = new Laptop { ModelId = (int)Laptop.eLaptopModel.eClosed, Position = new Vector3(2368.59741, -1122.68201, 1050.83435), Rotation = new Vector3(0.00000, 0.00000, 269.11588) };
            await laptop.CreateAsync(player);
            this.Objects = new List<SampStoryObjectBase>();
            this.Objects.Add(laptop);
            this.Objects.Add(bedroomChair);
            this.ValidStartingLocations = new List<StoryLocationBase>();
            var bedroom1Bed = new Bed
            {
                ModelId = 2302,
                Position = new Vector3(2364.55469, -1122.96875, 1049.86719),
                Rotation = new Vector3(3.14159, 0.00000, 1.57080)
            };

            var streamer = BaseMode.Instance.Services.GetService<IStreamer>();
            streamer.ProcessActiveItems();
            player.OnUpdate(new SampSharp.GameMode.Events.PlayerUpdateEventArgs() { PreventPropagation = false });
            streamer.Update(player, player.Position);
#endregion
#region Bedroom1
            var bedroom1FacingBedLeft = new Location(2363.0017, -1123.7264, 1050.8750, 357.2968, this.InteriorId, " bedroom near the bed ");
            var bedroom1BackToBedLeft = new Location(2363.0017, -1123.7264, 1050.8750, 177.2968, this.InteriorId, " bedroom near the bed ");
            this.ValidStartingLocations.Add(bedroom1BackToBedLeft);

            var bedroom1InBedLeft = new Location(2362.477, -1123.7567, 1050.875, 357.29678, this.InteriorId, " bedroom on the bed ");
            bedroom1FacingBedLeft.PossibleActions.Add(new GetInBed { NextLocation = bedroom1InBedLeft, Performer = SampStory.Instance.Actor, TargetItem = bedroom1Bed });

            this.ValidStartingLocations.Add(bedroom1FacingBedLeft);
            bedroom1InBedLeft.PossibleActions.Add(new Sleep { NextLocation = bedroom1InBedLeft, Performer = SampStory.Instance.Actor, TargetItem = bedroom1Bed });
            bedroom1InBedLeft.PossibleActions.Add(new GetOffBed { NextLocation = bedroom1BackToBedLeft, Performer = SampStory.Instance.Actor, TargetItem = bedroom1Bed });

            var bedroom1AtDeskBefore = new Location(2366.5579, -1122.7646, 1050.875, 266.2842, this.InteriorId, " bedroom at the desk ");
            var bedroom1AtDeskDuring = new Location(2366.5579, -1122.7646, 1050.875, 266.2842, this.InteriorId, " bedroom at the desk ");
            var bedroom1AtDeskAfter = new Location(2366.5579, -1122.7646, 1050.875, 86.2842, this.InteriorId, " bedroom at the desk ");
            this.ValidStartingLocations.Add(bedroom1AtDeskBefore);
            this.ValidStartingLocations.Add(bedroom1AtDeskAfter);
            bedroom1BackToBedLeft.PossibleActions.Add(new Walk { Performer = player, NextLocation = bedroom1AtDeskBefore, TargetItem = bedroom1AtDeskBefore });
            var sitAtDeskAction = new SitDown { Performer = player, NextLocation = bedroom1AtDeskDuring, TargetItem = bedroomChair };
            bedroom1AtDeskBefore.PossibleActions.Add(sitAtDeskAction);
            //Change the action here to get up 
            var standUpFromDeskAction = new StandUp { Performer = player, Prerequisites = new List<StoryActionBase> { sitAtDeskAction }, NextLocation = bedroom1AtDeskAfter, TargetItem = bedroomChair };
            sitAtDeskAction.ClosingAction = standUpFromDeskAction;
            bedroom1AtDeskDuring.PossibleActions.Add(standUpFromDeskAction);
            //TODO: see with the laptop what should be done here

            bedroom1AtDeskAfter.PossibleActions.Add(new Walk { Performer = player, NextLocation = bedroom1FacingBedLeft, TargetItem = bedroom1FacingBedLeft });

            var bedroom1Door = new Location(2367.1816, -1125.3959, 1050.875, 180.01979, this.InteriorId, " bedroom at the door ");
            this.ValidStartingLocations.Add(bedroom1Door);
            bedroom1AtDeskAfter.PossibleActions.Add(new Walk { Performer = player, NextLocation = bedroom1Door, TargetItem = bedroom1Door });
            bedroom1BackToBedLeft.PossibleActions.Add(new Walk { Performer = player, NextLocation = bedroom1Door, TargetItem = bedroom1Door });
            bedroom1Door.PossibleActions.Add(new Walk { Performer = player, NextLocation = bedroom1FacingBedLeft, TargetItem = bedroom1FacingBedLeft });
            bedroom1Door.PossibleActions.Add(new Walk { Performer = player, NextLocation = bedroom1AtDeskBefore, TargetItem = bedroom1AtDeskBefore });
            #endregion

            var hallwayToLivingroomDoor = new Location(2369.1443, -1127.3848, 1050.875, 270.25916, this.InteriorId, " hallway at the door to the living room ");
            this.ValidStartingLocations.Add(hallwayToLivingroomDoor);
            bedroom1Door.PossibleActions.Add(new Teleport { Performer = player, NextLocation = hallwayToLivingroomDoor, TargetItem = hallwayToLivingroomDoor });
            hallwayToLivingroomDoor.PossibleActions.Add(new Teleport { Performer = player, NextLocation = bedroom1Door, TargetItem = bedroom1Door });

            var livingRoomNearPhotos = new Location(2373.7715, -1128.37, 1050.8826, 213.83502, this.InteriorId, " living room near the dresser ");
            this.ValidStartingLocations.Add(livingRoomNearPhotos);
            hallwayToLivingroomDoor.PossibleActions.Add(new Teleport { Performer = player, NextLocation = livingRoomNearPhotos, TargetItem = livingRoomNearPhotos });
            livingRoomNearPhotos.PossibleActions.Add(new Teleport { Performer = player, NextLocation = hallwayToLivingroomDoor, TargetItem = hallwayToLivingroomDoor });

            var livingRoomToKitchenDoor = new Location(2370.776, -1129.9869, 1050.875, 179.36787, this.InteriorId, " living room at the door to kitchen ");
            this.ValidStartingLocations.Add(livingRoomToKitchenDoor);
            livingRoomNearPhotos.PossibleActions.Add(new Teleport { Performer = player, NextLocation = livingRoomToKitchenDoor, TargetItem = livingRoomToKitchenDoor });
            hallwayToLivingroomDoor.PossibleActions.Add(new Teleport { Performer = player, NextLocation = livingRoomToKitchenDoor, TargetItem = livingRoomToKitchenDoor });
            livingRoomToKitchenDoor.PossibleActions.Add(new Teleport { Performer = player, NextLocation = livingRoomNearPhotos, TargetItem = livingRoomNearPhotos });
            livingRoomToKitchenDoor.PossibleActions.Add(new Teleport { Performer = player, NextLocation = hallwayToLivingroomDoor, TargetItem = hallwayToLivingroomDoor });

            var kitchenNearTheSink = new Location(2373.8518, -1132.2216, 1050.875, 270.25897, this.InteriorId, " kitchen at the sink ");
            this.ValidStartingLocations.Add(kitchenNearTheSink);
            livingRoomToKitchenDoor.PossibleActions.Add(new Teleport { Performer = player, NextLocation = kitchenNearTheSink, TargetItem = kitchenNearTheSink });
            kitchenNearTheSink.PossibleActions.Add(new WashHands { Performer = player, NextLocation = kitchenNearTheSink, TargetItem = kitchenNearTheSink });
            kitchenNearTheSink.PossibleActions.Add(new Teleport { Performer = player, NextLocation = livingRoomToKitchenDoor, TargetItem = livingRoomToKitchenDoor });

            return true;
        }

        public async override Task<bool> PlayAsync(params object[] parameters)
        {
            if (parameters.Length < 1)
            {
                return false;
            }
            Player player = parameters[0] as Player;
            if (StartingLocation == null)
            {
                StartingLocation = ValidStartingLocations.PickRandom();
            }
            await (StartingLocation as Location).SpawnPlayerHere(player);
            //return true;
            return await StartingLocation.PossibleActions.PickRandom().ApplyAsync(parameters);
        }

        public async void Dispose()
        {
            foreach (var item in Objects)
            {
                await item.DestroyAsync();
            }
        }
    }
}
