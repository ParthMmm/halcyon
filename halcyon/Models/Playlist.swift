//
//  Playlist.swift
//  halcyon
//
//  Created by Parth Mangrola on 10/1/25.
//

import Foundation

struct Playlist: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var name: String
    var dateAdded: Date?  // Earliest track date (proxy for playlist creation)

    // Use Music's persistent ID as the identifier when available.
    // Falls back to name only if an ID is not supplied (tests/previews).
    init(id: String? = nil, name: String, dateAdded: Date? = nil) {
        self.name = name
        self.id = id ?? name
        self.dateAdded = dateAdded
    }
}
