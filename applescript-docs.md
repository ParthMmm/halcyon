<artifact identifier="apple-music-applescript-ref" type="application/vnd.ant.code" language="markdown" title="Apple Music AppleScript Reference">
# Apple Music AppleScript Dictionary Reference

A comprehensive guide to scripting Apple Music using AppleScript.

---

## Standard Suite

Common commands available in most AppleScript-compatible applications.

### Commands

#### print
Print specified objects.

**Syntax:** `print [specifier] [options]`

**Parameters:**
- `specifier` - List of objects to print
- `print dialog` (boolean) - Show print dialog
- `with properties` (print settings) - Print settings to use
- `kind` - Printout type: `track listing`, `album listing`, or `cd insert`
- `theme` (text) - Theme name for formatting

#### close
Close an object.

**Syntax:** `close specifier`

#### count
Return the number of elements of a particular class within an object.

**Syntax:** `count specifier each type`

**Returns:** integer

#### delete
Delete an element from an object.

**Syntax:** `delete specifier`

#### duplicate
Duplicate one or more objects.

**Syntax:** `duplicate specifier [to location specifier]`

**Returns:** specifier to the duplicated object(s)

#### exists
Verify if an object exists.

**Syntax:** `exists specifier`

**Returns:** boolean (true if exists, false if not)

#### make
Create a new element.

**Syntax:** `make new type [at location specifier] [with properties record]`

**Returns:** specifier to the new object(s)

#### move
Move playlist(s) to a new location.

**Syntax:** `move playlist to location specifier`

#### open
Open specified objects.

**Syntax:** `open specifier`

#### run
Run the application.

**Syntax:** `run`

#### quit
Quit the application.

**Syntax:** `quit`

#### save
Save specified objects.

**Syntax:** `save specifier`

---

### print settings

Properties (all read-only):
- `copies` (integer) - Number of copies to print
- `collating` (boolean) - Should copies be collated?
- `starting page` (integer) - First page to print
- `ending page` (integer) - Last page to print
- `pages across` (integer) - Logical pages laid across a physical page
- `pages down` (integer) - Logical pages laid down a physical page
- `error handling` - How errors are handled: `standard` or `detailed`
- `requested print time` (date) - When to print the document
- `printer features` (list of text) - Printer-specific options
- `fax number` (text) - Fax number
- `target printer` (text) - Target printer

---

## Music Suite

Commands specific to Apple Music.

### Playback Commands

#### play
Play the current track or a specified track/file.

**Syntax:** `play [specifier] [once boolean]`

**Parameters:**
- `specifier` - Item to play (optional)
- `once` (boolean) - If true, play once then stop

#### pause
Pause playback.

**Syntax:** `pause`

#### playpause
Toggle between playing and paused states.

**Syntax:** `playpause`

#### stop
Stop playback.

**Syntax:** `stop`

#### next track
Advance to the next track in the current playlist.

**Syntax:** `next track`

#### previous track
Return to the previous track in the current playlist.

**Syntax:** `previous track`

#### back track
Reposition to beginning of current track, or go to previous track if already at start.

**Syntax:** `back track`

#### fast forward
Skip forward in a playing track.

**Syntax:** `fast forward`

#### rewind
Skip backwards in a playing track.

**Syntax:** `rewind`

#### resume
Disable fast forward/rewind and resume playback.

**Syntax:** `resume`

---

### Library Management Commands

#### add
Add one or more files to a playlist.

**Syntax:** `add list of file [to location specifier]`

**Returns:** track reference to added track(s)

#### convert
Convert one or more files or tracks.

**Syntax:** `convert list of specifier`

**Returns:** track reference to converted track(s)

#### download
Download a cloud track or playlist.

**Syntax:** `download item`

**Parameters:**
- `item` - Shared track, URL track, or playlist to download

#### export
Export a source or playlist.

**Syntax:** `export item [as format] [to file]`

**Parameters:**
- `as` - Export format: `plain text`, `Unicode text`, `XML`, `M3U`, or `M3U8`
- `to` (file) - Destination of the export

**Returns:** text (exported data if not written to file)

#### refresh
Update file track information from the current information in the track's file.

**Syntax:** `refresh file track`

#### search
Search a playlist for tracks matching the search string.

**Syntax:** `search playlist for text [only search_area]`

**Parameters:**
- `only` - Area to search: `albums`, `all`, `artists`, `composers`, `displayed`, or `names` (default: all)

**Returns:** track reference to found track(s)

#### select
Select specified objects.

**Syntax:** `select specifier`

#### reveal
Reveal and select a track or playlist.

**Syntax:** `reveal item`

---

## Classes and Objects

### application

The Apple Music application itself.

**Elements:**
- AirPlay devices
- Browser windows
- Encoders
- EQ presets
- EQ windows
- Miniplayer windows
- Playlists
- Playlist windows
- Sources
- Tracks
- Video windows
- Visuals
- Windows

