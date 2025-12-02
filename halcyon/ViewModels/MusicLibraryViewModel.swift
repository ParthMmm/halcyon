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

         var updatedPlaylists = folder.playlists

         switch sortOption {
         case .alphabetical:
             updatedPlaylists.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
         case .reverseAlphabetical:
             updatedPlaylists.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
         case .newestFirst:
             updatedPlaylists.sort { (p1, p2) in
                 // Playlists with dates come first, then sort by date descending
                 switch (p1.dateAdded, p2.dateAdded) {
                 case (.some(let d1), .some(let d2)): return d1 > d2
                 case (.some, .none): return true   // Dated playlists before undated
                 case (.none, .some): return false
                 case (.none, .none): return false  // Keep original order for both nil
                 }
             }
         case .oldestFirst:
             updatedPlaylists.sort { (p1, p2) in
                 // Playlists with dates come first, then sort by date ascending
                 switch (p1.dateAdded, p2.dateAdded) {
                 case (.some(let d1), .some(let d2)): return d1 < d2
                 case (.some, .none): return true   // Dated playlists before undated
                 case (.none, .some): return false
                 case (.none, .none): return false  // Keep original order for both nil
                 }
             }
         case .default:
             // Keep original order from Music app (no sorting)
             break
         }

         allFolders[folderIndex].playlists = updatedPlaylists

         // Update selected folder
         if selectedFolder?.id == folder.id {
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
                 try await musicService.createPlaylist(named: name, inFolder: folderName)
                 DispatchQueue.main.async {
                     self.isLoading = false
                     self.loadFolders() // Refresh to show new playlist
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
                    self.isLoading = false
                    self.loadFolders() // Refresh to show new folder
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

         Task { [weak self, playlist, newName] in
             guard let self else { return }
             do {
                 try await musicService.renamePlaylist(id: playlist.id, to: newName)
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.loadFolders() // Refresh to show renamed playlist
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

         Task { [weak self, playlist, destinationFolder] in
             guard let self else { return }
             do {
                 try await musicService.movePlaylist(id: playlist.id, toFolder: destinationFolder)
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.loadFolders() // Refresh to show moved playlist
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

         Task { [weak self, playlistName = playlist.name] in
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
 }

// MARK: - Sort Options

enum PlaylistSortOption: String, CaseIterable {
    case alphabetical = "A → Z"
    case reverseAlphabetical = "Z → A"
    case newestFirst = "Newest First"
    case oldestFirst = "Oldest First"
    case `default` = "Original Order"
}
