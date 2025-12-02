//
//  MusicLibraryViewModel.swift
//  halcyon
//
//  Created by Parth Mangrola on 10/1/25.
//

import Foundation
import SwiftUI
import Combine

enum FolderFilter: String, CaseIterable {
    case all = "All"
    case foldersOnly = "Folders Only"
    case playlistsOnly = "Playlists Only"
}

@MainActor
class MusicLibraryViewModel: ObservableObject {

    // MARK: - Published Properties

     @Published var folderFilter: FolderFilter = .all
     @Published var searchText: String = ""
     @Published private(set) var allFolders: [Folder] = []  // Unfiltered data
     @Published private(set) var rootPlaylists: [Playlist] = []  // Root-level playlists
     @Published var selectedFolder: Folder?
     @Published var selectedPlaylist: Playlist?
     @Published var selectedPlaylistIDs: Set<Playlist.ID> = []
     @Published private(set) var songs: [Song] = []
     @Published var isLoading: Bool = false
     @Published var isLoadingSongs: Bool = false
     @Published var errorMessage: String?

     // MARK: - Private Properties

     private let musicService: MusicScriptService

     // MARK: - Initialization

     init(musicService: MusicScriptService) {
         self.musicService = musicService
     }

      // MARK: - Computed properties for filtered data

      var folders: [Folder] {
          allFolders
      }

      var filteredFolders: [Folder] {
          let foldersToFilter: [Folder] = switch folderFilter {
          case .all:
              allFolders
          case .foldersOnly:
              allFolders
          case .playlistsOnly:
              []
       }

         if searchText.isEmpty {
             return foldersToFilter
         } else {
             return foldersToFilter.filter { folder in
                 folder.name.localizedCaseInsensitiveContains(searchText) ||
                 folder.playlists.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
             }
         }
     }

      var filteredRootPlaylists: [Playlist] {
          let playlistsToFilter: [Playlist] = switch folderFilter {
          case .all:
              rootPlaylists
          case .foldersOnly:
              []
          case .playlistsOnly:
              rootPlaylists
          }

         if searchText.isEmpty {
             return playlistsToFilter
         } else {
             return playlistsToFilter.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
         }
     }

     // MARK: - Public Methods

