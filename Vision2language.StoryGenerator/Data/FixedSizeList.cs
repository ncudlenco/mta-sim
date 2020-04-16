using System;
using System.Collections.Generic;

namespace SyntheticVideo2language.Story.Data
{
    public class FixedSizeList<T> : List<T>
    {
        public int Size { get; private set; }
        public FixedSizeList(int size)
        {
            Size = size;
        }

        public new void Add(T obj)
        {
            base.Add(obj);
            while (base.Count > Size)
            {
                base.RemoveAt(0);
            }
        }

        public T GetBeforeLast()
        {
            if (base.Count < 2)
            {
                throw new IndexOutOfRangeException();
            }
            return base[base.Count - 2];
        }
    }
}
