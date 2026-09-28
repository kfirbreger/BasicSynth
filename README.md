# BasicSynth

A minimal software synthesizer for iOS, written entirely in Swift. It generates the classic waveforms in real time through an `AVAudioSourceNode`, with live control over waveform, frequency, and amplitude from a SwiftUI interface.

The project my Swift 6 take on Apple's sample [Building a Signal Generator](https://developer.apple.com/documentation/avfaudio/building-a-signal-generator). It keeps that sample's DSP design (band-limited additive synthesis, parameter ramping) but replaces its C++/Objective-C core with pure Swift. See [Differences from Apple's sample](#differences-from-apples-sample) below.

## Setup

There are no external dependencies.

1. Open `BasicSynth/BasicSynth.xcodeproj` in Xcode.
2. Select the **BasicSynth** scheme and an iPhone or iPad run destination (simulator or device).
3. Build and run (⌘R), then press **Start** to start the audio engine.

Requirements: Xcode with the iOS 26.2 SDK (deployment target is iOS 26.2). The target builds in **Swift 6 language mode** with strict concurrency checking set to *complete* and default actor isolation set to `MainActor`.

## Synth parameters supported:

- **Waveform:** sine, sawtooth, square, triangle, noise
- **Frequency:** 20–6000 Hz
- **Amplitude**: −48–0 dB

## Architecture

The app is split into three layers, from UI down to the audio render thread:

```
ContentView (SwiftUI)
      │  bindings (@Bindable)
      ▼
AudioManager (@Observable, MainActor)
      │  owns AVAudioEngine, forwards parameter changes
      ▼
SignalGenerator (nonisolated DSP layer)
      │  render closure, called per buffer on the audio thread
      ▼
AVAudioSourceNode ──► mainMixerNode ──► outputNode
```

| File | Role |
|------|------|
| `BasicSynth/Audio/AudioManager.swift` | Builds the `AVAudioEngine` graph, exposes `waveform`/`frequency`/`amplitude` as observable properties, and forwards changes to the generator via `willSet`. |
| `BasicSynth/Audio/SignalGenerator.swift` | Produces samples. Owns the `AVAudioSourceNode`, the phase accumulator, and the parameter ramps. `nextSample()` is the per-sample hot path. |
| `BasicSynth/Audio/WaveFunction.swift` | `Waveform` enum: the five waveforms and their band-limited sample math. |
| `BasicSynth/Audio/ParameterRamp.swift` | Linear ramp that smooths parameter changes to avoid clicks and zipper noise. |
| `BasicSynth/Audio/Noise.swift` | `NoiseSource`, a xorshift32 white-noise generator. |
| `BasicSynth/ContentView.swift` | Waveform picker, frequency/amplitude sliders, start/stop buttons. |

### Key decisions

- **Pure Swift DSP under Swift 6 strict concurrency.** The target uses default `MainActor` isolation, so everything is main-actor-bound unless stated otherwise. The DSP types (`SignalGenerator`, `Waveform`, `ParameterRamp`, `NoiseSource`) are explicitly marked `nonisolated` because they run on the audio render thread, which is not an actor. `SignalGenerator` is `@unchecked Sendable`: the UI thread writes parameter targets (plain `Float` fields) while the render thread reads them. There is deliberately no lock — locks are forbidden on the render thread — so this is an accepted benign race, and the parameter ramps absorb any momentary inconsistency. This is the central trade-off of the project; Apple's sample solves the same problem by dropping to C++ instead (see below).
- **`Waveform` as an enum, not function pointers.** Each waveform is a case with its sample math in `sample(phase:harmonics:)`. Being `CaseIterable` + `RawRepresentable` means the same type directly drives the SwiftUI segmented picker — no separate UI model. Noise is a case of the enum for UI purposes but is intercepted in `SignalGenerator.nextSample()` before `sample` is called, since it comes from a stateful generator rather than a phase function (the `sample` implementation asserts if it's ever reached with `.noise`).
- **Band-limited additive synthesis.** Naive sawtooth/square/triangle waves alias badly because their discontinuities imply frequencies above Nyquist. Instead, each waveform is built from its Fourier series, summing harmonics only up to the Nyquist frequency: `numHarmonics = ⌊0.5 × sampleRate / frequency⌋`, recomputed whenever the frequency or sample rate changes.
- **Parameter ramping.** Jumping frequency or amplitude between buffers produces audible clicks. Both the phase increment (frequency) and the raw amplitude are wrapped in `ParameterRamp`, which interpolates linearly to the new target over 100 ms. Amplitude is exposed in decibels in the UI and converted to linear gain (`powf(10, dB * 0.05)`) before ramping.
- **Deterministic noise.** White noise comes from a xorshift32 PRNG — three shifts and three XORs per sample, no allocation, no system RNG calls, so it's cheap and safe on the render thread. It's seedable, which makes output reproducible in tests.
- **Sample-rate agnostic setup.** `AudioManager` reads the hardware output format at init and hands the actual sample rate to the generator, rather than assuming 44.1 kHz. The source node renders one mono channel; the same sample is written to every buffer in the buffer list.

## Differences from Apple's sample code

Apple's [Building a Signal Generator](https://developer.apple.com/documentation/avfaudio/building-a-signal-generator) is the direct source of this project, and much of the design carries over unchanged: the engine graph (source node → main mixer at 0.5 volume → output, mono at the hardware sample rate), the `@Observable AudioManager` forwarding parameter changes from `willSet`, the Fourier-series waveform math, the Nyquist-based harmonic count, the 100 ms parameter ramps, and the dB→linear amplitude conversion.

| | Apple's sample | BasicSynth |
|---|---|---|
| **DSP language** | C++ (`SignalGeneratorKernel`) wrapped in Objective-C (`SignalGenerator`), driven from Swift | 100% Swift |
| **Render entry point** | Objective-C object exposes an `AVAudioSourceNodeRenderBlock` property; Swift passes it to `AVAudioSourceNode(renderBlock:)` | `SignalGenerator` builds the node itself with a Swift closure that calls `nextSample()` per frame, created lazily and cached |
| **Real-time safety strategy** | Keep the render path out of Swift entirely — C++ guarantees no ARC, no Swift runtime, no allocation on the audio thread | Accept Swift on the render thread. The code avoids allocation and locks in the hot path, but ARC traffic and Swift runtime checks can still occur — a conscious trade-off for a single-oscillator learning project, not something to copy into a production instrument |
| **Concurrency model** | Thread safety lives implicitly in the C++/ObjC boundary | Explicit Swift 6 model: strict concurrency *complete*, default `MainActor` isolation, `nonisolated` DSP layer, `@unchecked Sendable` generator with ramped, tolerated data races on parameter fields |
| **Waveform representation** | Inline C free functions (`additiveSawtooth`, `additiveSquare`, …) selected by the kernel | A single `Waveform` enum owning the math, which doubles as the UI model (`CaseIterable` → segmented picker) |
| **Noise** | Generated inside the C++ kernel | A standalone, seedable xorshift32 `NoiseSource` struct, special-cased in `nextSample()` |

