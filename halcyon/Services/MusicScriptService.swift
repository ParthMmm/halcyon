//
//  MusicScriptService.swift
//  halcyon
//
//  Created by Parth Mangrola on 10/1/25.
//

import Foundation

enum MusicScriptError: Error, LocalizedError {
    case musicAppNotRunning
    case scriptExecutionFailed(String)
    case invalidResponse
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .musicAppNotRunning:
            return "Music app is not running. Please open the Music app and try again."
        case .scriptExecutionFailed(let message):
            return "Failed to execute AppleScript: \(message)"
        case .invalidResponse:
            return "Received invalid response from Music app."
        case .permissionDenied:
            return "Permission denied. Please grant automation access to Music app in System Settings > Privacy & Security > Automation."
        }
    }
}

@AppleScriptActor
class MusicScriptService {

    // Cache the last AppleScript error so callers can map to typed errors
    private var lastAppleScriptError: NSDictionary?

    // Allow construction from any actor (used by SwiftUI views)
    nonisolated init() {}

    // Escape for AppleScript string literal
    nonisolated private func escapeAS(_ s: String) -> String {
        return s.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
    }

    // MARK: - Check if Music app is running

    func isMusicAppRunning() -> Bool {
        // Pure AppleScript check that does not trigger Automation prompt
        let script = """
        if application id "com.apple.Music" is running then
            return "running"
        else
            return "notRunning"
        end if
        """

        guard let result = executeScript(script), let str = result as? String else { return false }
        return str == "running"
    }

    // MARK: - Get all folder playlists

    // Returns list of folder names (plain strings to avoid crossing actors with model initializers)
    func getFolders() throws -> [String] {
        let script = """
        -- Ensure Music is running and wait until ready (max ~5s)
        try
            if application id "com.apple.Music" is not running then
                do shell script "open -b com.apple.Music"
            end if
        end try
        repeat with i from 1 to 50
            if application id "com.apple.Music" is running then exit repeat
            delay 0.1
        end repeat

        try
            tell application id "com.apple.Music"
                with timeout of 15 seconds
                    -- Fast, direct enumeration of folder playlists
                    return name of every folder playlist
                end timeout
            end tell
        on error errMsg number errNum
            error errMsg number errNum
        end try
        """

        guard let result = executeScript(script) else {
            // Map common AppleScript errors to typed errors
            if let errorNum = (lastAppleScriptError?[NSAppleScript.errorNumber] as? NSNumber)?.intValue {
                switch errorNum {
                case -1743, -10004:
                    throw MusicScriptError.permissionDenied
                case -600, -10810:
                    throw MusicScriptError.musicAppNotRunning
                default:
                    break
                }
            }
            throw MusicScriptError.scriptExecutionFailed("Could not get folders")
        }

        // Parse the result - handle empty array case
        if let folderNames = result as? [String] {
            return folderNames
        } else if let folderName = result as? String {
            // Single folder case or empty string
            if folderName.isEmpty {
                return []
            }
            return [folderName]
        } else if let _ = result as? [Any], (result as! [Any]).isEmpty {
            // Empty array case
            return []
        } else {
            // No folders found - return empty array instead of error
            return []
        }
    }

     // MARK: - Get all folders with their user playlists (single pass)

