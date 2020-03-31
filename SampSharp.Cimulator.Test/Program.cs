using SampSharp.Core;
using SampSharp.Core.Logging;
using System;

namespace SampSharp.Cimulator.Test
{
    class Program
    {
        static void Main(string[] args)
        {
            new GameModeBuilder()
                .Use<GameMode>()
                .UseLogLevel(CoreLogLevel.Verbose)
                .UseStartBehaviour(GameModeStartBehaviour.FakeGmx)
                .Run();
        }
    }
}
