//
//  Concurrency.swift
//  halcyon
//
//  Defines a dedicated global actor for AppleScript work so that
//  heavy Music automation does not block the main actor.
//

import Foundation

@globalActor
actor AppleScriptActor {
    static let shared = AppleScriptActor()
}

