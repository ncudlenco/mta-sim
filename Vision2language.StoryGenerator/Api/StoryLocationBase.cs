using SyntheticVideo2language.Story.Data;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace SyntheticVideo2language.Story.Api
{
    public abstract class StoryLocationBase : IStoryItem
    {
        public StoryLocationBase()
        {
            this.PossibleActions = new List<StoryActionBase>();
        }
        public abstract string Description { get; set; }
        public eStoryItemType StoryItemType => eStoryItemType.Location;
        public abstract List<StoryActionBase> PossibleActions { get; set; }
        public abstract StoryActionBase GetNextRandomValidAction();
    }
}
