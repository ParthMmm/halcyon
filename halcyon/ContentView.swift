//
//  ContentView.swift
//  halcyon
//
//  Created by Parth Mangrola on 10/1/25.
//

import SwiftUI

@MainActor
struct ContentView: View {

    @StateObject private var viewModel: MusicLibraryViewModel
    // Inner split visibility controls the middle column (playlists)
    @State private var innerVisibility: NavigationSplitViewVisibility = .detailOnly

    init() {
        _viewModel = StateObject(wrappedValue: MusicLibraryViewModel(musicService: MusicScriptService()))
    }

     var body: some View {
         AnyView(
           outerSplitView
            .navigationTitle("Halcyon")
            .alert("Error", isPresented: errorAlertBinding) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onAppear {
                viewModel.loadFolders()
                innerVisibility = (viewModel.selectedFolder == nil) ? .detailOnly : .doubleColumn
            }
            .onChange(of: viewModel.selectedFolder) { newValue in
                withAnimation(.easeInOut(duration: 0.25)) {
                    innerVisibility = (newValue == nil) ? .detailOnly : .doubleColumn
                }
            }
         )
    }

    // MARK: - Outer split (left sidebar + right area)
    private var outerSplitView: some View {
        NavigationSplitView {
            sidebarColumn
        } detail: {
            // Inner split controls the middle column visibility
            innerSplitView
        }
    }

    // MARK: - Inner split (middle playlists + right detail)
    private var innerSplitView: some View {
        NavigationSplitView(columnVisibility: $innerVisibility) {
            contentColumn
        } detail: {
            detailColumn
        }
        // Main-content header bar spanning both middle + right columns
        .safeAreaInset(edge: .top, spacing: 0) {
            MainHeaderBar(viewModel: viewModel)
        }
    }

    // MARK: - Columns (split out to aid type-checker)

    private var sidebarColumn: some View {
        FolderListView(viewModel: viewModel)
    }

    @ViewBuilder
    private var contentColumn: some View {
        if let folder = viewModel.selectedFolder {
            PlaylistListView(viewModel: viewModel, folder: folder)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        if viewModel.selectedPlaylist != nil {
            SongListView(viewModel: viewModel)
        } else {
            ContentUnavailableView(
                "Select a Playlist",
                systemImage: "music.note.list",
                description: Text("Choose a playlist to view its songs")
            )
        }
    }

    // MARK: - Bindings

    private var errorAlertBinding: Binding<Bool> {
        Binding<Bool>(
            get: { viewModel.errorMessage != nil },
            set: { presenting in if !presenting { viewModel.errorMessage = nil } }
        )
    }
}

#Preview {
    ContentView()
}

// MARK: - Main Header Bar (spans main content area)

struct MainHeaderBar: View {
    @ObservedObject var viewModel: MusicLibraryViewModel

    @State private var selectedSort: PlaylistSortOption? = nil
    @State private var showCreatePlaylistSheet = false
    @State private var newPlaylistName = ""

    var body: some View {
        HStack(spacing: 12) {
            Text(currentTitle)
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            if let folder = viewModel.selectedFolder {
                Menu {
                    ForEach(PlaylistSortOption.allCases, id: \.self) { option in
                        Button(option.rawValue) {
                            viewModel.sortPlaylists(in: folder, by: option)
                            selectedSort = option
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                        .labelStyle(.iconOnly)
                }
                .help("Sort Playlists")

                Button {
                    viewModel.refreshPlaylists(for: folder)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
                .help("Refresh Folder")
                .disabled(viewModel.isLoading)

                Button {
                    showCreatePlaylistSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .help("New Playlist")
                .disabled(viewModel.isLoading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
        .sheet(isPresented: $showCreatePlaylistSheet) {
            createPlaylistSheet
        }
    }

    private var currentTitle: String {
        if let playlist = viewModel.selectedPlaylist {
            return playlist.name
        } else if let folder = viewModel.selectedFolder {
            return folder.name
        } else {
            return "Library"
        }
    }

    private var createPlaylistSheet: some View {
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
                        let targetFolderName = viewModel.selectedFolder?.name == "Library" ? nil : viewModel.selectedFolder?.name
                        viewModel.createPlaylist(named: newPlaylistName, inFolder: targetFolderName)
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
}
