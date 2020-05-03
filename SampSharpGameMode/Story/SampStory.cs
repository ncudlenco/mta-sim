using SampSharp.Streamer.World;
using SampSharp.SyntheticGameMode.Commands;
using SampSharp.SyntheticGameMode.Enums;
using SampSharp.SyntheticGameMode.Extensions;
using SampSharp.SyntheticGameMode.Story.Actions;
using ScreenRecorderLib;
using SyntheticVideo2language.Story.Api;
using SyntheticVideo2language.Story.Data;
using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace SampSharp.SyntheticGameMode.Story
{
    public class SampStory : StoryBase<SampStory>
    {
        private static readonly bool LOG_DATA = true;
        private static readonly string LOG_DIRECTORY_PATH = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
        public override int MAX_ACTIONS => int.MaxValue;
        public bool IsRunning { get; set; }
        private Guid StoryId = Guid.NewGuid();
        public override List<StoryEpisodeBase> Episodes => new List<StoryEpisodeBase> {
            new Episodes.House3()
        };
        public StoryEpisodeBase CurrentEpisode { get; internal set; }

        //public List<IStoryItem> GenerateRandom(object[] parameters)
        //{
        //    if (parameters.Length == 0 || !(parameters[0] is Player))
        //    {
        //        return null;
        //    }

        //    var random = new Random();
        //    List<IStoryItem> storyItems = new List<IStoryItem>();

        //    var player = parameters[0] as Player;
        //    storyItems.Add(player);
        //    player.TargetStoryItems = new List<IGenericStorySequence>();
        //    player.TargetStoryItems.Add(Actions.SetPlayerSkin.PlayerSkins.PickRandom());
        //    player.PlayerSkin = player.TargetStoryItems.First() as Actions.SetPlayerSkin;
        //    //Spawn Location
        //    //this.CurrentLocation = Location.LosSantos[(int)CityLocation.SantaMariaBeach];
        //    //this.CurrentLocation = Location.LosSantos[(int)CityLocation.SantaMariaBeachInWater];
        //    this.CurrentLocation = Location.Interiors[(int)Interior.House1];
        //    player.TargetStoryItems.Add(this.CurrentLocation);
        //    player.TargetStoryItems.Add(new TimeOfDay(random.Next(23), random.Next(59)));
        //    player.TargetStoryItems.Add(Weather.WeatherTypes[random.Next(Weather.WeatherTypes.Length)]);
        //    player.TargetStoryItems.Add(new Actions.Bed());
        //    //if (random.Next(2) == 1)
        //    //{
        //    //    player.StoryItems.Add(new Actions.Smoke());
        //    //}
        //    //else
        //    //{
        //    //player.StoryItems.Add(new Actions.Walk());
        //    //    player.StoryItems.Add(new Actions.PutObjectOnGround(Actions.PutObjectOnGround.GetAllValidObjects().PickRandom()));
        //    //    player.StoryItems.Add(new Actions.LayOnObject(player.StoryItems.Last().StoryItems.First()));
        //    //}
        //    //player.StoryItems.Add(new Actions.EndSimulation());

        //    //Create a player vehicle
        //    return storyItems;
        //}

        public async override Task<bool> Play()
        {
            if (this.Actor == null)
            {
                throw new Exception("SampStory.Play: The actor was null.");
            }

            foreach (var item in DynamicObject.All)
            {
                item.Dispose();
            }
            this.History = new FixedSizeList<StoryActionBase>(MAX_ACTIONS);
            string videoFilePath = null;
            this.Recorder = null;
            this.ElapsedTime = new Stopwatch();
            string loggingFilePath = null;
            if (LOG_DATA)
            {
                int left = 10;
                int top = 40;
                int right = 640;
                int bottom = 480;
                //DeviceName in the form \\.\DISPLAY1. Typically you would enumerate system monitors and select one. Default monitor is used if no valid input is given.
                string monitorDeviceName = System.Windows.Forms.Screen.PrimaryScreen.DeviceName;
                RecorderOptions options = new RecorderOptions
                {
                    //DisplayOptions = new DisplayOptions(monitorDeviceName, left, top, right, bottom)
                };
                videoFilePath = Path.Combine(LOG_DIRECTORY_PATH, StoryId + ".mp4");
                loggingFilePath = Path.Combine(LOG_DIRECTORY_PATH, StoryId + ".txt");
                this.Recorder = Recorder.CreateRecorder(options);
                this.Recorder.Record(videoFilePath);
            }
            this.ElapsedTime.Start();

            Logger = new SampLogger { Path = loggingFilePath, ShowOnScreen = true };

            var skin = SetPlayerSkin.PlayerSkins.PickRandom();
            skin.TargetItem = this.Actor;
            skin.Performer = this.Actor;
            await skin.ApplyAsync();
            this.CurrentEpisode = Episodes.PickRandom();
            await this.CurrentEpisode.Initialize(this.Actor);
            var res = await this.CurrentEpisode.PlayAsync(this.Actor);

            this.ElapsedTime.Stop();
            if (LOG_DATA)
            {
                this.Recorder.Stop();
                if (File.Exists(videoFilePath))
                {
                    string argument = "/select, \"" + videoFilePath + "\"";
                    Process.Start("explorer.exe", argument);
                }
            }
            return res;
        }
    }
}
