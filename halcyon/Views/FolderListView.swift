//
//  FolderListView.swift
//  halcyon
//
//  Created by Parth Mangrola on 10/1/25.
//

import SwiftUI

// MARK: - Sidebar unified selection (folders and playlists)
enum SidebarItem: Hashable, Identifiable {
    case folder(Folder)
    case playlist(Playlist)

    var id: String {
        switch self {
        case .folder(let f): return "f-\(f.id)"
        case .playlist(let p): return "p-\(p.id)"
        }
    }
}

struct FolderListView: View {

    @ObservedObject var viewModel: MusicLibraryViewModel
    @State private var showCreateFolderSheet = false
    @State private var newFolderName = ""
    @State private var sidebarSelection: SidebarItem? = nil

    var body: some View {
         VStack(alignment: .leading, spacing: 0) {
             // Content list
            if viewModel.isLoading && viewModel.folders.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading folders...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if viewModel.folders.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("No folders found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    Text("Open Music app and try again")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
             } else {
                 List(selection: $sidebarSelection) {
                     // Root playlists section
                     if !viewModel.filteredRootPlaylists.isEmpty {
                         Section("Playlists") {
                              ForEach(viewModel.filteredRootPlaylists) { playlist in
                                  RootPlaylistRow(playlist: playlist, viewModel: viewModel)
                                      .tag(SidebarItem.playlist(playlist))
                              }
                         }
                     }

                     // Folders section
                     if !viewModel.filteredFolders.isEmpty {
                         Section("Folders") {
                             ForEach(viewModel.filteredFolders) { folder in
                                 FolderRow(folder: folder, viewModel: viewModel)
                                     .tag(SidebarItem.folder(folder))
                             }
                         }
                     }
                 }
                  .listStyle(.sidebar)
                  .listRowSeparator(.hidden)
                  .scrollContentBackground(.hidden)
                  .padding(.horizontal, -8)
                  .onChange(of: sidebarSelection) { newValue in
                      switch newValue {
                      case .folder(let folder):
                          viewModel.selectedFolder = folder
                          viewModel.selectedPlaylist = nil
                      case .playlist(let playlist):
                          viewModel.selectedFolder = nil
                          viewModel.selectedPlaylist = playlist
                          viewModel.loadSongs(for: playlist)
                      case .none:
                          break
                      }
                  }
                  .onAppear {
                      if let f = viewModel.selectedFolder {
                          sidebarSelection = .folder(f)
                      } else if let p = viewModel.selectedPlaylist {
                          sidebarSelection = .playlist(p)
                      }
                  }
             }
        }
        .frame(minWidth: 220, idealWidth: 250, maxWidth: 300)
        // Sidebar header bar pinned to top
        .safeAreaInset(edge: .top, spacing: 0) {
            SidebarHeaderBar(viewModel: viewModel, showCreateFolderSheet: $showCreateFolderSheet)
        }
        .sheet(isPresented: $showCreateFolderSheet) {
            VStack(spacing: 20) {
                Text("Create New Folder")
                    .font(.headline)

                TextField("Folder Name", text: $newFolderName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                HStack {
                    Button("Cancel") {
                        showCreateFolderSheet = false
                        newFolderName = ""
                    }
                    .keyboardShortcut(.escape)

                    Spacer()

                    Button("Create") {
                        if !newFolderName.isEmpty {
                            viewModel.createFolder(named: newFolderName)
                            showCreateFolderSheet = false
                            newFolderName = ""
                        }
                    }
                    .keyboardShortcut(.return)
                    .disabled(newFolderName.isEmpty)
                }
                .padding(.horizontal)
            }
            .padding()
            .frame(width: 300, height: 150)
        }
         .safeAreaInset(edge: .trailing, spacing: 0) { Divider() }
    }
}

 struct RootPlaylistRow: View {
     let playlist: Playlist
     let viewModel: MusicLibraryViewModel

     @State private var showRenameSheet = false
     @State private var newName = ""

