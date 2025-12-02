//
//  Song.swift
//  halcyon
//
//  Created by Parth Mangrola on 10/2/25.
//

import Foundation

struct Song: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var name: String
    var artist: String
    var album: String
    var duration: TimeInterval  // in seconds
    var genre: String?
    var year: Int?
    var trackNumber: Int?

    init(
        id: String = UUID().uuidString,
        name: String,
        artist: String = "Unknown Artist",
        album: String = "Unknown Album",
        duration: TimeInterval = 0,
        genre: String? = nil,
        year: Int? = nil,
        trackNumber: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.artist = artist
        self.album = album
        self.duration = duration
        self.genre = genre
        self.year = year
        self.trackNumber = trackNumber
    }
}