//
//  PairState.swift
//  Pairfoil
//

import Foundation

enum PairState: String, Codable, Sendable {
    case notPaired
    case requested
    case requestedByPeer
    case paired

}
