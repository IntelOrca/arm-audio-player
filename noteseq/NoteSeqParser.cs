using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace noteseq
{
	class NoteSeqParser
	{
		enum Token
		{
			Invalid,
			Whitespace,
			Key,
			Number,
			StartLength,
			MidLength,
			EndLength,
			EOF,

			IncludeSpecifier,				// <
			TrackLabelSpecifier,			// @
			NoteSequenceLabelSpecifier,		// $
			AttributeSpecifier,				// %
			Text,
		}

		private static readonly char[] ValidKeyChars = new char[] { 'A', 'B', 'C', 'D', 'E', 'F', 'G', '#', '\'', '~' };

		private readonly Stack<StringReader> mStackedReaders = new Stack<StringReader>();
		private StringReader mReader;
		private string mNextToken;
		private Note mNote = new Note(Key.C, 4, 0, 32);
		private string mError = null;

		private TrackLibrary mTrackLibrary;
		private Track mCurrentTrack;
		private readonly HashSet<string> mLabelDefinitions = new HashSet<string>();
		private readonly HashSet<string> mLabelReferences = new HashSet<string>();

		public NoteSeqParser()
		{
			mTrackLibrary = new TrackLibrary();
			mLabelDefinitions.Clear();
			mLabelReferences.Clear();
		}

		public bool Read(string path)
		{
			path = Path.GetFullPath(path);
			mReader = new StringReader(File.ReadAllText(path));

			Token token;

			while ((token = GetNextToken()) != Token.EOF) {
				switch (token) {
				case Token.IncludeSpecifier:
					StringBuilder sb = new StringBuilder();
					for (; ; ) {
						if (mReader.Peek() == -1) {
							mError = "Expected >";
							return false;
						} else if ((char)mReader.Peek() == '>') {
							mStackedReaders.Push(mReader);
							Read(Path.Combine(Path.GetDirectoryName(path), sb.ToString()));
							mReader = mStackedReaders.Pop();
							break;
						} else {
							sb.Append((char)mReader.Read());
						}
					}
					break;
				case Token.TrackLabelSpecifier: {
						string name = ReadLabelNameDefinition();
						if (String.IsNullOrEmpty(name))
							return false;

						mCurrentTrack = new Track();
						mTrackLibrary.AddTrack(mCurrentTrack);
						break;
					}
				case Token.AttributeSpecifier: {
						if (mCurrentTrack == null) {
							mError = "No track specified";
							return false;
						}

						string name = ReadUntilWhitespace();
						SkipWhitespace();
						switch (name.ToLower()) {
						case "name":
							mCurrentTrack.Name = ReadQuotedText();
							break;
						case "bpm":
							int value = ReadUnsignedNumber();
							if (value == -1)
								return false;
							mCurrentTrack.BPM = value;
							break;
						case "channel":
							List<string> labels = new List<string>();
							do {
								SkipWhitespace();
								name = ReadLabelName();
								if (String.IsNullOrEmpty(name))
									return false;
								labels.Add(name);
								SkipWhitespace();
							} while (Char.IsLetter((char)mReader.Peek()) || (char)mReader.Peek() == '_');
							mCurrentTrack.Channels.Add(labels.ToArray());
							break;
						default:
							mError = String.Format("Unknown attribute: {0}", name);
							break;
						}
						break;
					}
				case Token.NoteSequenceLabelSpecifier: {
						mCurrentTrack = null;

						string name = ReadLabelNameDefinition();
						if (String.IsNullOrEmpty(name))
							return false;

						List<Note> notes = new List<Note>();
						for (;;) {
							SkipWhitespace();
							if (ValidKeyChars.Contains((char)mReader.Peek())) {
								Note note = ReadNote();
								if (note != Note.Empty)
									notes.Add(note);
							} else {
								break;
							}
						}
						mTrackLibrary.AddNoteSequence(name, notes.ToArray());
						break;
					}
				}
			}

			// Check if there are any undefined label references
			mLabelReferences.ExceptWith(mLabelDefinitions);
			if (mLabelReferences.Count > 0) {
				mError = String.Format("Label {0} is undefined", mLabelReferences.First());
				return false;
			}

			return true;
		}

		public Note ReadNote()
		{
			Token token;

			mError = null;
			do {
				token = GetNextToken();
				if (token == Token.EOF)
					return Note.Empty;
			} while (token == Token.Whitespace);

			// First read key
			if (token == Token.Key) {
				mNote.Key = Note.GetKeyFromString(mNextToken);
			} else {
				mError = "Expected key";
				return Note.Empty;
			}

			// Read octave
			token = GetNextToken();
			if (token == Token.Number) {
				mNote.Octave = Convert.ToInt32(mNextToken);
				token = GetNextToken();
			}

			// Read length
			if (token == Token.StartLength) {
				int num, denom;
				if (GetNextToken() == Token.Number) {
					num = Convert.ToInt32(mNextToken);
				} else {
					mError = "Expected length numerator";
					return Note.Empty;
				}

				if (GetNextToken() != Token.MidLength) {
					mError = "Expected /";
					return Note.Empty;
				}

				if (GetNextToken() == Token.Number) {
					denom = Convert.ToInt32(mNextToken);
				} else {
					mError = "Expected length denominator";
					return Note.Empty;
				}

				// Bar length
				mNote.Bars = num / denom;
				mNote.BarFractions = ((256 * num) / denom) % 256;

				if (GetNextToken() != Token.EndLength) {
					mError = "Expected ]";
					return Note.Empty;
				} else {
					token = GetNextToken();
				}
			}

			if (token == Token.Whitespace || token == Token.EOF) {
				return mNote;
			} else {
				mError = "Unexpected characters after note definition";
				return Note.Empty;
			}
		}

		private Token GetNextToken()
		{
			int read = mReader.Read();
			if (read == -1)
				return Token.EOF;
			char c = (char)read;

			// Skip over comments
			while (c == '/') {
				if ((char)mReader.Peek() == '/') {
					mReader.ReadLine();
					c = (char)mReader.Read();
				} else if ((char)mReader.Peek() == '*') {
					mReader.Read();

					// Find end comment
					for (;;) {
						if (mReader.Peek() == -1)
							return Token.Invalid;
						c = (char)mReader.Read();
						if (c == '*' && (char)mReader.Peek() == '/') {
							mReader.Read();
							c = (char)mReader.Read();
							break;
						}
					}
				} else {
					return Token.MidLength;
				}
			}

			if (c == Char.MaxValue)
				return Token.EOF;

			// Whitespace
			if (Char.IsWhiteSpace(c)) {
				SkipWhitespace();
				return Token.Whitespace;
			}

			// Numbers
			if (Char.IsNumber(c)) {
				mNextToken = c.ToString();
				while (Char.IsNumber((char)mReader.Peek())) {
					mNextToken += (char)mReader.Read();
				}
				return Token.Number;
			}

			// Other
			mNextToken = c.ToString();
			switch (c) {
			case '<':
				return Token.IncludeSpecifier;
			case '@':
				return Token.TrackLabelSpecifier;
			case '%':
				return Token.AttributeSpecifier;
			case '$':
				return Token.NoteSequenceLabelSpecifier;
			case '"':
				mNextToken = ReadQuotedText();
				return Token.Text;
			case '[':
				return Token.StartLength;
			case ']':
				return Token.EndLength;
			default:
				while (ValidKeyChars.Contains((char)mReader.Peek())) {
					mNextToken += (char)mReader.Read();
				}
				return Token.Key;
			}
		}

		private string ReadQuotedText()
		{
			// First character should be starting quote
			if ((char)mReader.Read() != '"')
				return String.Empty;

			StringBuilder sb = new StringBuilder();
			for (;;) {
				if (mReader.Peek() == -1) {
					mError = "Expected end quote";
					return null;
				}

				if ((char)mReader.Peek() == '"') {
					mReader.Read();
					if ((char)mReader.Peek() != '"')
						return sb.ToString();
					mReader.Read();
					sb.Append('"');
				}

				sb.Append((char)mReader.Read());
			}
		}

		private string ReadLabelNameDefinition()
		{
			string name = ReadUntilWhitespace();
			if (Regex.IsMatch(name, "^[A-Za-z][A-Za-z0-9_]*:$")) {
				name = name.Remove(name.Length - 1);
				if (mLabelDefinitions.Contains(name)) {
					mError = String.Format("Label {0} is not unique", name);
					return null;
				} else {
					mLabelDefinitions.Add(name);
				}
				return name;
			} else {
				mError = "Invalid label name";
				return null;
			}
		}

		private string ReadLabelName()
		{
			string name = ReadUntilWhitespace();
			if (Regex.IsMatch(name, "^[A-Za-z][A-Za-z0-9_]*$")) {
				mLabelReferences.Add(name);
				return name;
			} else {
				mError = "Invalid label name";
				return null;
			}
		}

		private int ReadUnsignedNumber()
		{
			StringBuilder sb = new StringBuilder();
			for (; ; ) {
				if (mReader.Peek() == -1)
					break;
				char c = (char)mReader.Peek();
				if (!Char.IsNumber(c))
					break;
				mReader.Read();
				sb.Append(c);
			}

			int result;
			if (Int32.TryParse(sb.ToString(), out result))
				return result;
			mError = "Invalid integer";
			return -1;
		}

		private string ReadUntilWhitespace()
		{
			StringBuilder sb = new StringBuilder();
			for (; ; ) {
				if (mReader.Peek() == -1)
					return sb.ToString();
				char c = (char)mReader.Peek();
				if (Char.IsWhiteSpace(c))
					return sb.ToString();
				mReader.Read();
				sb.Append(c);
			}
		}

		private void SkipWhitespace()
		{
			int read;
			for (;;) {
				read = mReader.Peek();
				if (read == -1)
					return;
				if (Char.IsWhiteSpace((char)read))
					mReader.Read();
				else {
					if (SkipComments())
						SkipWhitespace();
					break;
				}
			}
		}

		private bool SkipComments()
		{
			bool noCommentsFound = true;
			char c = (char)mReader.Peek();
			while (c == '/') {
				mReader.Read();
				if ((char)mReader.Peek() == '/') {
					noCommentsFound = false;
					mReader.ReadLine();
					c = (char)mReader.Peek();
				} else if ((char)mReader.Peek() == '*') {
					noCommentsFound = false;
					mReader.Read();

					// Find end comment
					for (; ; ) {
						if (mReader.Peek() == -1)
							return true;
						c = (char)mReader.Read();
						if (c == '*' && (char)mReader.Peek() == '/') {
							mReader.Read();
							c = (char)mReader.Peek();
							break;
						}
					}
				} else {
					break;
				}
			}

			return !noCommentsFound;
		}

		public string Error
		{
			get { return mError; }
		}

		public TrackLibrary TrackLibrary
		{
			get { return mTrackLibrary; }
		}
	}
}
