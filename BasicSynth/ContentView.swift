//
//  ContentView.swift
//  BasicSynth
//
//  Created by Kfir Breger on 21/08/2026.
//

import SwiftUI

struct ContentView: View {
    
    @Bindable var audioManager: AudioManager
    
    var body: some View {
        VStack {
            Text("Waveform")
            
            Picker("Waveform", selection: $audioManager.waveform) {
                ForEach(Waveform.allCases, id: \.rawValue) { waveform in
                    Text(waveform.rawValue)
                    .tag(waveform)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .labelsHidden()
            
            Text("Frequency: \(audioManager.frequency, specifier: "%.1f") Hz")
                .padding(.top)
                .opacity(audioManager.waveform == .noise ? 0 : 1)
            Slider(value: $audioManager.frequency, in: 20...6000, onEditingChanged: {_ in},
            minimumValueLabel: Text("20"),
                   maximumValueLabel: Text("6000")) {}
                .opacity(audioManager.waveform == .noise ? 0 : 1)
            
            Text("Amplitude: \(audioManager.amplitude, specifier: "%.1f") dB")
            Slider(value: $audioManager.amplitude, in: -48...0, onEditingChanged: {_ in}, minimumValueLabel: Text("-48"), maximumValueLabel: Text("0")) {}
                .padding(.bottom)
            HStack {
                Button("Start") {
                    audioManager.start()
                }
                Button("Stop") {
                    audioManager.stop()
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView(audioManager: AudioManager())
}
