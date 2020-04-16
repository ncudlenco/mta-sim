using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace SyntheticVideo2language.Story.Api
{
    public abstract class StoryTextLoggerBase
    {
        public string Path { get; set; }
        public abstract void Log(string text, params object[] vs);
    }
}
