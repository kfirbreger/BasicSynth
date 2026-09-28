//
//  Noise.swift
//  Noise source for white noise
//  BasicSynth
//
//  Created by Kfir Breger on 27/09/2026.
//

nonisolated struct NoiseSource {
    private var state: UInt32
    
    init(seed: UInt32 = 12345) {
        self.state = max(seed, 1)
    }
    
    mutating func next() -> Float {
        // xorshift32 — state must be non-zero
        state ^= state << 13
        state ^= state >> 17
        state ^= state << 5
        // Map the top 24 bits to [-1, 1)
        return Float(state >> 8) * (2.0 / 16_777_216.0) - 1.0
    }
}
