//
//  Folder.swift
//  halcyon
//
//  Created by Parth Mangrola on 10/1/25.
//

import Foundation

struct Folder: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var name: String
    var playlists: [Playlist]

    init(id: String = UUID().uuidString, name: String, playlists: [Playlist] = []) {
        self.id = id
        self.name = name
        self.playlists = playlists
    }
}
