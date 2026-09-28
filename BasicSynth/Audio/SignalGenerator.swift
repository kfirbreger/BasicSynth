//
//  SignalGenerator.swift
//  BasicSynth
//
//  Created by Kfir Breger on 26/09/2026.
//
import Foundation
import AVFAudio

nonisolated final class SignalGenerator: @unchecked Sendable {
    
    private var sampleRate: Float
    private var amplitude: Float
    private var numHarmonics: Int
    private var frequency: Float
    private var phase: Float
    
    // Used Waveform
    private var waveform: Waveform
    
    private var phaseIncrement: ParameterRamp
    private var rawAmplitude: ParameterRamp
    private var noise: NoiseSource
  

    private var _sourceNode: AVAudioSourceNode?
    var sourceNode: AVAudioSourceNode {
        if let node = _sourceNode { return node }
        let node = AVAudioSourceNode { [unowned self] _, _, frameCount, audioBufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let sample = self.nextSample()
                for buffer in buffers {
                    buffer.mData!.assumingMemoryBound(to: Float.self)[frame] = sample
                }
            }
            return noErr
        }
        _sourceNode = node
        return node
    }
        
    init(inSampleRate: Float = 44100, inAmplitude: Float = -12, inNumHarmonics: Int = 1, inFrequency: Float = 440, inPhase: Float = 0) {
        sampleRate = inSampleRate
        amplitude = inAmplitude
        numHarmonics = inNumHarmonics
        frequency = inFrequency
        phase = inPhase
        waveform = .sine
        phaseIncrement = ParameterRamp(value: frequency * Waveform.twoPi / sampleRate)
        rawAmplitude = ParameterRamp(value: 0.25)
        noise = NoiseSource()
    }
    
    public func setSampleRate(_ inSampleRate: Float) {
        // Store the sample rate
        self.sampleRate = inSampleRate
        // Update max harmonics
        self.numHarmonics = Int(0.5 * sampleRate / self.frequency)
        // Setting increments to 100 miliseconds.
        self.phaseIncrement.setRampLength(0.1 * sampleRate)
        self.rawAmplitude.setRampLength(0.1 * sampleRate)
    }
   
    public func setWaveform(inWaveform: Waveform) {
        waveform = inWaveform
    }
    
    public func setFrequency(inFrequency: Float) {
        if (frequency != inFrequency) {
            // Store the frequency.
            frequency = inFrequency
            // Update the maximum number of harmonics by taking the floor of the Nyquist frequency divided by the base frequency.
            numHarmonics = Int(0.5 * sampleRate / frequency);
            // The phase increment needs to be ramped to avoid artifacts.
            phaseIncrement.setTargetValue(frequency * Waveform.twoPi / sampleRate);
        }
    }
    
    public func setAmplitude(inAmplitude: Float) {
        if (amplitude != inAmplitude) {
            // Store the amplitude.
            amplitude = inAmplitude
            // The inAmplitude parameter is converted from decibels to a raw amplitude value. The raw amplitude needs to be ramped to avoid artifacts.
            rawAmplitude.setTargetValue(powf(10, amplitude * 0.05));
        }
    }
    
    public func update(inWF: Waveform, inAmp: Float, inFreq: Float) {
        setWaveform(inWaveform: inWF)
        setAmplitude(inAmplitude: inAmp)
        setFrequency(inFrequency: inFreq)
    }
   
    public func nextSample() -> Float {
        let amp = rawAmplitude.nextValue()
        
        // Checking for noise to intercept sample call
        // @TODO at some point this needs to be cleaner
        if waveform == .noise {
            return amp * noise.next()
        }
        
        // Working with wave funcitons
        //-----------------------------
        // Getting the next sample
        let sample = waveform.sample(phase: phase, harmonics: numHarmonics)
        // Progressing the phase
        phase += phaseIncrement.nextValue()
        
        // We are moving in a circle
        if phase > Waveform.twoPi {
            phase -= Waveform.twoPi
        }
        
        return sample * amp
    }
}
