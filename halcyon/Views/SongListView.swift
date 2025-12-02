//
//  SongListView.swift
//  halcyon
//
//  Created by Parth Mangrola on 10/2/25.
//

import SwiftUI

struct SongListView: View {

    @ObservedObject var viewModel: MusicLibraryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            contentView
        }
         .navigationTitle(viewModel.selectedPlaylist?.name ?? "Songs")
         .navigationSubtitle(viewModel.selectedPlaylist != nil ? "\(viewModel.songs.count) song\(viewModel.songs.count == 1 ? "" : "s")" : "")
        
    }

    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoadingSongs {
            loadingView
         } else if viewModel.selectedPlaylist != nil {
            if viewModel.songs.isEmpty {
                emptyPlaylistView
            } else {
                songsTableView
                songCountView
            }
        } else {
            noPlaylistView
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading songs...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyPlaylistView: some View {
        VStack {
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No songs in this playlist")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var songsTableView: some View {
        Table(viewModel.songs) {
            TableColumn("#") { song in
                if let trackNum = song.trackNumber {
                    Text("\(trackNum)")
                        .foregroundStyle(.secondary)
                } else {
                    Text("—")
                        .foregroundStyle(.tertiary)
                }
            }
            .width(min: 30, ideal: 40, max: 50)

            TableColumn("Title") { song in
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.name)
                        .font(.body)
                    Text(song.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .width(min: 200, ideal: 300)

            TableColumn("Album") { song in
                Text(song.album)
            }
            .width(min: 150, ideal: 200)

            TableColumn("Genre") { song in
                Text(song.genre ?? "—")
                    .foregroundStyle(song.genre == nil ? .tertiary : .primary)
            }
            .width(min: 100, ideal: 120)

            TableColumn("Time") { song in
                Text(formatDuration(song.duration))
                    .foregroundStyle(.secondary)
            }
            .width(min: 50, ideal: 60, max: 70)
        }
        .alternatingRowBackgrounds()
    }

    private var songCountView: some View {
        Text("\(viewModel.songs.count) song\(viewModel.songs.count == 1 ? "" : "s")")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.opacity(0.5))
    }

    private var noPlaylistView: some View {
        VStack {
            Spacer()
            Image(systemName: "music.note")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Select a playlist to view songs")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// #Preview {
//     let viewModel = MusicLibraryViewModel(musicService: MusicScriptService())
//     viewModel.selectedPlaylist = Playlist(name: "My Favorites")
//     // Note: songs array is private(set) so we can't set it directly in preview
//     // In a real scenario, songs would be loaded via loadSongs() method
//
//     SongListView(viewModel: viewModel)
//         .frame(width: 800, height: 600)
// }