       // Returns: (rootPlaylists: [(name, persistentID, dateString?)], folderGroups: [(folderName, [(name, persistentID, dateString?)])])
       func getAllFoldersWithPlaylists() throws -> ([(String, String, String?)], [(String, [(String, String, String?)])]) {
         let script = """
         -- Ensure Music is running and wait until ready (max ~5s)
         try
             if application id "com.apple.Music" is not running then
                 do shell script "open -b com.apple.Music"
             end if
         end try
         repeat with i from 1 to 50
             if application id "com.apple.Music" is running then exit repeat
             delay 0.1
         end repeat

         try
             tell application id "com.apple.Music"
                 with timeout of 60 seconds
                     -- Get all user playlists (flat list)
                     set allUserPlaylists to every user playlist

                      -- Collect root playlists and folder groups separately
                      set rootRecs to {} -- list of {name, persistentId, dateStr}
                      set folderGroups to {} -- list of {folderName, { {name, persistentId, dateStr} }}

                      repeat with p in allUserPlaylists
                          try
                              if (special kind of p) is none then
                                  set nm to name of p
                                  set pid to (persistent ID of p)

                                  -- Get earliest track date as proxy for playlist creation date
                                  set dateStr to ""
                                  try
                                      set trackList to every track of p
                                      if (count of trackList) > 0 then
                                          set earliestDate to missing value
                                          repeat with tr in trackList
                                              try
                                                  set tDate to date added of tr
                                                  if earliestDate is missing value or tDate comes before earliestDate then
                                                      set earliestDate to tDate
                                                  end if
                                              end try
                                          end repeat
                                          if earliestDate is not missing value then
                                              set dateStr to earliestDate as text
                                          end if
                                      end if
                                  end try

                                  try
                                      set parentName to name of (parent of p)
                                      set foundGroup to false
                                      repeat with group in folderGroups
                                          if (item 1 of group) is parentName then
                                              set foundGroup to true
                                              set end of (item 2 of group) to {nm, pid, dateStr}
                                              exit repeat
                                          end if
                                      end repeat
                                      if not foundGroup then
                                          set end of folderGroups to {parentName, {{nm, pid, dateStr}}}
                                      end if
                                  on error
                                      -- No parent -> root level
                                      set end of rootRecs to {nm, pid, dateStr}
                                  end try
                              end if
                          end try
                      end repeat

                      -- Return as nested array: [rootRecs, folderGroups]
                      return {rootRecs, folderGroups}
                 end timeout
             end tell
         on error errMsg number errNum
             error errMsg number errNum
         end try
         """

        guard let result = executeScript(script) else {
            if let errorNum = (lastAppleScriptError?[NSAppleScript.errorNumber] as? NSNumber)?.intValue {
                switch errorNum {
                case -1743, -10004:
                    throw MusicScriptError.permissionDenied
                case -600, -10810:
                    throw MusicScriptError.musicAppNotRunning
                default:
                    let msg = (lastAppleScriptError?[NSAppleScript.errorMessage] as? String) ?? ""
                    throw MusicScriptError.scriptExecutionFailed("Could not get folders with playlists (error \(errorNum): \(msg))")
                }
            }
            throw MusicScriptError.scriptExecutionFailed("Could not get folders with playlists")
        }

        guard let outer = result as? [[Any]], outer.count == 2 else {
             print("Unexpected result format: \(result)")
            return ([], [])
        }

        // First element: root playlists [{name, pid, dateStr}]
        var rootList: [(String, String, String?)] = []
        if let rootArray = outer[0] as? [[Any]] {
            for rec in rootArray {
                if rec.count >= 2 {
                    let nm = rec[0] as? String ?? ""
                    let pid = rec[1] as? String ?? ""
                    let dateStr: String? = rec.count >= 3 ? (rec[2] as? String) : nil
                    rootList.append((nm, pid, dateStr))
                }
            }
        }

        // Second element: folder groups [{folderName, {{name,pid,dateStr}...}}]
        var folderGroups: [(String, [(String, String, String?)])] = []
        if let groups = outer[1] as? [[Any]] {
            for g in groups {
                guard let fname = g.first as? String else { continue }
                var entries: [(String, String, String?)] = []
                if g.count > 1, let plist = g[1] as? [[Any]] {
                    for rec in plist {
                        if rec.count >= 2 {
                            let nm = rec[0] as? String ?? ""
                            let pid = rec[1] as? String ?? ""
                            let dateStr: String? = rec.count >= 3 ? (rec[2] as? String) : nil
                            entries.append((nm, pid, dateStr))
                        }
                    }
                }
                folderGroups.append((fname, entries))
            }
        }

        return (rootList, folderGroups)
    }

    // MARK: - Get playlists in a specific folder

