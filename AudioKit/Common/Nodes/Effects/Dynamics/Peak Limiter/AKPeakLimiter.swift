//
//  AKPeakLimiter.swift
//  AudioKit
//
//  Created by Aurelius Prochazka, revision history on Github.
//  Copyright © 2018 AudioKit. All rights reserved.
//

/// AudioKit version of Apple's PeakLimiter Audio Unit
///
open class AKPeakLimiter: AKNode, AKToggleable, AUEffect, AKInput {

    /// Four letter unique description of the node
    public static let ComponentDescription = AudioComponentDescription(appleEffect: kAudioUnitSubType_PeakLimiter)

    private var au: AUWrapper
    private var mixer: AKMixer

    /// Attack Time (Secs) ranges from 0.001 to 0.03 (Default: 0.012)
    @objc open dynamic var attackTime: Double = 0.012 {
        didSet {
            attackTime = (0.001...0.03).clamp(attackTime)
            au[kLimiterParam_AttackTime] = attackTime
        }
    }

    /// Decay Time (Secs) ranges from 0.001 to 0.06 (Default: 0.024)
    @objc open dynamic var decayTime: Double = 0.024 {
        didSet {
            decayTime = (0.001...0.06).clamp(decayTime)
            au[kLimiterParam_DecayTime] = decayTime
        }
    }

    /// Pre Gain (dB) ranges from -40 to 40 (Default: 0)
    @objc open dynamic var preGain: Double = 0 {
        didSet {
            preGain = (-40...40).clamp(preGain)
            au[kLimiterParam_PreGain] = preGain
        }
    }

    /// Dry/Wet Mix (Default 1)
    @objc open dynamic var dryWetMix: Double = 1 {
        didSet {
            dryWetMix = (0...1).clamp(dryWetMix)
            inputGain?.volume = 1 - dryWetMix
            effectGain?.volume = dryWetMix
        }
    }

    private var lastKnownMix: Double = 1
    private var inputGain: AKMixer?
    private var effectGain: AKMixer?
    private var inputMixer = AKMixer()

    // Store the internal effect
    fileprivate var internalEffect: AVAudioUnitEffect

    /// Tells whether the node is processing (ie. started, playing, or active)
    @objc open dynamic var isStarted = true

    /// Initialize the peak limiter node
    ///
    /// - Parameters:
    ///   - input: Input node to process
    ///   - attackTime: Attack Time (Secs) ranges from 0.001 to 0.03 (Default: 0.012)
    ///   - decayTime: Decay Time (Secs) ranges from 0.001 to 0.06 (Default: 0.024)
    ///   - preGain: Pre Gain (dB) ranges from -40 to 40 (Default: 0)
    ///
    @objc public init(
        _ input: AKNode? = nil,
        attackTime: Double = 0.012,
        decayTime: Double = 0.024,
        preGain: Double = 0) {

        self.attackTime = attackTime
        self.decayTime = decayTime
        self.preGain = preGain

        inputGain = AKMixer()
        inputGain?.volume = 0
        mixer = AKMixer(inputGain)

        effectGain = AKMixer()
        effectGain?.volume = 1

        input?.connect(to: inputMixer)
        inputMixer.connect(to: [inputGain!, effectGain!])

        let effect = _Self.effect
        self.internalEffect = effect

        au = AUWrapper(effect)

        super.init(avAudioNode: mixer.avAudioNode)
        AudioKit.engine.attach(effect)

        if let node = effectGain?.avAudioNode {
            AudioKit.engine.connect(node, to: effect, format: AudioKit.format)
        }
        AudioKit.engine.connect(effect, to: mixer.avAudioNode, format: AudioKit.format)

        au[kLimiterParam_AttackTime] = attackTime
        au[kLimiterParam_DecayTime] = decayTime
        au[kLimiterParam_PreGain] = preGain
    }

    public var inputNode: AVAudioNode {
        return inputMixer.avAudioNode
    }
    // MARK: - Control

    /// Function to start, play, or activate the node, all do the same thing
    @objc open func start() {
        if isStopped {
            dryWetMix = lastKnownMix
            isStarted = true
        }
    }

    /// Function to stop or bypass the node, both are equivalent
    @objc open func stop() {
        if isPlaying {
            lastKnownMix = dryWetMix
            dryWetMix = 0
            isStarted = false
        }
    }

    /// Disconnect the node
    override open func disconnect() {
        stop()

        AudioKit.detach(nodes: [inputMixer.avAudioNode,
                                inputGain!.avAudioNode,
                                effectGain!.avAudioNode,
                                mixer.avAudioNode])
        AudioKit.engine.detach(self.internalEffect)
    }
}
