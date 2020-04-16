using SampSharp.Core;
using SampSharp.Core.Logging;
using System;

namespace SampSharpGameMode
{
    public class Program
    {
        [STAThread]
        public static void Main(string[] args)
        {
            new GameModeBuilder()
                .Use<BaseMode>()
                .UseLogLevel(CoreLogLevel.Info)
                .UseStartBehaviour(GameModeStartBehaviour.FakeGmx)
                .Run();
        }
    }
}