    // Returns list of playlist names
    func getPlaylists(in folderName: String) throws -> [String] {
        let safeName = escapeAS(folderName)
        let script = """
        -- Make sure Music is running and ready (max ~5s)
        try
            if application id "com.apple.Music" is not running then
                do shell script "open -b com.apple.Music"
            end if
        end try
        repeat with i from 1 to 50
            if application id "com.apple.Music" is running then exit repeat
            delay 0.1
        end repeat

        try
            tell application id "com.apple.Music"
                with timeout of 20 seconds
                     set out to {}
                     set targetFolder to first folder playlist whose name is "\(safeName)"
                     repeat with p in (every playlist of targetFolder)
                         try
                             if (class of p is user playlist) then
                                 set nm to name of p
                                 set end of out to nm
                             end if
                         end try
                     end repeat
                    -- Optional: include nested playlists
                    if (count of out) is 0 then
                        set out to my gatherUserPlaylists(targetFolder)
                    end if
                    return out
                end timeout
            end tell
        on error errMsg number errNum
            error errMsg number errNum
        end try

        on gatherUserPlaylists(fld)
            set out to {}
            tell application id "com.apple.Music"
                set ups to (user playlists of fld whose class is not folder playlist)
                repeat with p in ups
                    set nm to name of p
                    set end of out to nm
                end repeat
                set subs to folder playlists of fld
                repeat with f in subs
                    set more to my gatherUserPlaylists(f)
                    repeat with rec in more
                        set end of out to rec
                    end repeat
                end repeat
            end tell
            return out
        end gatherUserPlaylists
        """

        guard let result = executeScript(script) else {
            if let errorNum = (lastAppleScriptError?[NSAppleScript.errorNumber] as? NSNumber)?.intValue {
                switch errorNum {
                case -1743, -10004:
                    throw MusicScriptError.permissionDenied
                case -600, -10810:
                    throw MusicScriptError.musicAppNotRunning
                default:
                    let msg = (lastAppleScriptError?[NSAppleScript.errorMessage] as? String) ?? ""
                    throw MusicScriptError.scriptExecutionFailed("Could not get playlists for folder: \(folderName) (error \(errorNum): \(msg))")
                }
            }
            throw MusicScriptError.scriptExecutionFailed("Could not get playlists for folder: \(folderName)")
        }

        // Parse the result - AppleScript returns a list of playlist names
        if let playlistNames = result as? [String] {
            return playlistNames
        } else {
            // Empty or invalid response
            return []
        }
    }

    // MARK: - Create playlist

    func createPlaylist(named name: String, inFolder folderName: String?) throws {
        let safeName = escapeAS(name)
        let script = """
        -- Ensure Music is running and ready (max ~5s)
        try
            if application id "com.apple.Music" is not running then
                do shell script "open -b com.apple.Music"
            end if
        end try
        repeat with i from 1 to 50
            if application id "com.apple.Music" is running then exit repeat
            delay 0.1
        end repeat

        try
            tell application id "com.apple.Music"
                with timeout of 10 seconds
                    set newPlaylist to make new user playlist with properties {name: "\(safeName)"}
                    if "\(folderName ?? "")" is not "" then
                        set targetFolder to folder playlist "\(escapeAS(folderName!))"
                        move newPlaylist to targetFolder
                    end if
                end timeout
            end tell
        on error errMsg number errNum
            error errMsg number errNum
        end try
        """

        guard executeScript(script) != nil else {
            if let errorNum = (lastAppleScriptError?[NSAppleScript.errorNumber] as? NSNumber)?.intValue {
                switch errorNum {
                case -1743, -10004:
                    throw MusicScriptError.permissionDenied
                case -600, -10810:
                    throw MusicScriptError.musicAppNotRunning
                default:
                    break
                }
            }
            throw MusicScriptError.scriptExecutionFailed("Could not create playlist: \(name)")
        }
    }

    // MARK: - Create folder

    func createFolder(named name: String) throws {
        let safeName = escapeAS(name)
        let script = """
        -- Ensure Music is running and ready (max ~5s)
        try
            if application id "com.apple.Music" is not running then
                do shell script "open -b com.apple.Music"
            end if
        end try
        repeat with i from 1 to 50
            if application id "com.apple.Music" is running then exit repeat
            delay 0.1
        end repeat

        try
            tell application id "com.apple.Music"
                with timeout of 10 seconds
                    make new folder playlist with properties {name: "\(safeName)"}
                end timeout
            end tell
        on error errMsg number errNum
            error errMsg number errNum
        end try
        """

        guard executeScript(script) != nil else {
            if let errorNum = (lastAppleScriptError?[NSAppleScript.errorNumber] as? NSNumber)?.intValue {
                switch errorNum {
                case -1743, -10004:
                    throw MusicScriptError.permissionDenied
                case -600, -10810:
                    throw MusicScriptError.musicAppNotRunning
                default:
                    break
                }
            }
            throw MusicScriptError.scriptExecutionFailed("Could not create folder: \(name)")
        }
    }

    // MARK: - Rename playlist

