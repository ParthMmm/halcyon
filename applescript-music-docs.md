Awesome—here’s a focused, LLM-friendly cheat sheet that covers everything practical you can do with Playlists & Folders and Tracks & Metadata in Apple Music via AppleScript, plus bullet-proof snippets you can paste into Script Editor.

Apple Music AppleScript — Playlists/Folders & Tracks/Metadata (Cheat Sheet)

Use application id "com.apple.Music" for robustness.
Folder detection: special kind of playlist = folder vs none (normal).

⸻

0) Reusable helpers (drop at bottom of any script)

property APPID : "com.apple.Music"

on is_folder(p)
	try
		tell application id APPID to set sk to special kind of p
		if sk is not none then return true
	on error
		-- fallback: folders own subfolders
		try
			tell application id APPID to if (count of folder playlists of p) > 0 then return true
		end try
	end try
	return false
end is_folder

on folder_path_text(p)
	-- Build "Root ▸ Sub ▸ Leaf" folder path for playlist p
	set parts to {}
	tell application id APPID
		try
			set parentPl to parent of p
		on error
			set parentPl to missing value
		end try
	end tell
	repeat while parentPl is not missing value
		if my is_folder(parentPl) then set end of parts to (name of parentPl as text)
		tell application id APPID
			try
				set parentPl to parent of parentPl
			on error
				exit repeat
			end try
		end tell
	end repeat
	if (count parts) = 0 then return ""
	-- reverse parts (root→leaf)
	set out to {}
	repeat with i from (count parts) to 1 by -1
		set end of out to item i of parts
	end repeat
	return my join(out, " ▸ ")
end folder_path_text

on join(L, sep)
	set tid to AppleScript's text item delimiters
	set AppleScript's text item delimiters to sep
	set s to L as text
	set AppleScript's text item delimiters to tid
	return s
end join


⸻

1) Playlists & Folders

Create / Delete / Rename

tell application id APPID
	if not (running) then launch
	-- new normal playlist
	set p to make new user playlist with properties {name:"My New List"}

	-- new folder
	set f to make new folder playlist with properties {name:"My Folder"}

	-- rename
	set name of p to "Renamed List"

	-- delete
	delete playlist "Old Stuff"
end tell

Move playlists between folders (change container)

tell application id APPID
	set p to playlist "Renamed List"
	set f to folder playlist "My Folder"
	move p to f
end tell

Not possible: set the order of playlists within a folder (no writable index / before/after).

Enumerate playlists (flat, folders only, or both)

tell application id APPID
	-- all user playlists (includes folders)
	set pls to every user playlist

	-- only normal (non-folder) playlists
	set normals to (every playlist whose special kind is none)

	-- only folder playlists
	set folders to (every playlist whose special kind is folder)
end tell

Reveal a playlist/folder in the sidebar (select it in UI)

tell application id APPID
	reveal playlist "Renamed List"
	activate
end tell

Get a playlist’s folder path (for display/logging)

tell application id APPID
	set p to playlist "Renamed List"
end tell
set pathTxt to folder_path_text(p) -- uses helper above

Search library (like the search field) and add to a playlist

set q to "skeler"
tell application id APPID
	set hits to search playlist "Library" for q only artists
	repeat with t in hits
		duplicate t to playlist "Renamed List"
	end repeat
end tell

Export a playlist (M3U8 / XML / text)

tell application id APPID
	export playlist "Renamed List" as M3U8 ¬
		to POSIX file "/Users/me/Desktop/renamed-list.m3u8"
end tell

Copy playlists between folders (by name)

tell application id APPID
	set src to playlist "Renamed List"
	set dstFolder to folder playlist "Another Folder"
	-- make a new copy playlist
	set copyP to make new user playlist at end of playlists of dstFolder ¬
		with properties {name:(name of src) & " (Copy)"}
	duplicate (every track of src) to copyP
end tell

Safely delete all empty playlists in a folder

tell application id APPID
	set f to folder playlist "My Folder"
	set kids to user playlists of f
	repeat with p in kids
		if my is_folder(p) is false then
			if (count of tracks of p) = 0 then delete p
		end if
	end repeat
end tell


⸻

2) Tracks & Metadata

Read current “Now Playing” & player state

tell application id APPID
	set t to current track
	set info to {name:name of t, artist:artist of t, album:album of t}
	set pos to player position
	set st to player state -- playing | paused | stopped | fast forwarding | rewinding
end tell

Iterate tracks in a playlist (robust; avoid index assumptions)

tell application id APPID
	set p to playlist "Renamed List"
	set trks to every track of p
	repeat with tr in trks
		set nm to name of tr
		set ar to artist of tr
		set dur to duration of tr -- seconds (real, r/o)
		-- do stuff...
	end repeat
end tell

Edit common metadata (rating, BPM, lyrics, genre…)

tell application id APPID
	set tr to first track of playlist "Renamed List"
	set rating of tr to 80          -- 0..100
	set bpm of tr to 128
	set lyrics of tr to "Sing along…"
	set genre of tr to "Drum & Bass"
	set album artist of tr to "Various"
