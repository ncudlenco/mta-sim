using SyntheticVideo2language.StoryGenerator.Api;
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;

namespace Vision2language.StoryGenerator.Api
{
    public interface IGenericStoryItem
    {
        string Description { get; set; }
        int TopologicalOrder { get; set; }
        eStoryItemType StoryItemType { get; }
        List<IGenericStoryItem> StoryItems { get; set; }

        Task<bool> ApplyInGameAsync(params object[] parameters);
    }
}
