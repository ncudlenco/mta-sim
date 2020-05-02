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
using System.Collections.Specialized;
using System.Text;
using System.Threading.Tasks;

namespace SampSharp.SyntheticGameMode.Story.Episodes
{
    public class House3 : StoryEpisodeBase, IDisposable
    {
        // this scenariu will be in a different house
        public override StoryTimeOfDayBase StoryTimeOfDay { get; set; }
        public override StoryWeatherBase StoryWeather { get; set; }
        public override StoryLocationBase StartingLocation { get; set; }
        public List<SampStoryObjectBase> Objects { get; set; }
        public override List<StoryLocationBase> ValidStartingLocations { get; protected set; }

        private readonly int InteriorId = 3;

        public override async Task<bool> Initialize(params object[] parameters)
        {
            if (parameters.Length < 1)
            {
                return false;
            }

            Player player = parameters[0] as Player;

            var streamer = BaseMode.Instance.Services.GetService<IStreamer>();
            streamer.ProcessActiveItems();
            player.OnUpdate(new SampSharp.GameMode.Events.PlayerUpdateEventArgs() { PreventPropagation = false });
            streamer.Update(player, player.Position);

            #region Episode objects

            var kitchenChair1 = new Chair { ModelId = (int)Chair.eChairModel.eSolidWoodenChair, Position = new Vector3(2494.2, -1708.3188, 1014.2422), Rotation = new Vector3(0, 0, 0) };
            await kitchenChair1.CreateAsync(player);

            var kitchenChair2 = new Chair { ModelId = (int)Chair.eChairModel.eSolidWoodenChair, Position = new Vector3(2494.2, -1706.7609, 1014.2422), Rotation = new Vector3(0, 0, 0) };
            await kitchenChair2.CreateAsync(player);

            #endregion

            this.Objects = new List<SampStoryObjectBase>();
            this.ValidStartingLocations = new List<StoryLocationBase>();

            // declare possible locations
            var livingRoomDoorEntranceLocation = new Location(2496.0610, -1694.2596, 1014.7422, 181.8800, this.InteriorId, "livin room near door");
            var kitchenDoorEntranceLocation = new Location(2496.0244, -1708.2274, 1014.7422, 177.1800, this.InteriorId, "kitchen entrance");
            var kitchenSinkLocation = new Location(2500.1151, -1709.2577, 1014.7422, 267.4209, this.InteriorId, "sink");
            var kitchenGasCookerLocation = new Location(2499.2088, -1706.6673, 1014.7422, 6.4351, this.InteriorId, "gas cooker");
            var kitchenFridgeLocation = new Location(2498.2986, -1711.3533, 1014.7422, 169.6598, this.InteriorId, "fridge");
            var kitchenChairLocations = new List<Tuple<Location, float>> {
                Tuple.Create(new Location(2495.1032, -1708.3363, 1014.7422, 90.000, this.InteriorId, "chair"), 108.0327f) ,
                Tuple.Create(new Location(2495.1032, -1706.7609, 1014.7422, 90.000, this.InteriorId, "chair"), 92.8327f)
            };

            int chairLocation = new Random().Next(2);
            var kitchenChairLocationTuple = kitchenChairLocations[chairLocation];

            // declare valid starting locations
            ValidStartingLocations.Add(livingRoomDoorEntranceLocation);

            #region Create locations graph
            // living room entrance actions
            //livingRoomDoorEntranceLocation.PossibleActions.Add(new PickUpObject { Performer = player, TargetItem = kitchenSinkLocation});

            livingRoomDoorEntranceLocation.PossibleActions.Add(new Walk { Performer = player, NextLocation = kitchenDoorEntranceLocation, TargetItem = kitchenDoorEntranceLocation, Angle = 179.0600f });

            // kitchen entrance actions
            kitchenDoorEntranceLocation.PossibleActions.Add(new Walk { Performer = player, NextLocation = kitchenSinkLocation, TargetItem = kitchenSinkLocation, Angle = 255.1674f });

            // kitchen sink entrance 
            var washHandsAtSinkAction = new WashHands { Performer = player, NextLocation = kitchenSinkLocation, TargetItem = kitchenSinkLocation };
            kitchenSinkLocation.PossibleActions.Add(washHandsAtSinkAction);
            var goToFridgeAction = new Walk { Performer = player, Prerequisites = new List<StoryActionBase> { washHandsAtSinkAction }, NextLocation = kitchenFridgeLocation, TargetItem = kitchenFridgeLocation, Angle = 145.4264f };
            washHandsAtSinkAction.ClosingAction = goToFridgeAction;
            kitchenSinkLocation.PossibleActions.Add(goToFridgeAction);

            // kitchen fridge
            var foodTypes = Enum.GetValues(typeof(Food.eFoodType));
            var food = new Food { ModelId = (int)foodTypes.GetValue(new Random().Next(foodTypes.Length)) };
            var pickupFoodAction = new PickUpObject { Performer = player, NextLocation = kitchenFridgeLocation, TargetItem = food };
            kitchenFridgeLocation.PossibleActions.Add(pickupFoodAction);
            var goToGasCookerAction = new Walk { Performer = player, Prerequisites = new List<StoryActionBase> { pickupFoodAction }, NextLocation = kitchenGasCookerLocation, TargetItem = kitchenGasCookerLocation, Angle = 350.4216f };
            pickupFoodAction.ClosingAction = goToGasCookerAction;
            kitchenFridgeLocation.PossibleActions.Add(goToGasCookerAction);

            // kitchen gas cooker
            var cookAction = new Cook { Performer = player, NextLocation = kitchenGasCookerLocation, TargetItem = kitchenGasCookerLocation };
            kitchenGasCookerLocation.PossibleActions.Add(cookAction);
            var goToChair1Action = new Walk { Performer = player, Prerequisites = new List<StoryActionBase> { cookAction }, NextLocation = kitchenChairLocationTuple.Item1, TargetItem = kitchenChairLocationTuple.Item1, Angle = kitchenChairLocationTuple.Item2 };
            cookAction.ClosingAction = goToChair1Action;
            kitchenGasCookerLocation.PossibleActions.Add(goToChair1Action);

            // eat at chair 
            var sitDownAtTable1Action = new SitDown(SitDown.eHow.atDesk) { Performer = player, NextLocation = kitchenChairLocationTuple.Item1, TargetItem = kitchenChair1 };
            kitchenChairLocationTuple.Item1.PossibleActions.Add(sitDownAtTable1Action);
            var standUpFromTableAction = new StandUp(StandUp.eHow.fromDesk) { Performer = player, Prerequisites = new List<StoryActionBase> { sitDownAtTable1Action }, NextLocation = kitchenChairLocationTuple.Item1, TargetItem = kitchenChair1 };
            sitDownAtTable1Action.ClosingAction = standUpFromTableAction;
            kitchenChairLocationTuple.Item1.PossibleActions.Add(standUpFromTableAction);
            
            var endScenario = new EndSimulation { Prerequisites = new List<StoryActionBase> { standUpFromTableAction } };
            standUpFromTableAction.ClosingAction = endScenario;
            kitchenChairLocationTuple.Item1.PossibleActions.Add(endScenario);


            #endregion


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
