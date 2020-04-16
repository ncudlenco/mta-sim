using SyntheticVideo2language.Story.Api;
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;

namespace SyntheticVideo2language.Story.Api
{
    public interface IStoryItem
    {
        string Description { get; set; }
        eStoryItemType StoryItemType { get; }
    }
}
