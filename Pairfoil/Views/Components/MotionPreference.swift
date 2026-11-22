//
//  MotionPreference.swift
//  Pairfoil
//
//  Reduce motion: Pairfoil's own setting or the system's.
//

import SwiftUI

extension EnvironmentValues {
    /// Pairfoil's Reduce motion setting or the system's, whichever is on.
    /// Set by `pairfoilMotionPreference()` at each window's root.
    @Entry var reducesMotion = false
}

enum MotionPreference {
    /// Settings › General › "Reduce motion". Off by default: Pairfoil's few
    /// animations are short, and people who want them gone can say so here.
    static let key = "pairfoil_reduce_motion"
}

struct MotionPreferenceModifier: ViewModifier {
    @AppStorage(MotionPreference.key) private var pairfoilReduceMotion = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    /// The system's Reduce Motion counts as well as Pairfoil's own setting.
    private var reduceMotion: Bool { pairfoilReduceMotion || systemReduceMotion }

    func body(content: Content) -> some View {
        content.environment(\.reducesMotion, reduceMotion).transaction { transaction in
            if reduceMotion {
                transaction.disablesAnimations = true
                transaction.animation = nil
            }
        }
    }
}

extension View {
    /// Applies the user's Pairfoil motion preference to this view and everything inside it.
    func pairfoilMotionPreference() -> some View {
        modifier(MotionPreferenceModifier())
    }
}
