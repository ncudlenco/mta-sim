using System.Collections.Generic;
using System.Collections.Immutable;
using System.Threading.Tasks;

namespace SyntheticVideo2language.Story.Api
{
    public abstract class StoryEpisodeBase
    {
        public abstract StoryTimeOfDayBase StoryTimeOfDay {get;set;}
        public abstract StoryWeatherBase StoryWeather { get;set;}
        /// <summary>
        /// The location where the episode starts. Could be one random from a point of interest, ore set specifically during episode transitions.
        /// Ex: After some actions, the actor enters inside a house. The starting location must be set to the house entrance.
        /// </summary>
        public abstract StoryLocationBase StartingLocation { get; set; }
        /// <summary>
        /// Different spatially defined points of interest.
        /// Ex: Near the bed, near the sofa, near the sink, door from bedroom to living
        /// </summary>
        public abstract List<StoryLocationBase> ValidStartingLocations { get; protected set; }
        public abstract Task<bool> Initialize(params object[] parameters);
        public abstract Task<bool> PlayAsync(params object[] parameters);
    }
}