    func renamePlaylist(from oldName: String, to newName: String) throws {
        let safeOldName = escapeAS(oldName)
        let safeNewName = escapeAS(newName)
        let script = """
        -- Ensure Music is running and ready (max ~5s)
        try
            if application id "com.apple.Music" is not running then
                do shell script "open -b com.apple.Music"
            end if
        end try
        repeat with i from 1 to 50
            if application id "com.apple.Music" is running then exit repeat
            delay 0.1
        end repeat

        try
            tell application id "com.apple.Music"
                with timeout of 10 seconds
                    set targetPlaylist to user playlist "\(safeOldName)"
                    set name of targetPlaylist to "\(safeNewName)"
                end timeout
            end tell
        on error errMsg number errNum
            error errMsg number errNum
        end try
        """

        guard executeScript(script) != nil else {
            if let errorNum = (lastAppleScriptError?[NSAppleScript.errorNumber] as? NSNumber)?.intValue {
                switch errorNum {
                case -1743, -10004:
                    throw MusicScriptError.permissionDenied
                case -600, -10810:
                    throw MusicScriptError.musicAppNotRunning
                default:
                    break
                }
            }
            throw MusicScriptError.scriptExecutionFailed("Could not rename playlist from \(oldName) to \(newName)")
        }
    }

    // MARK: - Delete playlist

    func deletePlaylist(named name: String) throws {
        let safeName = escapeAS(name)
        let script = """
        -- Ensure Music is running and ready (max ~5s)
        try
            if application id \"com.apple.Music\" is not running then
                do shell script \"open -b com.apple.Music\"
            end if
        end try
        repeat with i from 1 to 50
            if application id \"com.apple.Music\" is running then exit repeat
            delay 0.1
        end repeat

        try
            tell application id \"com.apple.Music\"
                with timeout of 15 seconds
                    -- Target a user playlist explicitly; deleting a generic
                    -- 'playlist' can fail if a folder playlist matches the name
                    set targetPlaylist to user playlist \"\(safeName)\"
                    delete targetPlaylist
                end timeout
            end tell
        on error errMsg number errNum
            error errMsg number errNum
        end try
        """

        guard executeScriptAllowingMissingValue(script) else {
            if let errorNum = (lastAppleScriptError?[NSAppleScript.errorNumber] as? NSNumber)?.intValue {
                switch errorNum {
                case -1743, -10004:
                    throw MusicScriptError.permissionDenied
                case -600, -10810:
                    throw MusicScriptError.musicAppNotRunning
                case -1728: // object not found
                    throw MusicScriptError.scriptExecutionFailed("Playlist not found: \(name)")
                default:
                    break
                }
            }
            throw MusicScriptError.scriptExecutionFailed("Could not delete playlist: \(name)")
        }
    }

    // MARK: - Move playlist to specific position within a folder

    func movePlaylist(named playlistName: String, toFolder folderName: String) throws {
        let safeFolderName = escapeAS(folderName)
        let safePlaylistName = escapeAS(playlistName)
        let script = """
        -- Ensure Music is running and ready (max ~5s)
        try
            if application id "com.apple.Music" is not running then
                do shell script "open -b com.apple.Music"
            end if
        end try
        repeat with i from 1 to 50
            if application id "com.apple.Music" is running then exit repeat
            delay 0.1
        end repeat

        try
            tell application id "com.apple.Music"
                with timeout of 10 seconds
                    set targetFolder to folder playlist "\(safeFolderName)"
                    set targetPlaylist to user playlist "\(safePlaylistName)"
                    move targetPlaylist to targetFolder
                end timeout
            end tell
        on error errMsg number errNum
            error errMsg number errNum
        end try
        """

        guard executeScript(script) != nil else {
            if let errorNum = (lastAppleScriptError?[NSAppleScript.errorNumber] as? NSNumber)?.intValue {
                switch errorNum {
                case -1743, -10004:
                    throw MusicScriptError.permissionDenied
                case -600, -10810:
                    throw MusicScriptError.musicAppNotRunning
                default:
                    break
                }
            }
            throw MusicScriptError.scriptExecutionFailed("Could not move playlist: \(playlistName)")
        }
     }

     // MARK: - Get songs/tracks from a playlist