    func loadFolders() {
        print("Loading folders...")
        isLoading = true
        errorMessage = nil

        let service = musicService
        Task { [weak self] in
            guard let self else { return }
            do {
                 print("Fetching all folders with playlists...")
                 // Single AppleScript round-trip to avoid per-folder failures
                 let (rootList, folderGroups) = try await service.getAllFoldersWithPlaylists()
                 print("Retrieved \(rootList.count) root playlists and \(folderGroups.count) folders")

                 // Build folders from folder groups (with persistent IDs and dates)
                 let builtFolders = folderGroups.map { (fname, entries) in
                     print("Folder '\(fname)': \(entries.count) playlists")
                     return Folder(name: fname, playlists: entries.map {
                         Playlist(id: $0.1, name: $0.0, dateAdded: service.parseAppleScriptDate($0.2))
                     })
                 }

                 // Build root playlists with persistent IDs and dates
                 let builtRootPlaylists = rootList.map {
                     Playlist(id: $0.1, name: $0.0, dateAdded: service.parseAppleScriptDate($0.2))
                 }
                 print("Built \(builtRootPlaylists.count) root playlists")

                 DispatchQueue.main.async {
                     self.allFolders = builtFolders
                     self.rootPlaylists = builtRootPlaylists
                     self.isLoading = false
                     print("Folders and root playlists loaded successfully")
                     print("📊 Total folders: \(builtFolders.count)")
                     for folder in builtFolders {
                         print("  📁 \(folder.name): \(folder.playlists.count) playlists")
                     }
                 }

             } catch let error as MusicScriptError {
                print("MusicScriptError: \(error)")
                DispatchQueue.main.async {
                    self.errorMessage = error.errorDescription
                    self.isLoading = false
                }
            } catch {
                print("Unexpected error: \(error)")
                DispatchQueue.main.async {
                    self.errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    func selectFolder(_ folder: Folder) {
        selectedFolder = folder
    }



     func sortPlaylists(in folder: Folder, by sortOption: PlaylistSortOption) {
         guard let folderIndex = allFolders.firstIndex(where: { $0.id == folder.id }) else {
             return
         }

         // Check if date-based sorting needs dates to be fetched
         let needsDateSort = (sortOption == .newestFirst || sortOption == .oldestFirst)
         let playlistsMissingDates = folder.playlists.filter { $0.dateAdded == nil }

         if needsDateSort && !playlistsMissingDates.isEmpty {
             // Fetch dates lazily then apply sort
             fetchDatesAndSort(folderIndex: folderIndex, sortOption: sortOption)
             return
         }

         // Apply sort immediately (dates already available or not needed)
         applySortToFolder(folderIndex: folderIndex, sortOption: sortOption)
     }

     /// Fetch dates for playlists missing them, then apply date-based sort
     private func fetchDatesAndSort(folderIndex: Int, sortOption: PlaylistSortOption) {
         let folder = allFolders[folderIndex]
         let idsToFetch = folder.playlists.filter { $0.dateAdded == nil }.map { $0.id }

         guard !idsToFetch.isEmpty else {
             applySortToFolder(folderIndex: folderIndex, sortOption: sortOption)
             return
         }

         isLoading = true
         let service = musicService

         Task { [weak self] in
             guard let self else { return }
             do {
                 let dateMap = try await service.getPlaylistDates(ids: idsToFetch)

                 DispatchQueue.main.async {
                     // Update playlists with fetched dates
                     for i in 0..<self.allFolders[folderIndex].playlists.count {
                         let playlist = self.allFolders[folderIndex].playlists[i]
                         if let dateStr = dateMap[playlist.id], !dateStr.isEmpty {
                             self.allFolders[folderIndex].playlists[i].dateAdded = service.parseAppleScriptDate(dateStr)
                         }
                     }

                     // Update selected folder if needed
                     if self.selectedFolder?.id == self.allFolders[folderIndex].id {
                         self.selectedFolder = self.allFolders[folderIndex]
                     }

                     // Now apply the sort
                     self.applySortToFolder(folderIndex: folderIndex, sortOption: sortOption)
                     self.isLoading = false
                 }
             } catch {
                 DispatchQueue.main.async {
                     self.errorMessage = "Failed to fetch playlist dates: \(error.localizedDescription)"
                     self.isLoading = false
                 }
             }
         }
     }

     /// Apply sorting to a folder's playlists (assumes dates are available if needed)
     private func applySortToFolder(folderIndex: Int, sortOption: PlaylistSortOption) {
         var updatedPlaylists = allFolders[folderIndex].playlists

         switch sortOption {
         case .alphabetical:
             updatedPlaylists.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
         case .reverseAlphabetical:
             updatedPlaylists.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
         case .newestFirst:
             updatedPlaylists.sort { (p1, p2) in
                 switch (p1.dateAdded, p2.dateAdded) {
                 case (.some(let d1), .some(let d2)): return d1 > d2
                 case (.some, .none): return true
                 case (.none, .some): return false
                 case (.none, .none): return false
                 }
             }
         case .oldestFirst:
             updatedPlaylists.sort { (p1, p2) in
                 switch (p1.dateAdded, p2.dateAdded) {
                 case (.some(let d1), .some(let d2)): return d1 < d2
                 case (.some, .none): return true
                 case (.none, .some): return false
                 case (.none, .none): return false
                 }
             }
         case .default:
             break
         }

         allFolders[folderIndex].playlists = updatedPlaylists

         if selectedFolder?.id == allFolders[folderIndex].id {
             selectedFolder = allFolders[folderIndex]
         }
     }



    // no-op helper removed (calls stay on main actor)

     func refreshPlaylists(for folder: Folder) {
          let service = musicService
          Task { [weak self, folder] in
              guard let self else { return }
              do {
                  let (rootList, folderGroups) = try await service.getAllFoldersWithPlaylists()

                  // Update root playlists with dates
                  let updatedRootPlaylists = rootList.map {
                      Playlist(id: $0.1, name: $0.0, dateAdded: service.parseAppleScriptDate($0.2))
                  }
                  DispatchQueue.main.async {
                      self.rootPlaylists = updatedRootPlaylists
                  }

                  // Update folder playlists with dates
                  let entries = folderGroups.first(where: { $0.0 == folder.name })?.1 ?? []
                  let playlists = entries.map {
                      Playlist(id: $0.1, name: $0.0, dateAdded: service.parseAppleScriptDate($0.2))
                  }
                  DispatchQueue.main.async {
                      if let folderIndex = self.allFolders.firstIndex(where: { $0.id == folder.id }) {
                          self.allFolders[folderIndex].playlists = playlists
                          if self.selectedFolder?.id == folder.id {
                              self.selectedFolder = self.allFolders[folderIndex]
                          }
                      }
                  }
              } catch {
                  print("Failed to refresh playlists: \(error)")
              }
          }
      }

     func createPlaylist(named name: String, inFolder folderName: String?) {
         isLoading = true
         errorMessage = nil

         Task { [weak self, name, folderName] in
             guard let self else { return }
             do {
                 let newID = try await musicService.createPlaylist(named: name, inFolder: folderName)
                 DispatchQueue.main.async {
                     // Optimistic local update - add playlist to local state
                     let newPlaylist = Playlist(id: newID, name: name, dateAdded: nil)

                     if let folderName = folderName {
                         // Add to specific folder
                         if let folderIndex = self.allFolders.firstIndex(where: { $0.name == folderName }) {
                             self.allFolders[folderIndex].playlists.append(newPlaylist)
                             if self.selectedFolder?.id == self.allFolders[folderIndex].id {
                                 self.selectedFolder = self.allFolders[folderIndex]
                             }
                         }
                     } else {
                         // Add to root playlists
                         self.rootPlaylists.append(newPlaylist)
                     }

                     self.isLoading = false
                 }
             } catch let error as MusicScriptError {
                 DispatchQueue.main.async {
                     self.errorMessage = error.errorDescription
                     self.isLoading = false
                 }
             } catch {
                 DispatchQueue.main.async {
                     self.errorMessage = "Failed to create playlist: \(error.localizedDescription)"
                     self.isLoading = false
                 }
             }
         }
     }

     func createFolder(named name: String) {
         isLoading = true
         errorMessage = nil

         Task { [weak self, name] in
             guard let self else { return }
             do {
                 try await musicService.createFolder(named: name)
                DispatchQueue.main.async {
                    // Optimistic local update - add folder to local state
                    let newFolder = Folder(name: name, playlists: [])
                    self.allFolders.append(newFolder)
                    self.isLoading = false
                }
            } catch let error as MusicScriptError {
                DispatchQueue.main.async {
                    self.errorMessage = error.errorDescription
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to create folder: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

     func renamePlaylist(_ playlist: Playlist, to newName: String, inFolder folderName: String) {
         isLoading = true
         errorMessage = nil

         Task { [weak self, playlist, newName, folderName] in
             guard let self else { return }
             do {
                 try await musicService.renamePlaylist(id: playlist.id, to: newName)
                DispatchQueue.main.async {
                    // Optimistic local update - rename playlist in local state
                    if folderName.isEmpty {
                        // Root playlist
                        if let index = self.rootPlaylists.firstIndex(where: { $0.id == playlist.id }) {
                            self.rootPlaylists[index].name = newName
                        }
                    } else {
                        // Folder playlist
                        if let folderIndex = self.allFolders.firstIndex(where: { $0.name == folderName }),
                           let playlistIndex = self.allFolders[folderIndex].playlists.firstIndex(where: { $0.id == playlist.id }) {
                            self.allFolders[folderIndex].playlists[playlistIndex].name = newName
                            if self.selectedFolder?.id == self.allFolders[folderIndex].id {
                                self.selectedFolder = self.allFolders[folderIndex]
                            }
                        }
                    }
                    self.isLoading = false
                }
            } catch let error as MusicScriptError {
                DispatchQueue.main.async {
                    self.errorMessage = error.errorDescription
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to rename playlist: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    func deletePlaylist(_ playlist: Playlist, from folderName: String) {
        isLoading = true
        errorMessage = nil

        Task { [weak self, playlist] in
            guard let self else { return }
            do {
                 try await musicService.deletePlaylist(id: playlist.id)
                DispatchQueue.main.async {
                    // Optimistically update local state instead of full refetch
                    self.removePlaylistLocally(playlist, from: folderName)
                    self.isLoading = false
                }
            } catch let error as MusicScriptError {
                DispatchQueue.main.async {
                    self.errorMessage = error.errorDescription
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to delete playlist: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

     func movePlaylist(_ playlist: Playlist, from sourceFolder: String, to destinationFolder: String) {
         isLoading = true
         errorMessage = nil

         Task { [weak self, playlist, sourceFolder, destinationFolder] in
             guard let self else { return }
             do {
                 try await musicService.movePlaylist(id: playlist.id, toFolder: destinationFolder)
                DispatchQueue.main.async {
                    // Optimistic local update - move playlist between folders

                    // Remove from source
                    if sourceFolder.isEmpty {
                        self.rootPlaylists.removeAll { $0.id == playlist.id }
                    } else if let sourceIndex = self.allFolders.firstIndex(where: { $0.name == sourceFolder }) {
                        self.allFolders[sourceIndex].playlists.removeAll { $0.id == playlist.id }
                        if self.selectedFolder?.id == self.allFolders[sourceIndex].id {
                            self.selectedFolder = self.allFolders[sourceIndex]
                        }
                    }

                    // Add to destination
                    if let destIndex = self.allFolders.firstIndex(where: { $0.name == destinationFolder }) {
                        self.allFolders[destIndex].playlists.append(playlist)
                        if self.selectedFolder?.id == self.allFolders[destIndex].id {
                            self.selectedFolder = self.allFolders[destIndex]
                        }
                    }

                    self.isLoading = false
                }
            } catch let error as MusicScriptError {
                DispatchQueue.main.async {
                    self.errorMessage = error.errorDescription
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to move playlist: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

     func deleteFolder(_ folder: Folder) {
         guard folder.name != "Library" else {
             errorMessage = "Cannot delete Library folder"
             return
         }

         isLoading = true
         errorMessage = nil

         Task { [weak self] in
             guard let self else { return }
             // Note: AppleScript doesn't have a direct "delete folder" command
             // This would need to be implemented if needed
             DispatchQueue.main.async {
                 self.errorMessage = "Folder deletion not yet implemented"
                 self.isLoading = false
             }
         }
     }

     // MARK: - Song Management

     func loadSongs(for playlist: Playlist) {
          isLoadingSongs = true
          errorMessage = nil
          selectedPlaylist = playlist

         Task { [weak self] in
             guard let self else { return }
             do {
                 print("Fetching songs from AppleScript...")
                 let songTuples = try await musicService.getSongs(playlistID: playlist.id)
                 print("Retrieved \(songTuples.count) songs")

                 // Map tuples to Song models
                 let loadedSongs = songTuples.map { tuple in
                     Song(
                         name: tuple.name,
                         artist: tuple.artist,
                         album: tuple.album,
                         duration: tuple.duration,
                         genre: tuple.genre.isEmpty ? nil : tuple.genre,
                         year: tuple.year == 0 ? nil : tuple.year,
                         trackNumber: tuple.trackNumber == 0 ? nil : tuple.trackNumber
                     )
                 }

                 DispatchQueue.main.async {
                     self.songs = loadedSongs
                     self.isLoadingSongs = false
                     print("Songs loaded successfully")
                 }

             } catch let error as MusicScriptError {
                 print("MusicScriptError loading songs: \(error)")
                 DispatchQueue.main.async {
                     self.errorMessage = error.errorDescription
                     self.isLoadingSongs = false
                     self.songs = []
                 }
             } catch {
                 print("Unexpected error loading songs: \(error)")
                 DispatchQueue.main.async {
                     self.errorMessage = "Failed to load songs: \(error.localizedDescription)"
                     self.isLoadingSongs = false
                     self.songs = []
                 }
             }
         }
     }

     func clearSongs() {
         selectedPlaylist = nil
         songs = []
     }

     // MARK: - Selection helpers

     func toggleSelection(for playlist: Playlist, modifiers: NSEvent.ModifierFlags) {
         // Single click without cmd → select only this
         if !modifiers.contains(.command) {
             selectedPlaylistIDs = [playlist.id]
             return
         }
         // Cmd+click toggles membership
         if selectedPlaylistIDs.contains(playlist.id) {
             selectedPlaylistIDs.remove(playlist.id)
         } else {
             selectedPlaylistIDs.insert(playlist.id)
         }
     }

     // MARK: - Local state updates

     private func removePlaylistLocally(_ playlist: Playlist, from folderName: String) {
         // Update selection
         selectedPlaylistIDs.remove(playlist.id)
         if selectedPlaylist?.id == playlist.id { clearSongs() }

         if folderName.isEmpty {
             // Root-level
             rootPlaylists.removeAll { $0.id == playlist.id }
         } else {
             if let index = allFolders.firstIndex(where: { $0.name == folderName }) {
                 allFolders[index].playlists.removeAll { $0.id == playlist.id }
                 if selectedFolder?.id == allFolders[index].id {
                     selectedFolder = allFolders[index]
                 }
             }
         }
     }

     // MARK: - One-Time Organization (Completed - kept for reference)

     /*
     func organizeMonthlyPlaylists() {
         print("🔄 Starting monthly playlist organization...")
         isLoading = true
         errorMessage = nil

         Task { [weak self] in
             guard let self else { return }
             do {
                 let (movedCount, skippedCount, failures) = try await performOrganization()

                 DispatchQueue.main.async {
                     self.isLoading = false

                     print("✅ Organization Complete!")
                     print("   Moved: \(movedCount) playlist\(movedCount == 1 ? "" : "s")")
                     print("   Skipped: \(skippedCount) playlist\(skippedCount == 1 ? "" : "s")")

                     if !failures.isEmpty {
                         print("   Failures:")
                         for (name, reason) in failures {
                             print("      • \(name): \(reason)")
                         }
                     }

                     // Refresh to show updated state
                     if movedCount > 0 {
                         self.loadFolders()
                     }
                 }
             } catch let error as MusicScriptError {
                 DispatchQueue.main.async {
                     self.isLoading = false
                     self.errorMessage = error.errorDescription
                     print("❌ Organization failed: \(error.errorDescription ?? "Unknown error")")
                 }
             } catch {
                 DispatchQueue.main.async {
                     self.isLoading = false
                     self.errorMessage = "Organization failed: \(error.localizedDescription)"
                     print("❌ Organization failed: \(error.localizedDescription)")
                 }
             }
         }
     }

     private func performOrganization() async throws -> (Int, Int, [(String, String)]) {
         // 1. Get all root playlists
         let playlists = rootPlaylists
         print("📋 Processing \(playlists.count) root playlists...")

         // 2. Build year folder lookup map
         let yearFolderMap = Dictionary(
             uniqueKeysWithValues: allFolders.map { ($0.name, $0) }
         )
         print("📁 Available year folders: \(yearFolderMap.keys.sorted())")

         // 3. Track results
         var movedCount = 0
         var skippedCount = 0
         var failures: [(String, String)] = []

         // 4. Process each playlist
         for playlist in playlists {
             // Parse playlist name
             guard let (monthName, yearStr) = parsePlaylistName(playlist.name) else {
                 // Not matching pattern - skip silently
                 continue
             }

             // Convert 2-digit year to 4-digit
             guard let fullYear = convertTwoDigitYear(yearStr) else {
                 skippedCount += 1
                 failures.append((playlist.name, "Invalid year format"))
                 print("⚠️  Skipped '\(playlist.name)': Invalid year format")
                 continue
             }

             // Validate year is in expected range (2014-2025)
             guard let yearInt = Int(fullYear), yearInt >= 2014 && yearInt <= 2025 else {
                 skippedCount += 1
                 failures.append((playlist.name, "Year \(fullYear) out of range (2014-2025)"))
                 print("⚠️  Skipped '\(playlist.name)': Year \(fullYear) out of range")
                 continue
             }

             // Check if year folder exists
             guard yearFolderMap[fullYear] != nil else {
                 skippedCount += 1
                 failures.append((playlist.name, "Year folder '\(fullYear)' not found"))
                 print("⚠️  Skipped '\(playlist.name)': Folder '\(fullYear)' not found")
                 continue
             }

             // Move playlist to year folder
             do {
                 print("🔀 Moving '\(playlist.name)' to '\(fullYear)'...")
                 try await musicService.movePlaylist(id: playlist.id, toFolder: fullYear)
                 movedCount += 1
                 print("✓  Moved '\(playlist.name)' to '\(fullYear)'")
             } catch {
                 skippedCount += 1
                 failures.append((playlist.name, "Move failed: \(error.localizedDescription)"))
                 print("✗  Failed to move '\(playlist.name)': \(error.localizedDescription)")
             }

             // Small delay to avoid overwhelming Music app
             try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
         }

         return (movedCount, skippedCount, failures)
     }

     private func parsePlaylistName(_ name: String) -> (String, String)? {
         // Regex pattern: "Month - YY"
         let pattern = #"^([A-Za-z]+)\s*-\s*(\d{2})$"#
         guard let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
               match.numberOfRanges == 3,
               let monthRange = Range(match.range(at: 1), in: name),
               let yearRange = Range(match.range(at: 2), in: name) else {
             return nil
         }
         return (String(name[monthRange]), String(name[yearRange]))
     }

     private func convertTwoDigitYear(_ twoDigitYear: String) -> String? {
         guard let year = Int(twoDigitYear), year >= 0 && year <= 99 else {
             return nil
         }
         // Simple conversion: add 2000 (for years 2014-2025, this covers 00-99)
         let fullYear = 2000 + year
         return String(fullYear)
     }
     */
 }

// MARK: - Sort Options

enum PlaylistSortOption: String, CaseIterable {
    case alphabetical = "A → Z"
    case reverseAlphabetical = "Z → A"
    case newestFirst = "Newest First"
    case oldestFirst = "Oldest First"
    case `default` = "Original Order"
}
