//
//  PlaylistListView.swift
//  halcyon
//
//  Created by Parth Mangrola on 10/1/25.
//

import SwiftUI

struct PlaylistListView: View {

    @ObservedObject var viewModel: MusicLibraryViewModel
    let folder: Folder?

    @State private var selectedSortOption: PlaylistSortOption?
    @State private var showCreatePlaylistSheet = false
    @State private var newPlaylistName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Playlist list
            if let folder = folder {
                if folder.playlists.isEmpty {
                    VStack {
                        Spacer()
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        Text("No playlists in this folder")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List(selection: $viewModel.selectedPlaylistIDs) {
                        ForEach(folder.playlists) { playlist in
                            PlaylistRow(playlist: playlist, folder: folder, viewModel: viewModel)
                                .tag(playlist.id)
                        }
                    }
                    .listStyle(.inset)
                    .listRowSeparator(.hidden)
                    .onChange(of: viewModel.selectedPlaylistIDs) { oldValue, ids in
                        // Load songs when exactly one playlist is selected; otherwise clear
                        if ids.count == 1, let onlyID = ids.first,
                           let pl = folder.playlists.first(where: { $0.id == onlyID }) {
                            viewModel.loadSongs(for: pl)
                        } else {
                            viewModel.clearSongs()
                        }
                    }
                    .onChange(of: folder.id) { oldValue, newValue in
                        // Reset selection when switching folders
                        viewModel.selectedPlaylistIDs.removeAll()
                        viewModel.clearSongs()
                    }
                }
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "music.note.list")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("Select a folder to view playlists")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationSubtitle(folder != nil ? "\(folder!.playlists.count) playlist\(folder!.playlists.count == 1 ? "" : "s")" : "")
        .sheet(isPresented: $showCreatePlaylistSheet) {
            VStack(spacing: 20) {
                Text("Create New Playlist")
                    .font(.headline)

                TextField("Playlist Name", text: $newPlaylistName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                HStack {
                    Button("Cancel") {
                        showCreatePlaylistSheet = false
                        newPlaylistName = ""
                    }
                    .keyboardShortcut(.escape)

                    Spacer()

                    Button("Create") {
                        if !newPlaylistName.isEmpty {
                            // When creating in Library folder, create at root level (nil folder)
                            let targetFolder = folder?.name == "Library" ? nil : folder?.name
                            viewModel.createPlaylist(named: newPlaylistName, inFolder: targetFolder)
                            showCreatePlaylistSheet = false
                            newPlaylistName = ""
                        }
                    }
                    .keyboardShortcut(.return)
                    .disabled(newPlaylistName.isEmpty)
                }
                .padding(.horizontal)
            }
            .padding()
            .frame(width: 300, height: 150)
        }
        
         .safeAreaInset(edge: .trailing, spacing: 0) { Divider() }
    }
}

 struct PlaylistRow: View {
     let playlist: Playlist
     let folder: Folder
     let viewModel: MusicLibraryViewModel

     @State private var showRenameSheet = false
     @State private var newName = ""
     @State private var selectedDestinationFolder: Folder?

      var body: some View {
          ContextMenuBridge {
              HStack {
                  Image(systemName: "music.note.list")
                      .imageScale(.medium)

                  Text(playlist.name)
                      .font(.body)

                  Spacer()
              }
              .padding(.horizontal, 6)
              .padding(.vertical, 4)
              .contentShape(Rectangle())
              .background(rowSelectionBackground)
          } makeMenu: { coordinator in
              let menu = NSMenu(title: "Playlist Menu")

              // Rename
              let rename = NSMenuItem(title: "Rename", action: nil, keyEquivalent: "")
              rename.image = NSImage(systemSymbolName: "pencil", accessibilityDescription: nil)
              rename.target = nil
              rename.action = #selector(NSApplication.doNothing)
              // We'll flip state after the menu shows
              rename.representedObject = { newName = playlist.name; showRenameSheet = true }
              menu.addItem(rename)

              // Move to Folder (submenu with search + create)
              let move = NSMenuItem(title: "Move to Folder", action: nil, keyEquivalent: "")
              move.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
              let controller = MoveToFolderSubmenuController(
                  allFolders: viewModel.allFolders,
                  onSelectFolder: { dest in
                      viewModel.movePlaylist(playlist, from: folder.name, to: dest.name)
                  },
                  onCreateFolder: { name in
                      viewModel.createFolder(named: name)
                  }
              )
              coordinator.moveSubmenuController = controller
              move.submenu = controller.submenu
              menu.addItem(move)

              menu.addItem(NSMenuItem.separator())

              // Delete
              let del = NSMenuItem(title: "Delete", action: nil, keyEquivalent: "")
              del.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
              del.representedObject = { viewModel.deletePlaylist(playlist, from: folder.name) }
              menu.addItem(del)

              // Wire up a post-display runner to execute representedObject closures
              menu.items.forEach { item in
                  if item.action == nil { item.action = #selector(NSApplication.performRepresentedClosure(_:)); item.target = NSApp }
              }

              return menu
          } onPrimaryClick: { flags in
              viewModel.toggleSelection(for: playlist, modifiers: flags)
          }
        .sheet(isPresented: $showRenameSheet) {
            VStack(spacing: 20) {
                Text("Rename Playlist")
                    .font(.headline)

                TextField("New Name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                HStack {
                    Button("Cancel") {
                        showRenameSheet = false
                        newName = ""
                    }
                    .keyboardShortcut(.escape)

                    Spacer()

                    Button("Rename") {
                        if !newName.isEmpty && newName != playlist.name {
                            viewModel.renamePlaylist(playlist, to: newName, inFolder: folder.name)
                            showRenameSheet = false
                            newName = ""
                        }
                    }
                    .keyboardShortcut(.return)
                    .disabled(newName.isEmpty || newName == playlist.name)
                }
                .padding(.horizontal)
            }
            .padding()
            .frame(width: 300, height: 150)
        }
        // Nested menu handles moves; no modal sheet.
    }
}

private extension PlaylistRow {
    var isSelected: Bool { viewModel.selectedPlaylistIDs.contains(playlist.id) }
    var rowSelectionBackground: some View {
        Group {
            if isSelected {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.15))
            } else {
                Color.clear
            }
        }
    }
}

// NSApplication helpers live in ContextMenuBridge.swift

#Preview {
    let viewModel = MusicLibraryViewModel(musicService: MusicScriptService())
    let sampleFolder = Folder(
        name: "My Folder",
        playlists: [
            Playlist(name: "Chill Vibes"),
            Playlist(name: "Workout Mix"),
            Playlist(name: "Road Trip")
        ]
    )

    PlaylistListView(viewModel: viewModel, folder: sampleFolder)
        .frame(width: 400, height: 400)
}