     func getSongs(playlistID: String) throws -> [(name: String, artist: String, album: String, duration: Double, genre: String, year: Int, trackNumber: Int)] {
         let safeID = escapeAS(playlistID)
         let script = """
         -- Ensure Music is running and ready (max ~5s)
         try
             if application id "com.apple.Music" is not running then
                 do shell script "open -b com.apple.Music"
             end if
         end try
         repeat with i from 1 to 50
             if application id "com.apple.Music" is running then exit repeat
             delay 0.1
         end repeat

         try
             tell application id "com.apple.Music"
                 with timeout of 60 seconds
                     set targetPlaylist to first user playlist whose persistent ID is "\(safeID)"
                     set trackList to every track of targetPlaylist
                     set songData to {}

                     repeat with tr in trackList
                         try
                             set trackName to name of tr
                             set trackArtist to artist of tr
                             set trackAlbum to album of tr
                             set trackDuration to duration of tr

                             -- Optional metadata (may not exist)
                             try
                                 set trackGenre to genre of tr
                             on error
                                 set trackGenre to ""
                             end try

                             try
                                 set trackYear to year of tr
                             on error
                                 set trackYear to 0
                             end try

                             try
                                 set trackNum to track number of tr
                             on error
                                 set trackNum to 0
                             end try

                             -- Build tuple: {name, artist, album, duration, genre, year, trackNumber}
                             set songTuple to {trackName, trackArtist, trackAlbum, trackDuration, trackGenre, trackYear, trackNum}
                             set end of songData to songTuple
                         end try
                     end repeat

                     return songData
                 end timeout
             end tell
         on error errMsg number errNum
             error errMsg number errNum
         end try
         """

         guard let result = executeScript(script) else {
             if let errorNum = (lastAppleScriptError?[NSAppleScript.errorNumber] as? NSNumber)?.intValue {
                 switch errorNum {
                 case -1743, -10004:
                     throw MusicScriptError.permissionDenied
                 case -600, -10810:
                     throw MusicScriptError.musicAppNotRunning
                 default:
                     let msg = (lastAppleScriptError?[NSAppleScript.errorMessage] as? String) ?? ""
                     throw MusicScriptError.scriptExecutionFailed("Could not get songs for playlist id: \(playlistID) (error \(errorNum): \(msg))")
                 }
             }
             throw MusicScriptError.scriptExecutionFailed("Could not get songs for playlist id: \(playlistID)")
         }

         // Parse result: array of arrays
         // Each inner array: [name, artist, album, duration, genre, year, trackNumber]
         guard let songs = result as? [[Any]] else {
             return []
         }

         var parsedSongs: [(String, String, String, Double, String, Int, Int)] = []

         for song in songs {
             guard song.count >= 7 else { continue }

             let name = song[0] as? String ?? "Unknown Track"
             let artist = song[1] as? String ?? "Unknown Artist"
             let album = song[2] as? String ?? "Unknown Album"

             // Duration comes as string from AppleScript, parse to Double
             var duration: Double = 0.0
             if let durationStr = song[3] as? String, let dur = Double(durationStr) {
                 duration = dur
             }

             let genre = song[4] as? String ?? ""

             var year: Int = 0
             if let yearStr = song[5] as? String, let yr = Int(yearStr) {
                 year = yr
             }

             var trackNumber: Int = 0
             if let trackNumStr = song[6] as? String, let tn = Int(trackNumStr) {
                 trackNumber = tn
             }

             parsedSongs.append((name, artist, album, duration, genre, year, trackNumber))
         }

        return parsedSongs
     }

     // MARK: - ID-based operations

     func renamePlaylist(id persistentID: String, to newName: String) throws {
        let safeID = escapeAS(persistentID)
        let safeNewName = escapeAS(newName)
        let script = """
        try
            if application id \"com.apple.Music\" is not running then
                do shell script \"open -b com.apple.Music\"
            end if
        end try
        repeat with i from 1 to 50
            if application id \"com.apple.Music\" is running then exit repeat
            delay 0.1
        end repeat
        try
            tell application id \"com.apple.Music\"
                with timeout of 10 seconds
                    set targetPlaylist to first user playlist whose persistent ID is \"\(safeID)\"
                    set name of targetPlaylist to \"\(safeNewName)\"
                end timeout
            end tell
        on error errMsg number errNum
            error errMsg number errNum
        end try
        """

        guard executeScript(script) != nil else {
            if let errorNum = (lastAppleScriptError?[NSAppleScript.errorNumber] as? NSNumber)?.intValue {
                switch errorNum {
                case -1743, -10004: throw MusicScriptError.permissionDenied
                case -600, -10810: throw MusicScriptError.musicAppNotRunning
                default: break
                }
            }
            throw MusicScriptError.scriptExecutionFailed("Could not rename playlist id: \(persistentID)")
        }
     }

