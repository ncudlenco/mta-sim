using ScreenRecorderLib;
using SyntheticVideo2language.Story.Data;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Threading;
using System.Threading.Tasks;

namespace SyntheticVideo2language.Story.Api
{
    public abstract class StoryBase<T> where T :
    StoryBase<T>
    {
        private static readonly ThreadLocal<T> Lazy =
        new ThreadLocal<T>(() =>
            Activator.CreateInstance(typeof(T), true) as T);

        public static T Instance => Lazy.Value;
        public abstract int MAX_ACTIONS { get; }
        public Recorder Recorder { get; protected set; }
        public Stopwatch ElapsedTime { get; protected set; }
        public StoryTextLoggerBase Logger { get; protected set; }
        public IStoryActor Actor { get; set; }
        public FixedSizeList<StoryActionBase> History { get; protected set; }
        public abstract List<StoryEpisodeBase> Episodes { get; }
        public abstract Task<bool> Play();
    }
}