end tell

Bulk-edit: set rating for all tracks in a playlist

tell application id APPID
	set trks to every track of playlist "Renamed List"
	repeat with tr in trks
		set rating of tr to 60
	end repeat
end tell

Move tracks between playlists (copy, then optionally remove)

tell application id APPID
	set src to playlist "Renamed List"
	set dst to playlist "Another List"
	duplicate (every track of src) to dst
	-- optional: clear source after copy
	-- delete (every track of src)
end tell

Add/import files to a playlist

tell application id APPID
	add {POSIX file "/Users/me/Music/drop/one.aiff", ¬
	     POSIX file "/Users/me/Music/drop/two.aiff"} to playlist "Renamed List"
end tell

Convert selected tracks using current encoder (returns new tracks)

tell application id APPID
	set newOnes to convert (selection)
end tell

Artwork: read, write (PNG/JPEG) to/from tracks

-- write file data to first track's first artwork
set srcPath to POSIX file "/Users/me/Desktop/cover.jpg"
set picData to (read srcPath as picture)
tell application id APPID
	set tr to first track of playlist "Renamed List"
	if (count of artworks of tr) = 0 then
		make new artwork at end of artworks of tr with properties {data:picData}
	else
		set data of artwork 1 of tr to picData
	end if
end tell

-- extract artwork to file
tell application id APPID
	set tr to first track of playlist "Renamed List"
	set img to data of artwork 1 of tr
end tell
set outPath to POSIX file "/Users/me/Desktop/extracted.icns"
set fref to open for access outPath with write permission
set eof of fref to 0
write img to fref
close access fref

Read “library facts” for filtering/dedupe (IDs, play counts, etc.)

tell application id APPID
	set tr to first track of playlist "Renamed List"
	set meta to {persistentID:(persistent ID of tr), databaseID:(database ID of tr), ¬
		playedCount:(played count of tr), dateAdded:(date added of tr), kind:(kind of tr)}
end tell

Search within a specific playlist (artist/title/album scopes)

tell application id APPID
	set p to playlist "Renamed List"
	set hits to search p for "breakcore" only names -- or: artists | albums | composers | all | displayed
end tell


⸻

3) Player Controls (quick reference)

tell application id APPID
	play -- or: play track 1 of playlist "Renamed List"
	pause
	playpause
	next track
	previous track
	set player position to 42
	set shuffle enabled to true
	set shuffle mode to songs -- songs | albums | groupings
	set song repeat to all    -- off | one | all
	set sound volume to 35    -- 0..100
end tell


⸻

4) Limitations & Tips
	•	Cannot set playlist order inside a folder (no writable index, no move before/after).
	•	Track order within a playlist is also not directly controllable via a “set index” API; order follows UI sort rules and manual arrangement.
	•	Smart Playlists: you can detect (smart) but not author/edit rule logic via AppleScript.
	•	Cloud/Apple-Music specifics: some properties reflect cloud state but aren’t writable.
	•	Use reveal to make the UI select a playlist before GUI-scripting any manual actions.
	•	Prefer IDs (e.g., persistent ID) for reliable matching/dedup instead of names.

⸻

5) High-leverage “toolbelt” scripts

Export all non-folder playlists → JSON (name, persistentId, folderPath)

property APPID : "com.apple.Music"

tell application id APPID
	if not (running) then launch
	set items to {}
	repeat with p in (every playlist whose special kind is none)
		set row to "{\"name\":\"" & my esc(name of p) & "\",\"persistentId\":\"" & (persistent ID of p) & "\",\"folderPath\":\"" & my esc(folder_path_text(p)) & "\"}"
		set end of items to row
	end repeat
end tell
set json to "[" & my join(items, ",") & "]"
set the clipboard to json
display dialog "Copied " & (count items) & " playlists to clipboard as JSON."

on esc(s)
	set s to my join((every text item of s as text) of s, "") -- coerce
	set s to my replace_all(s, "\\", "\\\\")
	set s to my replace_all(s, "\"", "\\\"")
	set s to my replace_all(s, return, "\\n")
	set s to my replace_all(s, linefeed, "\\n")
	set s to my replace_all(s, tab, "\\t")
	return s
end esc

on replace_all(s, f, r)
	set tid to AppleScript's text item delimiters
	set AppleScript's text item delimiters to f
	set parts to every text item of s
	set AppleScript's text item delimiters to r
	set s2 to parts as text
	set AppleScript's text item delimiters to tid
	return s2
end replace_all

-- include helpers: join, is_folder, folder_path_text

Batch-rename playlists in a folder (safe prefixing example)

property APPID : "com.apple.Music"
property PREFIX : "DNB - "

tell application id APPID
	set f to folder playlist "My Folder"
	repeat with p in (user playlists of f)
		if my is_folder(p) is false then
			set nm to name of p as text
			if nm does not start with PREFIX then set name of p to PREFIX & nm
		end if
	end repeat
end tell
-- uses is_folder helper


⸻


