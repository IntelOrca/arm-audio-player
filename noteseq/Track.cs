using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace noteseq
{
	class Track
	{
		private readonly List<string[]> mChannels = new List<string[]>();

		public string Name { get; set; }
		public int BPM { get; set; }
		public List<string[]> Channels { get { return mChannels; } }
	}
}
