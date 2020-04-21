using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace SampSharp.SyntheticGameMode.Extensions
{
    public static class EnumerableExtension
    {
        public static T PickRandom<T>(this IEnumerable<T> source, Func<T, bool> predicate = null)
        {
            return source.PickRandom(1, predicate).FirstOrDefault();
        }

        public static IEnumerable<T> PickRandom<T>(this IEnumerable<T> source, int count, Func<T,bool> predicate = null)
        {
            if (predicate == null)
            {
                return source.Shuffle().Take(count);
            }
            return source.Where(predicate).Shuffle().Take(count);
        }

        public static IEnumerable<T> Shuffle<T>(this IEnumerable<T> source)
        {
            return source.OrderBy(x => Guid.NewGuid());
        }
    }
}
