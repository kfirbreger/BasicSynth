//
//  AudioManager.swift
//  Connects the Oscillators to the AV foundation
//  audio engine
//
//  Created by Kfir Breger on 27/09/2026.
//

import AVFoundation

@Observable
final class AudioManager {
    private let signalGenerator = SignalGenerator()
    private var engine = AVAudioEngine()
    
    var waveform: Waveform = .sine {
        willSet {
            signalGenerator.setWaveform(inWaveform: newValue)
        }
    }
    
    var frequency: Float = 440 {
        willSet {
            signalGenerator.setFrequency(inFrequency: newValue)
        }
    }
    
    var amplitude: Float = -12 {
        willSet {
            signalGenerator.setAmplitude(inAmplitude: newValue)
        }
    }
    
    init() {
        let srcNode = signalGenerator.sourceNode
        let mainMixer = engine.mainMixerNode
        let output = engine.outputNode
        let outputFormat = output.inputFormat(forBus: 0) // Reading system sampling rate
        let inputFormat = AVAudioFormat(commonFormat: outputFormat.commonFormat, sampleRate: outputFormat.sampleRate, channels: 1, interleaved: outputFormat.isInterleaved)
        
        signalGenerator.setSampleRate(Float(outputFormat.sampleRate))
        engine.attach(srcNode)
        engine.connect(srcNode, to:mainMixer, format: inputFormat)
        engine.connect(mainMixer, to:output, format: outputFormat)
        mainMixer.outputVolume = 0.5
    }
    
    func start() {
        do {
            try engine.start()
        } catch {
            print("Could not start engine: \(error)")
        }
    }
    
    func stop() {
        engine.stop()
    }
}
