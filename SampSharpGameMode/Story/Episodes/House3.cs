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
            #region Episode objects

            this.Objects = new List<SampStoryObjectBase>();
            this.ValidStartingLocations = new List<StoryLocationBase>();

            var streamer = BaseMode.Instance.Services.GetService<IStreamer>();
            streamer.ProcessActiveItems();
            player.OnUpdate(new SampSharp.GameMode.Events.PlayerUpdateEventArgs() { PreventPropagation = false });
            streamer.Update(player, player.Position);

            #endregion

            // declare possible locations
            var livingRoomDoorEntranceLocation = new Location(2496.0610, -1694.2596, 1014.7422, 181.8800, this.InteriorId, "livin room near door");
            var kitchenDoorEntranceLocation = new Location(2496.0244, -1708.2274, 1014.7422, 177.1800, this.InteriorId, "kitchen entrance");
            var kitchenSinkLocation = new Location(2500.0151, -1708.6577, 1014.7422, 267.4209, this.InteriorId, "sink");
            var kitchenGasCookerLocation = new Location(2499.2888, -1706.7673, 1014.7422, 6.4351, this.InteriorId, "gas cooker");
            var kitchenFridgeLocation = new Location(2498.3386, -1711.3533, 1014.7422, 169.6598, this.InteriorId, "fridge");

            // declare valid starting locations
            ValidStartingLocations.Add(livingRoomDoorEntranceLocation);

            #region Create locations graph
            // living room entrance actions
            livingRoomDoorEntranceLocation.PossibleActions.Add(new Walk { Performer = player, NextLocation = kitchenDoorEntranceLocation, TargetItem = kitchenDoorEntranceLocation, Angle = 179.0600f });

            // kitchen entrance actions
            kitchenDoorEntranceLocation.PossibleActions.Add(new Walk { Performer = player, NextLocation = kitchenSinkLocation, TargetItem = kitchenSinkLocation, Angle = 266.1674f });
            kitchenDoorEntranceLocation.PossibleActions.Add(new Walk { Performer = player, NextLocation = kitchenGasCookerLocation, TargetItem = kitchenGasCookerLocation, Angle = 303.4544f });
            kitchenDoorEntranceLocation.PossibleActions.Add(new Walk { Performer = player, NextLocation = kitchenFridgeLocation, TargetItem = kitchenFridgeLocation, Angle = 214.7803f });

            // kitchen sink entrance 
            kitchenSinkLocation.PossibleActions.Add(new WashHands { Performer = player, NextLocation = kitchenSinkLocation, TargetItem = kitchenSinkLocation });
            kitchenSinkLocation.PossibleActions.Add(new Walk { Performer = player, NextLocation = kitchenGasCookerLocation, TargetItem = kitchenGasCookerLocation, Angle = 12.3651f });
            kitchenSinkLocation.PossibleActions.Add(new Walk { Performer = player, NextLocation = kitchenFridgeLocation, TargetItem = kitchenFridgeLocation, Angle = 152.4264f });

            // kitchen gas cooker
            kitchenGasCookerLocation.PossibleActions.Add(new Cook { Performer = player, NextLocation = kitchenGasCookerLocation, TargetItem = kitchenGasCookerLocation });
            kitchenGasCookerLocation.PossibleActions.Add(new Walk { Performer = player, NextLocation = kitchenSinkLocation, TargetItem = kitchenSinkLocation, Angle = 211.6236f });
            kitchenGasCookerLocation.PossibleActions.Add(new Walk { Performer = player, NextLocation = kitchenFridgeLocation, TargetItem = kitchenFridgeLocation, Angle = 165.8766f });

            // kitchen fridge 
            kitchenFridgeLocation.PossibleActions.Add(new Walk { Performer = player, NextLocation = kitchenSinkLocation, TargetItem = kitchenSinkLocation, Angle = 316.8812f });
            kitchenFridgeLocation.PossibleActions.Add(new Walk { Performer = player, NextLocation = kitchenGasCookerLocation, TargetItem = kitchenGasCookerLocation, Angle = 350.4216f });
            kitchenFridgeLocation.PossibleActions.Add(new EndSimulation());

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
