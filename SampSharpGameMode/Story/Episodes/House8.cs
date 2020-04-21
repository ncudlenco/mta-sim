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

            var bedroom2Bed = new Bed
            {
                ModelId = 2298,
                Position = new Vector3(2361.29688,-1134.14844,1049.85938),
                Rotation = new Vector3(3.14159,0.00000,1.57080)
            };

            var sofaRight = new Sofa
            {
                ModelId = 1703,
                Position = new Vector3(2370.39063, -1124.43750, 1049.84375),
                Rotation = new Vector3(3.14159, 0.00000, 1.57080)
            };

            var sofaCenter = new Sofa
            {
                ModelId = 1703,
                Position = new Vector3(2371.60156, -1121.50781, 1049.84375),
                Rotation = new Vector3(3.14159, 0.00000, 3.14159)
            };

            var sofaLeft = new Sofa
            {
                ModelId = 1703,
                Position = new Vector3(2374.67969, -1122.53125, 1049.84375),
                Rotation = new Vector3(3.14159, 0.00000, -1.57080)
            };

            var streamer = BaseMode.Instance.Services.GetService<IStreamer>();
            streamer.ProcessActiveItems();
            player.OnUpdate(new SampSharp.GameMode.Events.PlayerUpdateEventArgs() { PreventPropagation = false });
            streamer.Update(player, player.Position);
#endregion

