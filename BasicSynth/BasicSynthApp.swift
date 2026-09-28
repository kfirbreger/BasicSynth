//
//  BasicSynthApp.swift
//  BasicSynth
//
//  Created by Kfir Breger on 21/08/2026.
//

import SwiftUI

@main
struct BasicSynthApp: App {
    @State private var audioManager = AudioManager()

    var body: some Scene {
        WindowGroup {
            ContentView(audioManager: audioManager)
        }
    }
}
