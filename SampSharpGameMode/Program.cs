using SampSharp.Core;
using SampSharp.Core.Logging;

namespace SampSharpGameMode
{
    public class Program
    {
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
