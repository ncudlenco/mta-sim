using System;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;

namespace SyntheticVideo2language.Story.Api
{
    public abstract class StoryActionBase : IStoryItem
    {
        public StoryActionBase()
        {
            this.ActionId = Guid.NewGuid().ToString();
            this.Prerequisites = new List<StoryActionBase>();
        }
        protected virtual string ActionId { get; set; }
        public eStoryItemType StoryItemType => eStoryItemType.Action;
        public virtual StoryLocationBase NextLocation { get; set; }
        public abstract string Description { get; set; }
        public abstract IStoryActor Performer { get; set; }
        public abstract IStoryItem TargetItem { get; set; }
        /// <summary>
        /// Other actions which must be applied before in the same location in order for the current action to be valid.
        /// Ex: While sitting at a desk, for the StandUp action to be valid, the SitDown action is a prerequisite
        /// </summary>
        public virtual List<StoryActionBase> Prerequisites { get; set; }
        /// <summary>
        /// The action that makes this action end.
        /// Ex: This action is SitDown and the closing action is StandUp
        /// </summary>
        public virtual StoryActionBase ClosingAction { get; set; }
        public abstract Task<bool> ApplyAsync(params object[] parameters);

        public override bool Equals(object obj)
        {
            var other = obj as StoryActionBase;
            return other != null && other.ActionId == this.ActionId;
        }

        public override int GetHashCode()
        {
            int hash = 13;
            hash = (hash * 7) + this.ActionId.GetHashCode();
            return hash;
        }

        public override string ToString()
        {
            return this.Description;
        }
    }
}
