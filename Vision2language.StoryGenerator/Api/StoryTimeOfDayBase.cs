using System;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;

namespace SyntheticVideo2language.Story.Api
{
    public abstract class StoryTimeOfDayBase : IStoryItem
    {
        public abstract string Description { get; set; }
        public eStoryItemType StoryItemType => eStoryItemType.TimeOfDay;

        public abstract Task<bool> ApplyAsync(params object[] parameters);

    }
}
