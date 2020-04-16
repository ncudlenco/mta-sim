using SyntheticVideo2language.Story.Api;
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace SampSharp.SyntheticGameMode.Story
{
    public class SampLogger : StoryTextLoggerBase
    {
        public bool ShowOnScreen { get; set; }
        public override void Log(string text, params object[] vs)
        {
            Player player = null;
            var logText = SampStory.Instance.ElapsedTime.Elapsed.ToString(@"hh\:mm\:ss") + " " + text;
            if (!string.IsNullOrEmpty(this.Path))
            {
                File.AppendAllText(this.Path, logText + Environment.NewLine);
            }
            if (ShowOnScreen && vs.Length > 0 && vs[0] is Player)
            {
                player = vs[0] as Player;
                if (player != null)
                {
                    player.SendClientMessage(logText);
                }
            }
        }
    }
}
