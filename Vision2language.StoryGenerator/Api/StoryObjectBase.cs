using System;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;

namespace SyntheticVideo2language.Story.Api
{
    public abstract class StoryObjectBase : IStoryItem
    {
        public abstract string Description { get; set; }
        public eStoryItemType StoryItemType => eStoryItemType.Object;

        public abstract Task<bool> CreateAsync(params object[] parameters);
        public abstract Task<bool> DestroyAsync(params object[] parameters);
    }
}