**Properties:**
- `AirPlay enabled` (boolean, read-only) - Is AirPlay enabled?
- `converting` (boolean, read-only) - Is a track being converted?
- `current AirPlay devices` (list of AirPlay device) - Currently selected AirPlay device(s)
- `current encoder` (encoder) - Currently selected encoder (MP3, AIFF, WAV, etc.)
- `current EQ preset` (EQ preset) - Currently selected equalizer preset
- `current playlist` (playlist, read-only) - Playlist containing currently targeted track
- `current stream title` (text, read-only) - Name of current track in playing stream
- `current stream URL` (text, read-only) - URL of playing stream
- `current track` (track, read-only) - Current targeted track
- `current visual` (visual) - Currently selected visual plugin
- `EQ enabled` (boolean) - Is equalizer enabled?
- `fixed indexing` (boolean) - Track indices independent of play order?
- `frontmost` (boolean) - Is this the active application?
- `full screen` (boolean) - Is application using entire screen?
- `name` (text, read-only) - Application name
- `mute` (boolean) - Has sound output been muted?
- `player position` (real) - Player's position within current track (seconds)
- `player state` (read-only) - Player state: `stopped`, `playing`, `paused`, `fast forwarding`, or `rewinding`
- `selection` (specifier, read-only) - Selection visible to user
- `shuffle enabled` (boolean) - Are songs played randomly?
- `shuffle mode` - Shuffle mode: `songs`, `albums`, or `groupings`
- `song repeat` - Repeat mode: `off`, `one`, or `all`
- `sound volume` (integer) - Sound output volume (0-100)
- `version` (text, read-only) - Application version
- `visuals enabled` (boolean) - Are visuals being displayed?

---

### AirPlay device

An AirPlay-capable device.

**Contained by:** application

**Properties:**
- `active` (boolean, read-only) - Is device currently being played to?
- `available` (boolean, read-only) - Is device currently available?
- `kind` (read-only) - Device type: `computer`, `AirPort Express`, `Apple TV`, `AirPlay device`, `Bluetooth device`, `HomePod`, `TV`, or `unknown`
- `network address` (text, read-only) - Network (MAC) address
- `protected` (boolean, read-only) - Is device password/passcode-protected?
- `selected` (boolean) - Is device currently selected?
- `supports audio` (boolean, read-only) - Does device support audio playback?
- `supports video` (boolean, read-only) - Does device support video playback?
- `sound volume` (integer) - Output volume for device (0-100)

---

### track

A playable audio source.

**Contained by:** application, playlists

**Contains:** artworks

**Properties:**

#### Basic Information
- `name` (text) - Track name
- `artist` (text) - Artist/source of track
- `album` (text) - Album name
- `album artist` (text) - Album artist
- `composer` (text) - Composer
- `genre` (text) - Music/audio genre
- `kind` (text, read-only) - Text description of track
- `media kind` - Media type: `song`, `music video`, `movie`, `TV show`, or `unknown`

#### Metadata
- `year` (integer) - Year recorded/released
- `comment` (text) - Freeform notes
- `grouping` (text) - Grouping/piece (often for classical movements)
- `lyrics` (text) - Track lyrics
- `description` (text) - Track description
- `long description` (text) - Long description

#### Classical Music
- `work` (text) - Work name
- `movement` (text) - Movement name
- `movement count` (integer) - Total movements in work
- `movement number` (integer) - Index of movement in work

#### Album Information
- `compilation` (boolean) - Is this from a compilation album?
- `disc count` (integer) - Total discs in source album
- `disc number` (integer) - Index of disc containing this track
- `track count` (integer) - Total tracks on source album
- `track number` (integer) - Index on source album
- `gapless` (boolean) - Is this from a gapless album?

#### Playback
- `duration` (real, read-only) - Length in seconds
- `time` (text, read-only) - Length in MM:SS format
- `start` (real) - Start time in seconds
- `finish` (real) - Stop time in seconds
- `volume adjustment` (integer) - Relative volume adjustment (-100% to +100%)
- `EQ` (text) - Name of EQ preset

#### Status and Ratings
- `enabled` (boolean) - Is track checked for playback?
- `bookmarkable` (boolean) - Is playback position remembered?
- `bookmark` (real) - Bookmark time in seconds
- `shufflable` (boolean) - Is track included when shuffling?
- `unplayed` (boolean) - Is track unplayed?
- `rating` (integer) - Track rating (0-100)
- `rating kind` (read-only) - Rating type: `user` or `computed`
- `favorited` (boolean) - Is track favorited?
- `disliked` (boolean) - Is track disliked?

#### Album Ratings
- `album rating` (integer) - Album rating (0-100)
- `album rating kind` (read-only) - Album rating type: `user` or `computed`
- `album favorited` (boolean) - Is album favorited?
- `album disliked` (boolean) - Is album disliked?