      var body: some View {
          ContextMenuBridge {
              HStack {
                  Image(systemName: "music.note.list")
                      .imageScale(.medium)

                  VStack(alignment: .leading, spacing: 2) {
                      Text(playlist.name)
                          .font(.body)
                  }
              }
              .padding(.vertical, 4)
          } makeMenu: { coordinator in
              let menu = NSMenu(title: "Playlist Menu")

              let rename = NSMenuItem(title: "Rename", action: nil, keyEquivalent: "")
              rename.image = NSImage(systemSymbolName: "pencil", accessibilityDescription: nil)
              rename.representedObject = { newName = playlist.name; showRenameSheet = true }
              menu.addItem(rename)

              let move = NSMenuItem(title: "Move to Folder", action: nil, keyEquivalent: "")
              move.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
              let controller = MoveToFolderSubmenuController(
                  allFolders: viewModel.allFolders,
                  onSelectFolder: { dest in
                      viewModel.movePlaylist(playlist, from: "", to: dest.name)
                  },
                  onCreateFolder: { name in
                      viewModel.createFolder(named: name)
                  }
              )
              coordinator.moveSubmenuController = controller
              move.submenu = controller.submenu
              menu.addItem(move)

              let del = NSMenuItem(title: "Delete", action: nil, keyEquivalent: "")
              del.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
              del.representedObject = { viewModel.deletePlaylist(playlist, from: "") }
              menu.addItem(del)

              menu.items.forEach { item in
                  if item.action == nil { item.action = #selector(NSApplication.performRepresentedClosure(_:)); item.target = NSApp }
              }

              return menu
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
                            viewModel.renamePlaylist(playlist, to: newName, inFolder: "")
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

struct FolderRow: View {
    let folder: Folder
    let viewModel: MusicLibraryViewModel

    @State private var showRenameSheet = false
    @State private var newName = ""

    var body: some View {
        HStack {
             Image(systemName: folder.name == "Library" ? "music.note.house.fill" : "folder.fill")
                 .imageScale(.medium)
                 .foregroundStyle(Color.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(folder.name)
                    .font(.body)

                Text("\(folder.playlists.count) playlist\(folder.playlists.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            if folder.name != "Library" {
                Button {
                    newName = folder.name
                    showRenameSheet = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    viewModel.deleteFolder(folder)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showRenameSheet) {
            VStack(spacing: 20) {
                Text("Rename Folder")
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
                        if !newName.isEmpty && newName != folder.name {
                            // TODO: Implement folder renaming
                            showRenameSheet = false
                            newName = ""
                        }
                    }
                    .keyboardShortcut(.return)
                    .disabled(newName.isEmpty || newName == folder.name)
                }
                .padding(.horizontal)
            }
            .padding()
            .frame(width: 300, height: 150)
        }
    }
}

#Preview {
    let viewModel = MusicLibraryViewModel(musicService: MusicScriptService())
    FolderListView(viewModel: viewModel)
        .frame(width: 250, height: 400)
}

// MARK: - Sidebar header bar (local toolbar)

struct SidebarHeaderBar: View {
    @ObservedObject var viewModel: MusicLibraryViewModel
    @Binding var showCreateFolderSheet: Bool

    var body: some View {
        VStack(spacing: 6) {
            TextField("Search playlists and folders...", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.top, 6)

            HStack(spacing: 6) {
                filterButton(systemName: "square.grid.2x2", isActive: viewModel.folderFilter == .all) {
                    viewModel.folderFilter = .all
                }
                filterButton(systemName: "folder.fill", isActive: viewModel.folderFilter == .foldersOnly) {
                    viewModel.folderFilter = .foldersOnly
                }
                filterButton(systemName: "music.note.list", isActive: viewModel.folderFilter == .playlistsOnly) {
                    viewModel.folderFilter = .playlistsOnly
                }

                Spacer(minLength: 8)

                Button {
                    viewModel.loadFolders()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
                .help("Refresh Library")
                .disabled(viewModel.isLoading)

                Button {
                    showCreateFolderSheet = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .help("New Folder")
                .disabled(viewModel.isLoading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func filterButton(systemName: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14))
                .frame(width: 32, height: 28)
                .background(isActive ? Color.accentColor.opacity(0.18) : Color.clear)
                .foregroundStyle(isActive ? .blue : .secondary)
                .cornerRadius(6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
