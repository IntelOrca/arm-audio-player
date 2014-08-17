using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace noteseq
{
	class TrackLibrary
	{
		private readonly List<Track> mTracks = new List<Track>();
		private readonly List<string> mNoteSequenceKeys = new List<string>();
		private readonly List<Note[]> mNoteSequenceValues = new List<Note[]>();

		public void AddTrack(Track track)
		{
			mTracks.Add(track);
		}

		public void AddNoteSequence(string label, Note[] notes)
		{
			mNoteSequenceKeys.Add(label);
			mNoteSequenceValues.Add(notes);
		}

		public int GetNoteSequenceIndex(string label)
		{
			return mNoteSequenceKeys.IndexOf(label);
		}

		public string GetNoteSequenceKey(int index)
		{
			return mNoteSequenceKeys[index];
		}

		public Track[] Tracks
		{
			get { return mTracks.ToArray(); }
		}

		public Note[][] NoteSequences
		{
			get { return mNoteSequenceValues.ToArray(); }
		}
	}
}
