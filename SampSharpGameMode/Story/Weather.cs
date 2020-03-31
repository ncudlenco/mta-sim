using System;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;
using SyntheticVideo2language.StoryGenerator.Api;
using Vision2language.StoryGenerator.Api;

namespace SampSharp.SyntheticGameMode.Story
{
    public class Weather : IGenericStoryItem
    {
        public int Id { get; set; }

        protected Weather(int id, string description)
        {
            this.Id = id;
            this.Description = description;
        }

        public static Weather[] WeatherTypes = new Weather[]
        {
            new Weather (0, "very warm"),
            new Weather (1, "warm"),
            new Weather (2, "very warm with smog"),
            new Weather (3, "warm with smog"),
            new Weather (4, "cloudy"),
            new Weather (5, "warm"),
            new Weather (6, "very warm"),
            new Weather (7, "cloudy"),
            new Weather (8, "rainy"),
            new Weather (9, "foggy"),
            new Weather (10, "warm"),
            new Weather (11, "very warm with heat weaves"),
            new Weather (12, "cloudy"),
            new Weather (13, "very warm"),
            new Weather (14, "warm"),
            new Weather (15, "cloudy"),
            new Weather (16, "rainy"),
            new Weather (17, "very warm"),
            new Weather (18, "warm"),
            new Weather (19, "dust storm")
        };

        public string Description { get; set; }
        public int TopologicalOrder { get => 0; set { } }

        public eStoryItemType StoryItemType => eStoryItemType.TimeOfDay;

        public List<IGenericStoryItem> StoryItems { get; set; }

        public async Task<bool> ApplyInGameAsync(params object[] parameters)
        {
            if (parameters.Length != 1)
            {
                throw new IndexOutOfRangeException();
            }

            var player = parameters[0] as Player;
            player.SetWeather(this.Id);

            player.SendClientMessage(" on a " + this.Description + " weather.");

            await Task.Delay(100);
            return true;
        }
    }
}