#region Bedroom1
            var bedroom1FacingBedLeft = new Location(2363.0017, -1123.7264, 1050.8750, 357.2968, this.InteriorId, " bedroom near the bed ");
            var bedroom1BackToBedLeft = new Location(2363.0017, -1123.7264, 1050.8750, 177.2968, this.InteriorId, " bedroom near the bed ");
            //this.ValidStartingLocations.Add(bedroom1BackToBedLeft);

            var bedroom1InBedLeft = new Location(2362.477, -1123.7567, 1050.875, 357.29678, this.InteriorId, " bedroom on the bed ");
            var getInBedAction = new GetInBed { NextLocation = bedroom1InBedLeft, Performer = SampStory.Instance.Actor, TargetItem = bedroom1Bed };
            bedroom1FacingBedLeft.PossibleActions.Add(getInBedAction);

            this.ValidStartingLocations.Add(bedroom1FacingBedLeft);
            var sleepAction = new Sleep { NextLocation = bedroom1InBedLeft, Prerequisites = new List<StoryActionBase> { getInBedAction }, Performer = SampStory.Instance.Actor, TargetItem = bedroom1Bed };
            bedroom1InBedLeft.PossibleActions.Add(sleepAction);
            var getOffBedAction = new GetOffBed { NextLocation = bedroom1BackToBedLeft, Prerequisites = new List<StoryActionBase> { getInBedAction, sleepAction }, Performer = SampStory.Instance.Actor, TargetItem = bedroom1Bed };
            bedroom1InBedLeft.PossibleActions.Add(getOffBedAction);
            getInBedAction.ClosingAction = getOffBedAction;
            sleepAction.ClosingAction = getOffBedAction;

            var bedroom1AtDeskBefore = new Location(2366.5579, -1122.7646, 1050.875, 266.2842, this.InteriorId, " bedroom at the desk ");
            var bedroom1AtDeskDuring = new Location(2366.5579, -1122.7646, 1050.875, 266.2842, this.InteriorId, " bedroom at the desk ");
            var bedroom1AtDeskAfter = new Location(2366.5579, -1122.7646, 1050.875, 86.2842, this.InteriorId, " bedroom at the desk ");
            //this.ValidStartingLocations.Add(bedroom1AtDeskBefore);
            //this.ValidStartingLocations.Add(bedroom1AtDeskAfter);
            bedroom1BackToBedLeft.PossibleActions.Add(new Walk { Performer = player, NextLocation = bedroom1AtDeskBefore, TargetItem = bedroom1AtDeskBefore });
            var sitAtDeskAction = new SitDown(SitDown.eHow.atDesk) { Performer = player, NextLocation = bedroom1AtDeskDuring, TargetItem = bedroomChair };
            bedroom1AtDeskBefore.PossibleActions.Add(sitAtDeskAction);
            //Change the action here to get up 
            var standUpFromDeskAction = new StandUp(StandUp.eHow.fromDesk) { Performer = player, Prerequisites = new List<StoryActionBase> { sitAtDeskAction }, NextLocation = bedroom1AtDeskAfter, TargetItem = bedroomChair };
            sitAtDeskAction.ClosingAction = standUpFromDeskAction;
            bedroom1AtDeskDuring.PossibleActions.Add(standUpFromDeskAction);
            //TODO: see with the laptop what should be done here

            //bedroom1AtDeskAfter.PossibleActions.Add(new Walk { Performer = player, NextLocation = bedroom1FacingBedLeft, TargetItem = bedroom1FacingBedLeft });

            var bedroom1Door = new Location(2367.1816, -1125.3959, 1050.875, 180.01979, this.InteriorId, " bedroom at the door ");
            //this.ValidStartingLocations.Add(bedroom1Door);
            bedroom1AtDeskAfter.PossibleActions.Add(new Walk { Performer = player, NextLocation = bedroom1Door, TargetItem = bedroom1Door });
            //bedroom1BackToBedLeft.PossibleActions.Add(new Walk { Performer = player, NextLocation = bedroom1Door, TargetItem = bedroom1Door });
            //bedroom1Door.PossibleActions.Add(new Walk { Performer = player, NextLocation = bedroom1FacingBedLeft, TargetItem = bedroom1FacingBedLeft });
            //bedroom1Door.PossibleActions.Add(new Walk { Performer = player, NextLocation = bedroom1AtDeskBefore, TargetItem = bedroom1AtDeskBefore });
            #endregion

            var hallwayToLivingroomDoor = new Location(2369.1443, -1127.3848, 1050.875, 270.25916, this.InteriorId, " hallway at the door to the living room ");
            //this.ValidStartingLocations.Add(hallwayToLivingroomDoor);
            bedroom1Door.PossibleActions.Add(new Walk { Performer = player, NextLocation = hallwayToLivingroomDoor, TargetItem = hallwayToLivingroomDoor });
            //hallwayToLivingroomDoor.PossibleActions.Add(new Walk { Performer = player, NextLocation = bedroom1Door, TargetItem = bedroom1Door });

            var livingRoomBackToRightSofa = new Location(2370.9368, -1124.0031, 1050.8750, 95.8058, " right sofa in the living room ");
            var livingRoomBackToRightSofa2 = new Location(2370.9368, -1124.0031, 1050.8750, 95.8058, " right sofa in the living room ");
            var livingRoomOnTheRightSofa = new Location(2370.9368, -1124.0031, 1050.8750, 95.8058, " right sofa in the living room ");

            hallwayToLivingroomDoor.PossibleActions.Add(new Walk { Performer = player, NextLocation = livingRoomBackToRightSofa, TargetItem = livingRoomBackToRightSofa });
            var sitOnRightSofaAction = new SitDown(SitDown.eHow.sofa) { Performer = player, NextLocation = livingRoomOnTheRightSofa, TargetItem = new Sofa() };
            livingRoomBackToRightSofa.PossibleActions.Add(sitOnRightSofaAction);
            var standUpFromRightSofaAction = new StandUp(StandUp.eHow.fromSofa) { Performer = player, Prerequisites = new List<StoryActionBase> { sitOnRightSofaAction }, NextLocation = livingRoomBackToRightSofa2, TargetItem = new Sofa() };
            sitOnRightSofaAction.ClosingAction = standUpFromRightSofaAction;
            livingRoomOnTheRightSofa.PossibleActions.Add(standUpFromRightSofaAction);

            var livingRoomBackToCentralSofa = new Location(2372.0334, -1122.0536, 1050.8750, 356.7915, " central sofa in the living room ");
            var livingRoomBackToCentralSofa2 = new Location(2372.0334, -1122.0536, 1050.8750, 356.7915, " central sofa in the living room ");
            var livingRoomOnCentralSofa = new Location(2372.0334, -1122.0536, 1050.8750, 356.7915, " central sofa in the living room ");
            livingRoomBackToRightSofa2.PossibleActions.Add(new Walk { Performer = player, NextLocation = livingRoomBackToCentralSofa, TargetItem = livingRoomBackToCentralSofa });
            var sitOnCentralSofaAction = new SitDown(SitDown.eHow.sofa) { Performer = player, NextLocation = livingRoomOnCentralSofa, TargetItem = new Sofa() };
            livingRoomBackToCentralSofa.PossibleActions.Add(sitOnCentralSofaAction);
            var standUpFromCentralSofaAction = new StandUp(StandUp.eHow.fromSofa) { Performer = player, Prerequisites = new List<StoryActionBase> { sitOnCentralSofaAction }, NextLocation = livingRoomBackToCentralSofa2, TargetItem = new Sofa() };
            sitOnCentralSofaAction.ClosingAction = standUpFromCentralSofaAction;
            livingRoomOnCentralSofa.PossibleActions.Add(standUpFromCentralSofaAction);

            var livingRoomBackToLeftSofa = new Location(2374.1345, -1124.0991, 1050.8750, 262.7906, " central sofa in the living room ");
            var livingRoomBackToLeftSofa2 = new Location(2374.1345, -1124.0991, 1050.8750, 262.7906, " central sofa in the living room ");
            var livingRoomOnLeftSofa = new Location(2374.1345, -1124.0991, 1050.8750, 262.7906, " central sofa in the living room ");
            livingRoomBackToCentralSofa2.PossibleActions.Add(new Walk { Performer = player, NextLocation = livingRoomBackToLeftSofa, TargetItem = livingRoomBackToLeftSofa });
            var sitOnLeftSofaAction = new SitDown(SitDown.eHow.sofa) { Performer = player, NextLocation = livingRoomOnLeftSofa, TargetItem = new Sofa() };
            livingRoomBackToLeftSofa.PossibleActions.Add(sitOnLeftSofaAction);
            var standUpFromLeftSofaAction = new StandUp(StandUp.eHow.fromSofa) { Performer = player, Prerequisites = new List<StoryActionBase> { sitOnLeftSofaAction }, NextLocation = livingRoomBackToLeftSofa2, TargetItem = new Sofa() };
            sitOnLeftSofaAction.ClosingAction = standUpFromLeftSofaAction;
            livingRoomOnLeftSofa.PossibleActions.Add(standUpFromLeftSofaAction);

            var livingRoomNearPhotos = new Location(2373.7715, -1128.37, 1050.8826, 213.83502, this.InteriorId, " living room near the dresser ");
            //this.ValidStartingLocations.Add(livingRoomNearPhotos);
            //livingRoomNearPhotos.PossibleActions.Add(new Walk { Performer = player, NextLocation = hallwayToLivingroomDoor, TargetItem = hallwayToLivingroomDoor });
            livingRoomBackToLeftSofa2.PossibleActions.Add(new Walk { Performer = player, NextLocation = livingRoomNearPhotos, TargetItem = livingRoomNearPhotos });

            var livingRoomToKitchenDoor = new Location(2370.776, -1129.9869, 1050.875, 179.36787, this.InteriorId, " living room at the door to kitchen ");
            //this.ValidStartingLocations.Add(livingRoomToKitchenDoor);
            livingRoomNearPhotos.PossibleActions.Add(new Walk { Performer = player, NextLocation = livingRoomToKitchenDoor, TargetItem = livingRoomToKitchenDoor });
            //hallwayToLivingroomDoor.PossibleActions.Add(new Walk { Performer = player, NextLocation = livingRoomToKitchenDoor, TargetItem = livingRoomToKitchenDoor });
            //livingRoomToKitchenDoor.PossibleActions.Add(new Walk { Performer = player, NextLocation = livingRoomNearPhotos, TargetItem = livingRoomNearPhotos });
            //livingRoomToKitchenDoor.PossibleActions.Add(new Walk { Performer = player, NextLocation = hallwayToLivingroomDoor, TargetItem = hallwayToLivingroomDoor });

            var kitchenNearTheSink = new Location(2373.8518, -1132.2216, 1050.875, 270.25897, this.InteriorId, " kitchen at the sink ");
            //this.ValidStartingLocations.Add(kitchenNearTheSink);
            livingRoomToKitchenDoor.PossibleActions.Add(new Walk { Performer = player, NextLocation = kitchenNearTheSink, TargetItem = kitchenNearTheSink });
            var washHandsAction = new WashHands { Performer = player, NextLocation = kitchenNearTheSink, TargetItem = kitchenNearTheSink };
            kitchenNearTheSink.PossibleActions.Add(washHandsAction);
            //kitchenNearTheSink.PossibleActions.Add(new Walk { Performer = player, NextLocation = livingRoomToKitchenDoor, TargetItem = livingRoomToKitchenDoor });

            var kitchenToHallway = new Location(2366.8711, -1132.0065, 1050.8750, 92.9391, this.InteriorId, " kitchen to hallway door ");
            kitchenNearTheSink.PossibleActions.Add(new Walk { Performer = player, Prerequisites = new List<StoryActionBase> { washHandsAction }, NextLocation = kitchenToHallway, TargetItem = kitchenToHallway });

            var hallwayToBedroom2 = new Location(2363.4084, -1131.7386, 1050.8750, 88.6741, this.InteriorId, " hallway to bedroom door ");
            kitchenToHallway.PossibleActions.Add(new Walk { Performer = player, NextLocation = hallwayToBedroom2, TargetItem = hallwayToBedroom2 });

            var bedroom2BackToBedLeft = new Location(2359.0698, -1134.0743, 1050.8750, 177.9942, this.InteriorId, " bedroom near the bed ");
            var bedroom2FacingBedLeft = new Location(2363.0017, -1123.7264, 1050.8750, 357.9942, this.InteriorId, " bedroom near the bed ");
            hallwayToBedroom2.PossibleActions.Add(new Walk { Performer = player, NextLocation = bedroom2FacingBedLeft, TargetItem = bedroom2FacingBedLeft });
            var bedroom2InBedLeft = new Location(2363.0017, -1123.7264, 1050.8750, 357.9942, this.InteriorId, " bedroom near the bed ");
            var getInBed2Action = new GetInBed { NextLocation = bedroom2InBedLeft, Performer = SampStory.Instance.Actor, TargetItem = bedroom2Bed };
            bedroom2FacingBedLeft.PossibleActions.Add(getInBed2Action);

            var sleepAction2 = new Sleep { NextLocation = bedroom2InBedLeft, Prerequisites = new List<StoryActionBase> { getInBed2Action }, Performer = SampStory.Instance.Actor, TargetItem = bedroom2Bed };
            bedroom2InBedLeft.PossibleActions.Add(sleepAction2);
            var getOffBed2Action = new GetOffBed { NextLocation = bedroom2BackToBedLeft, Prerequisites = new List<StoryActionBase> { getInBed2Action, sleepAction2 }, Performer = SampStory.Instance.Actor, TargetItem = bedroom2Bed };
            bedroom2InBedLeft.PossibleActions.Add(getOffBed2Action);
            getInBed2Action.ClosingAction = getOffBed2Action;
            sleepAction2.ClosingAction = getOffBed2Action;

            var bedroom2ToHallway = new Location(2363.4084, -1131.7386, 1050.8750, 268.6741, this.InteriorId, " bedroom to hallway door ");
            bedroom2BackToBedLeft.PossibleActions.Add(new Walk { Performer = player, NextLocation = bedroom2ToHallway, TargetItem = bedroom2ToHallway });

            var hallwayToEntrance = new Location(2365.3000, -1132.9200, 1050.8750, 180, " hallway to entrance door ");
            bedroom2ToHallway.PossibleActions.Add(new Walk { Performer = player, NextLocation = hallwayToEntrance, TargetItem = hallwayToEntrance });
            hallwayToEntrance.PossibleActions.Add(new EndSimulation());
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
