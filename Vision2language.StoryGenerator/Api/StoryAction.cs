using System;
using System.Collections.Generic;
using System.Text;

namespace Vision2language.StoryGenerator.Api
{
    public interface IStoryAction : IGenericStoryItem
    {
        bool ApplyInGame();

        //Example: 
        //1. A certain kind of skin, actor will be spawned at a certain location, in a certain time of day with certain weather conditions, in a certain vehicle
        //A black male (on a bike) is on the middle of the beach in the evening. It is raining or it is a calm warm weather or https://wiki.sa-mp.com/wiki/WeatherID
    }
}
