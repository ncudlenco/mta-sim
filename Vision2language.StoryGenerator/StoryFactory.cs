using System;
using System.Collections.Generic;
using System.Threading;
using Vision2language.StoryGenerator.Api;

namespace Vision2language.StoryGenerator
{
    public abstract class StoryFactory<T> where T :
    StoryFactory<T>
    {
        private static readonly ThreadLocal<T> Lazy =
        new ThreadLocal<T>(() =>
            Activator.CreateInstance(typeof(T), true) as T);

        public static T Instance => Lazy.Value;

        public List<IGenericStoryItem> CurrentStory { get; protected set; }
        public abstract List<IGenericStoryItem> GenerateRandom(params object[] parameters);
    }
}
