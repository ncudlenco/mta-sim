using SampSharp.SyntheticGameMode.Commands;
using SampSharp.SyntheticGameMode.Enums;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Vision2language.StoryGenerator;
using Vision2language.StoryGenerator.Api;

namespace SampSharp.SyntheticGameMode.Story
{
    public class SampStoryGenerator : StoryFactory<SampStoryGenerator>
    {
        public SpawnPoint CurrentLocation { get; internal set; }
        public Player CurrentPlayer { get; internal set; }
        public bool IsRunning { get; set; }
        public override List<IGenericStoryItem> GenerateRandom(object[] parameters)
        {
            if (parameters.Length == 0 || !(parameters[0] is Player))
            {
                return null;
            }

            var random = new Random();
            List<IGenericStoryItem> storyItems = new List<IGenericStoryItem>();
            CurrentStory = storyItems;

            var player = parameters[0] as Player;
            this.CurrentPlayer = player;
            storyItems.Add(player);
            player.StoryItems = new List<IGenericStoryItem>();
            player.StoryItems.Add(Actions.SetPlayerSkin.PlayerSkins.PickRandom());
            player.PlayerSkin = player.StoryItems.First() as Actions.SetPlayerSkin;
            //Location
            this.CurrentLocation = new SpawnPoint((int)City.LosSantos, (int)CityLocation.SantaMariaBeach);
            //this.CurrentLocation = new SpawnPoint((int)City.LosSantos, (int)CityLocation.SantaMariaBeachInWater);
            player.StoryItems.Add(this.CurrentLocation);
            player.StoryItems.Add(new TimeOfDay(random.Next(23), random.Next(59)));
            player.StoryItems.Add(Weather.WeatherTypes[random.Next(Weather.WeatherTypes.Length)]);
            //player.StoryItems.Add(new Actions.Swim());
            if (random.Next(2) == 1)
            {
                player.StoryItems.Add(new Actions.Smoke());
            }
            else
            {
                player.StoryItems.Add(new Actions.Walk());
                player.StoryItems.Add(new Actions.PutObjectOnGround(Actions.PutObjectOnGround.GetAllValidObjects().PickRandom()));
                player.StoryItems.Add(new Actions.LayOnObject(player.StoryItems.Last().StoryItems.First()));
            }
            player.StoryItems.Add(new Actions.EndSimulation());

            //Create a player vehicle
            return storyItems;
        }
    }
}
