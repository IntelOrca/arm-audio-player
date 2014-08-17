using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace noteseq
{
	enum Key
	{
		Rest,
		C, CSharp, D, DSharp, E, F, FSharp, G, GSharp, A, ASharp, B,
		BSharp = C, DFlat = CSharp, EFlat = DSharp, FFlat = E, ESharp = F, GFlat = FSharp, AFlat = GSharp, BFlat = ASharp, CFlat = B,
	}

	struct Note
	{
		#region Key definitions

		private static Key[] KeyStringLookup = new Key[] {
			Key.Rest,
			Key.C, Key.CSharp, Key.D, Key.DSharp, Key.E, Key.F, Key.FSharp, Key.G, Key.GSharp, Key.A, Key.ASharp, Key.B,
			Key.C, Key.CSharp, Key.DSharp, Key.E, Key.F, Key.FSharp, Key.GSharp, Key.ASharp, Key.B,
		};

		private static String[] StringKeyLookup = new String[] {
			"~",
			"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B",
			"B#", "D'", "E'", "F'", "E#", "G'", "A'", "B'", "C'",
		};

		public static Key GetKeyFromString(string s)
		{
			if (s == "~")
				return Key.Rest;
			for (int i = 0; i < StringKeyLookup.Length; i++)
				if (s.Equals(StringKeyLookup[i], StringComparison.OrdinalIgnoreCase))
					return KeyStringLookup[i];
			return Key.Rest;
		}

		public static string GetStringFromKey(Key key)
		{
			return StringKeyLookup[(int)key];
		}

		#endregion

		private Key mKey;
		private int mOctave;
		private int mBars;
		private int mBarFractions;

		public static Note Empty
		{
			get { return new Note(Key.Rest, 0, 0, 0); }
		}

		public Note(Key key, int octave, int bars, int barfractions)
		{
			mKey = key;
			mOctave = octave;
			mBars = bars;
			mBarFractions = barfractions;
		}

		public override bool Equals(object obj)
		{
			if (!(obj is Note))
				return false;

			Note note = (Note)obj;
			return (mKey == note.mKey && mOctave == note.mOctave && mBars == note.mBars && mBarFractions == note.mBarFractions);
		}

		public override int GetHashCode()
		{
			return 23 ^ mKey.GetHashCode() ^ mOctave.GetHashCode() ^ mBars.GetHashCode() ^ mBarFractions.GetHashCode();
		}

		public override string ToString()
		{
			if (mKey == Key.Rest)
				return String.Format("{0}[{1},{2}]", GetStringFromKey(mKey), mBars, mBarFractions);
			else
				return String.Format("{0}{1}[{2},{3}]", GetStringFromKey(mKey), mOctave, mBars, mBarFractions);
		}

		public static bool operator ==(Note a, Note b)
		{
			return a.Equals(b);
		}

		public static bool operator !=(Note a, Note b)
		{
			return !a.Equals(b);
		}

		public uint WordValue
		{
			get
			{
				uint result = 0;
				result |= (uint)mKey;
				result |= (uint)mOctave << 8;
				result |= (uint)mBars << 16;
				result |= (uint)mBarFractions << 24;
				return result;
			}
		}

		public Key Key
		{
			get { return mKey; }
			set { mKey = value; }
		}

		public int Octave
		{
			get { return mOctave; }
			set { mOctave = value; }
		}

		public double BarLength
		{
			get { return mBars + mBarFractions / 256.0; }
		}

		public int Bars
		{
			get { return mBars; }
			set { mBars = value; }
		}

		public int BarFractions
		{
			get { return mBarFractions; }
			set { mBarFractions = value; }
		}
	}
}