     func deletePlaylist(id persistentID: String) throws {
        let safeID = escapeAS(persistentID)
        let script = """
        try
            if application id \"com.apple.Music\" is not running then
                do shell script \"open -b com.apple.Music\"
            end if
        end try
        repeat with i from 1 to 50
            if application id \"com.apple.Music\" is running then exit repeat
            delay 0.1
        end repeat
        try
            tell application id \"com.apple.Music\"
                with timeout of 15 seconds
                    set targetPlaylist to first user playlist whose persistent ID is \"\(safeID)\"
                    delete targetPlaylist
                end timeout
            end tell
        on error errMsg number errNum
            error errMsg number errNum
        end try
        """
        guard executeScriptAllowingMissingValue(script) else {
            if let errorNum = (lastAppleScriptError?[NSAppleScript.errorNumber] as? NSNumber)?.intValue {
                switch errorNum {
                case -1743, -10004: throw MusicScriptError.permissionDenied
                case -600, -10810: throw MusicScriptError.musicAppNotRunning
                case -1728: throw MusicScriptError.scriptExecutionFailed("Playlist not found by id: \(persistentID)")
                default: break
                }
            }
            throw MusicScriptError.scriptExecutionFailed("Could not delete playlist id: \(persistentID)")
        }
     }

     func movePlaylist(id persistentID: String, toFolder folderName: String) throws {
        let safeID = escapeAS(persistentID)
        let safeFolderName = escapeAS(folderName)
        let script = """
        try
            if application id \"com.apple.Music\" is not running then
                do shell script \"open -b com.apple.Music\"
            end if
        end try
        repeat with i from 1 to 50
            if application id \"com.apple.Music\" is running then exit repeat
            delay 0.1
        end repeat
        try
            tell application id \"com.apple.Music\"
                with timeout of 10 seconds
                    set targetFolder to folder playlist \"\(safeFolderName)\"
                    set targetPlaylist to first user playlist whose persistent ID is \"\(safeID)\"
                    move targetPlaylist to targetFolder
                end timeout
            end tell
        on error errMsg number errNum
            error errMsg number errNum
        end try
        """
        guard executeScript(script) != nil else {
            if let errorNum = (lastAppleScriptError?[NSAppleScript.errorNumber] as? NSNumber)?.intValue {
                switch errorNum {
                case -1743, -10004: throw MusicScriptError.permissionDenied
                case -600, -10810: throw MusicScriptError.musicAppNotRunning
                default: break
                }
            }
            throw MusicScriptError.scriptExecutionFailed("Could not move playlist id: \(persistentID)")
        }
     }

     // MARK: - Helper method to execute AppleScript

    private func executeScript(_ script: String) -> Any? {
        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        let output = appleScript?.executeAndReturnError(&error)

        if let error = error {
            lastAppleScriptError = error
            print("AppleScript Error: \(error)")
            return nil
        }

        lastAppleScriptError = nil
        guard let output = output else {
            print("AppleScript returned nil output")
            return nil
        }

        print("AppleScript raw output: \(output)")
        let converted = convertDescriptor(output)
        print("Converted output: \(converted ?? "nil")")
        return converted
    }

    // Execute a script where a successful run may return 'missing value'.
    // Returns true if the script executed without error, regardless of returned descriptor contents.
    private func executeScriptAllowingMissingValue(_ script: String) -> Bool {
        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        _ = appleScript?.executeAndReturnError(&error)
        if let error = error {
            lastAppleScriptError = error
            print("AppleScript Error: \(error)")
            return false
        }
        lastAppleScriptError = nil
        return true
    }

    // MARK: - Helper to convert NSAppleEventDescriptor to Swift types

    private func convertDescriptor(_ descriptor: NSAppleEventDescriptor) -> Any? {
        // Handle list/array first (before checking stringValue)
        let itemCount = descriptor.numberOfItems
        if itemCount > 0 {
            var result: [Any] = []
            for i in 1...itemCount {
                if let item = descriptor.atIndex(i) {
                    if let converted = convertDescriptor(item) {
                        result.append(converted)
                    }
                }
            }
            return result
        }

        // Handle string - safest approach. Always return String to avoid
        // misclassifying numeric-looking names like "2014" as Ints.
        if let stringValue = descriptor.stringValue {
            return stringValue
        }

        return nil
    }

    // MARK: - Date parsing helper

    /// Parse AppleScript date string to Swift Date.
    /// AppleScript format: "Saturday, January 1, 2022 at 12:00:00 PM"
    nonisolated func parseAppleScriptDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString, !dateString.isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm:ss a"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        return formatter.date(from: dateString)
    }
}
