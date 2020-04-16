using System;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;

namespace SyntheticVideo2language.Story.Api
{
    public abstract class StoryWeatherBase : IStoryItem
    {
        public abstract string Description { get; set; }
        public eStoryItemType StoryItemType => eStoryItemType.Weather;

        public abstract Task<bool> ApplyAsync(params object[] parameters);
    }
}
