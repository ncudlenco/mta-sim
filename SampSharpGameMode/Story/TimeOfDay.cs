using System;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;
using SyntheticVideo2language.Story.Api;

namespace SampSharp.SyntheticGameMode.Story
{
    public class TimeOfDay : StoryTimeOfDayBase
    {
        public int Hour { get; set; }
        public int Minutes { get; set; }

        public TimeOfDay(int hour, int minutes)
        {
            this.Hour = hour;
            this.Minutes = minutes;
        }

        public override string Description
        {
            get
            {
                var time = (this.Hour + (this.Minutes < 30 ? 0 : 1)) % 24;
                if (time > 5 && time < 11)
                {
                    return "in the morning";
                }
                else if (time == 12)
                {
                    return "at noon";
                }
                else if (time > 11 && time < 16)
                {
                    return "during the day";
                }
                else if (time > 16 && time < 19)
                {
                    return "in the evening";
                }
                else if (time == 0)
                {
                    return "in the middle of the night";
                }
                else
                {
                    return "during the night";
                }
            }
            set { }
        }

        public async override Task<bool> ApplyAsync(params object[] parameters)
        {
            if (parameters.Length != 1)
            {
                throw new IndexOutOfRangeException();
            }

            var player = parameters[0] as Player;
            await Task.Delay(100);

            player.SetTime(this.Hour, this.Minutes);
            SampStory.Instance.Logger.Log(" " + this.Description, player);
            await Task.Delay(100);

            return true;
        }
    }
}