#### Play Statistics
- `played count` (integer) - Times played
- `played date` (date) - Last played date/time
- `skipped count` (integer) - Times skipped
- `skipped date` (date) - Last skipped date/time

#### Technical Details
- `bit rate` (integer, read-only) - Bit rate in kbps
- `sample rate` (integer, read-only) - Sample rate in Hz
- `size` (double integer, read-only) - Size in bytes
- `bpm` (integer) - Tempo in beats per minute

#### Cloud and Purchase
- `cloud status` (read-only) - iCloud status: `unknown`, `purchased`, `matched`, `uploaded`, `ineligible`, `removed`, `error`, `duplicate`, `subscription`, `prerelease`, `no longer available`, or `not uploaded`
- `downloader account` (text, read-only) - Downloader account
- `downloader name` (text, read-only) - Downloader name
- `purchaser account` (text, read-only) - Purchaser account
- `purchaser name` (text, read-only) - Purchaser name

#### Dates and IDs
- `date added` (date, read-only) - Date added to playlist
- `modification date` (date, read-only) - Content modification date
- `release date` (date, read-only) - Release date
- `database ID` (integer, read-only) - Common unique ID for track
- `persistent ID` (text, read-only) - Hexadecimal ID (doesn't change over time)

#### Podcasts and TV
- `category` (text) - Track category
- `episode ID` (text) - Episode ID
- `episode number` (integer) - Episode number
- `season number` (integer) - Season number
- `show` (text) - Show name

#### Sorting Overrides
- `sort name` (text) - Override for sorting by name
- `sort album` (text) - Override for sorting by album
- `sort artist` (text) - Override for sorting by artist
- `sort album artist` (text) - Override for sorting by album artist
- `sort composer` (text) - Override for sorting by composer
- `sort show` (text) - Override for sorting by show name

---

### file track

A track representing an audio file (MP3, AIFF, etc.).

**Inherits from:** track

**Contained by:** library playlists, subscription playlists, user playlists

**Properties:**
- `location` (file) - Location of file represented by this track

---

### URL track

A track representing a network stream.

**Inherits from:** track

**Contained by:** library playlists, radio tuner playlists, subscription playlists, user playlists

**Properties:**
- `address` (text) - URL for this track

---

### shared track

A track residing in a shared library.

**Inherits from:** track

**Contained by:** library playlists, user playlists

---

### audio CD track

A track on an audio CD.

**Inherits from:** track

**Contained by:** audio CD playlists

**Properties:**
- `location` (file, read-only) - Location of file represented by this track

---

### playlist

A list of tracks/streams.

**Contained by:** application, sources

**Contains:** tracks, artworks

**Properties:**
- `name` (text) - Playlist name
- `description` (text) - Playlist description
- `duration` (integer, read-only) - Total length of all tracks (seconds)
- `time` (text, read-only) - Length of all tracks in MM:SS format
- `size` (integer, read-only) - Total size of all tracks (bytes)
- `parent` (playlist, read-only) - Containing folder (if any)
- `special kind` (read-only) - Special type: `none`, `folder`, `Genius`, `Library`, `Music`, or `Purchased Music`
- `visible` (boolean, read-only) - Is playlist visible in Source list?
- `favorited` (boolean) - Is playlist favorited?
- `disliked` (boolean) - Is playlist disliked?

---

### library playlist

The main library playlist.

**Inherits from:** playlist

**Contains:** file tracks, URL tracks, shared tracks

---

### user playlist

Custom playlists created by the user.

**Inherits from:** playlist

**Contains:** file tracks, URL tracks, shared tracks

**Properties:**
- `shared` (boolean) - Is playlist shared?
- `smart` (boolean, read-only) - Is this a Smart Playlist?
- `genius` (boolean, read-only) - Is this a Genius Playlist?

---

### folder playlist

A folder that contains other playlists.

**Inherits from:** user playlist → playlist

---

### audio CD playlist

A playlist representing an audio CD.

**Inherits from:** playlist

**Contains:** audio CD tracks

**Properties:**
- `artist` (text) - CD artist
- `compilation` (boolean) - Is this a compilation album?
- `composer` (text) - CD composer
- `disc count` (integer) - Total discs in album
- `disc number` (integer) - Index of this disc in source album
- `genre` (text) - CD genre
- `year` (integer) - Year recorded/released

---

### radio tuner playlist

The radio tuner playlist.

**Inherits from:** playlist

**Contains:** URL tracks

---

### subscription playlist

A subscription playlist from Apple Music.

**Inherits from:** playlist

**Contains:** file tracks, URL tracks

---

### source

A media source (library, CD, device, etc.).

**Contained by:** application

**Contains:** audio CD playlists, library playlists, playlists, radio tuner playlists, subscription playlists, user playlists

**Properties:**
- `name` (text) - Source name
- `kind` (read-only) - Source type: `library`, `audio CD`, `MP3 CD`, `radio tuner`, `shared library`, `iTunes Store`, or `unknown`
- `capacity` (double integer, read-only) - Total size if fixed size
- `free space` (double integer, read-only) - Free space if fixed size

---

### artwork

A piece of art within a track or playlist.

**Contained by:** playlists, tracks

**Properties:**
- `data` (picture) - Artwork data as picture
- `raw data` (any) - Artwork data in original format
- `description` (text) - Artwork description
- `downloaded` (boolean, read-only) - Was this downloaded by Music?
- `format` (type, read-only) - Data format for this artwork
- `kind` (integer) - Kind or purpose of this artwork

---

### encoder

Converts a track to a specific file format.

**Contained by:** application

**Properties:**
- `name` (text) - Encoder name
- `format` (text, read-only) - Data format created by encoder

---

### EQ preset

Equalizer preset configuration.

**Contained by:** application

**Properties:**
- `name` (text) - Preset name
- `band 1` (real) - 32 Hz band level (-12.0 dB to +12.0 dB)
- `band 2` (real) - 64 Hz band level (-12.0 dB to +12.0 dB)
- `band 3` (real) - 125 Hz band level (-12.0 dB to +12.0 dB)
- `band 4` (real) - 250 Hz band level (-12.0 dB to +12.0 dB)
- `band 5` (real) - 500 Hz band level (-12.0 dB to +12.0 dB)
- `band 6` (real) - 1 kHz band level (-12.0 dB to +12.0 dB)
- `band 7` (real) - 2 kHz band level (-12.0 dB to +12.0 dB)
- `band 8` (real) - 4 kHz band level (-12.0 dB to +12.0 dB)
- `band 9` (real) - 8 kHz band level (-12.0 dB to +12.0 dB)
- `band 10` (real) - 16 kHz band level (-12.0 dB to +12.0 dB)
- `preamp` (real) - Preamp level (-12.0 dB to +12.0 dB)
- `modifiable` (boolean, read-only) - Can this preset be modified?
- `update tracks` (boolean) - Should tracks referencing this preset be updated when renamed/deleted?

---

### visual

A visual plugin.

**Contained by:** application

**Properties:**
- `name` (text) - Visual name

---

### window

Any window.

**Contained by:** application

**Properties:**
- `name` (text) - Window name
- `bounds` (rectangle) - Boundary rectangle for window
- `position` (point) - Upper left position
- `visible` (boolean) - Is window visible?
- `closeable` (boolean, read-only) - Does window have close button?
- `collapseable` (boolean, read-only) - Does window have collapse button?
- `collapsed` (boolean) - Is window collapsed?
- `resizable` (boolean, read-only) - Is window resizable?
- `zoomable` (boolean, read-only) - Is window zoomable?
- `zoomed` (boolean) - Is window zoomed?
- `full screen` (boolean) - Is window full screen?

---

### browser window

The main browser window.

**Inherits from:** window

**Properties:**
- `selection` (specifier, read-only) - Selected tracks
- `view` (playlist) - Playlist currently displayed

---

### playlist window

A sub-window showing a single playlist.

**Inherits from:** window

**Properties:**
- `selection` (specifier, read-only) - Selected tracks
- `view` (playlist, read-only) - Playlist displayed in window

---

### miniplayer window

The miniplayer window.

**Inherits from:** window

---

### video window

The video window.

**Inherits from:** window

---

### EQ window

The equalizer window.

**Inherits from:** window

---

## Internet Suite

Standard terms for Internet scripting.

### open location

Opens an iTunes Store or audio stream URL.

**Syntax:** `open location [text]`

**Parameters:**
- `text` - The URL to open

---

## Common Item Properties

All items share these base properties:

- `class` (type, read-only) - Class of the item
- `container` (specifier, read-only) - Container of the item
- `id` (integer, read-only) - ID of the item
- `index` (integer, read-only) - Index in internal application order
- `name` (text) - Name of the item
- `persistent ID` (text, read-only) - Hexadecimal ID that doesn't change
- `properties` (record) - Every property of the item

---

## Usage Examples

### Play a specific track
```applescript
tell application "Music"
    play track 1 of playlist "My Playlist"
end tell

Get current track information
applescripttell application "Music"
    set trackName to name of current track
    set trackArtist to artist of current track
end tell
Search for tracks
applescripttell application "Music"
    set foundTracks to search playlist "Library" for "Beatles"
end tell
Set volume
applescripttell application "Music"
    set sound volume to 50
end tell
Export playlist
applescripttell application "Music"
    export playlist "My Playlist" to file "~/Desktop/playlist.m3u" as M3U
end tell
