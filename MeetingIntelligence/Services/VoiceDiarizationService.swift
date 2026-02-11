//
//  VoiceDiarizationService.swift
//  MeetingIntelligence
//
//  Professional-grade Speaker Diarization using Voice Embeddings
//  Uses audio feature extraction for reliable speaker identification
//

import Foundation
import AVFoundation
import Accelerate
import Combine

// MARK: - Voice Profile (Speaker Embedding)
struct VoiceProfile: Identifiable, Equatable {
    let id: Int
    var label: String
    var color: String
    
    // Voice characteristics (embeddings)
    var pitchMean: Float = 0
    var pitchVariance: Float = 0
    var energyMean: Float = 0
    var energyVariance: Float = 0
    var zeroCrossingRate: Float = 0
    var spectralCentroid: Float = 0
    var mfccFeatures: [Float] = []
    
    // Statistics
    var sampleCount: Int = 0
    var totalDuration: TimeInterval = 0
    var lastActiveTime: TimeInterval = 0
    var confidence: Float = 0
    
    static let colors = [
        "6366F1", // Indigo - Speaker 1
        "10B981", // Emerald - Speaker 2
        "F59E0B", // Amber - Speaker 3
        "EF4444", // Red - Speaker 4
        "8B5CF6", // Violet - Speaker 5
        "EC4899", // Pink - Speaker 6
        "06B6D4", // Cyan - Speaker 7
        "84CC16"  // Lime - Speaker 8
    ]
    
    static func colorFor(speakerId: Int) -> String {
        colors[speakerId % colors.count]
    }
    
    // Calculate similarity to another profile
    func similarity(to other: VoiceFeatures) -> Float {
        guard sampleCount > 0 else { return 0 }
        
        var score: Float = 0
        var weights: Float = 0
        
        // Pitch similarity (weighted heavily)
        let pitchDiff = abs(pitchMean - other.pitch)
        let pitchScore = max(0, 1 - (pitchDiff / 100)) // 100Hz tolerance
        score += pitchScore * 3.0
        weights += 3.0
        
        // Energy similarity
        let energyDiff = abs(energyMean - other.energy)
        let energyScore = max(0, 1 - (energyDiff / 20)) // 20dB tolerance
        score += energyScore * 2.0
        weights += 2.0
        
        // Zero crossing rate similarity
        let zcrDiff = abs(zeroCrossingRate - other.zeroCrossingRate)
        let zcrScore = max(0, 1 - (zcrDiff / 0.2))
        score += zcrScore * 1.5
        weights += 1.5
        
        // Spectral centroid similarity
        let centroidDiff = abs(spectralCentroid - other.spectralCentroid)
        let centroidScore = max(0, 1 - (centroidDiff / 1000))
        score += centroidScore * 2.0
        weights += 2.0
        
        // MFCC similarity (if available)
        if !mfccFeatures.isEmpty && !other.mfccCoefficients.isEmpty {
            let minCount = min(mfccFeatures.count, other.mfccCoefficients.count)
            var mfccDiff: Float = 0
            for i in 0..<minCount {
                mfccDiff += abs(mfccFeatures[i] - other.mfccCoefficients[i])
            }
            let mfccScore = max(0, 1 - (mfccDiff / Float(minCount * 10)))
            score += mfccScore * 2.5
            weights += 2.5
        }
        
        return score / weights
    }
    
    // Update profile with new voice features
    mutating func update(with features: VoiceFeatures, duration: TimeInterval) {
        let alpha: Float = min(0.3, 1.0 / Float(sampleCount + 1))
        
        // Exponential moving average for smoother updates
        if sampleCount == 0 {
            pitchMean = features.pitch
            energyMean = features.energy
            zeroCrossingRate = features.zeroCrossingRate
            spectralCentroid = features.spectralCentroid
            mfccFeatures = features.mfccCoefficients
        } else {
            pitchMean = pitchMean * (1 - alpha) + features.pitch * alpha
            energyMean = energyMean * (1 - alpha) + features.energy * alpha
            zeroCrossingRate = zeroCrossingRate * (1 - alpha) + features.zeroCrossingRate * alpha
            spectralCentroid = spectralCentroid * (1 - alpha) + features.spectralCentroid * alpha
            
            // Update MFCC with weighted average
            if !features.mfccCoefficients.isEmpty {
                if mfccFeatures.isEmpty {
                    mfccFeatures = features.mfccCoefficients
                } else {
                    for i in 0..<min(mfccFeatures.count, features.mfccCoefficients.count) {
                        mfccFeatures[i] = mfccFeatures[i] * (1 - alpha) + features.mfccCoefficients[i] * alpha
                    }
                }
            }
        }
        
        // Update variance (for confidence calculation)
        let pitchDiff = features.pitch - pitchMean
        pitchVariance = pitchVariance * (1 - alpha) + (pitchDiff * pitchDiff) * alpha
        
        let energyDiff = features.energy - energyMean
        energyVariance = energyVariance * (1 - alpha) + (energyDiff * energyDiff) * alpha
        
        sampleCount += 1
        totalDuration += duration
        lastActiveTime = Date().timeIntervalSince1970
        
        // Confidence based on sample count and variance
        let varianceScore = 1.0 / (1.0 + sqrt(pitchVariance) / 50)
        let sampleScore = min(1.0, Float(sampleCount) / 50.0)
        confidence = (varianceScore + sampleScore) / 2.0
    }
    
    static func == (lhs: VoiceProfile, rhs: VoiceProfile) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Voice Features (extracted from audio)
struct VoiceFeatures {
    var pitch: Float = 0              // Fundamental frequency (F0)
    var energy: Float = 0             // RMS energy in dB
    var zeroCrossingRate: Float = 0   // Rate of sign changes
    var spectralCentroid: Float = 0   // "Brightness" of sound
    var spectralFlatness: Float = 0   // Tonality vs noise
    var mfccCoefficients: [Float] = [] // Mel-frequency cepstral coefficients
    var isVoiced: Bool = false        // Voice activity detected
    var timestamp: TimeInterval = 0
}

// MARK: - Voice Diarization Service
@MainActor
class VoiceDiarizationService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = VoiceDiarizationService()
    
    // MARK: - Published Properties
    @Published var speakers: [VoiceProfile] = []
    @Published var currentSpeakerId: Int = 0
    @Published var isProcessing: Bool = false
    @Published var speakerConfidence: Float = 0
    
    // MARK: - Configuration
    private let minSpeakerSimilarity: Float = 0.65    // Threshold for same speaker
    private let maxSpeakers: Int = 8                   // Maximum speakers to track
    private let silenceThreshold: Float = -45.0        // dB threshold for silence
    private let minSegmentDuration: TimeInterval = 0.3 // Minimum speech segment
    private let speakerChangeDebounce: TimeInterval = 0.5 // Prevent rapid changes
    
    // MARK: - Internal State
    private var lastSpeakerChangeTime: TimeInterval = 0
    private var currentSegmentStart: TimeInterval = 0
    private var featureBuffer: [VoiceFeatures] = []
    private let featureBufferSize = 10
    private var lastVoicedTime: TimeInterval = 0
    
    // FFT setup for spectral analysis
    private var fftSetup: vDSP_DFT_Setup?
    private let fftSize = 2048
    
    // MARK: - Initialization
    private init() {
        // Initialize FFT
        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(fftSize),
            vDSP_DFT_Direction.FORWARD
        )
        
        // Initialize with first speaker
        speakers = [
            VoiceProfile(
                id: 0,
                label: "Speaker 1",
                color: VoiceProfile.colorFor(speakerId: 0)
            )
        ]
    }
    
    // MARK: - Reset
    func reset() {
        speakers = [
            VoiceProfile(
                id: 0,
                label: "Speaker 1",
                color: VoiceProfile.colorFor(speakerId: 0)
            )
        ]
        currentSpeakerId = 0
        featureBuffer = []
        lastSpeakerChangeTime = 0
        currentSegmentStart = 0
        speakerConfidence = 0
    }
    
    // MARK: - Process Audio Buffer
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer, at timestamp: TimeInterval) -> Int {
        isProcessing = true
        defer { isProcessing = false }
        
        guard let channelData = buffer.floatChannelData?[0] else {
            return currentSpeakerId
        }
        
        let frameLength = Int(buffer.frameLength)
        let sampleRate = Float(buffer.format.sampleRate)
        
        // Extract voice features
        var features = extractFeatures(
            from: channelData,
            frameLength: frameLength,
            sampleRate: sampleRate,
            timestamp: timestamp
        )
        
        // Check for voice activity
        guard features.isVoiced else {
            // Check if we've been silent long enough to reset segment
            if timestamp - lastVoicedTime > 1.5 {
                currentSegmentStart = timestamp
            }
            return currentSpeakerId
        }
        
        lastVoicedTime = timestamp
        
        // Add to feature buffer for smoothing
        featureBuffer.append(features)
        if featureBuffer.count > featureBufferSize {
            featureBuffer.removeFirst()
        }
        
        // Average features over buffer for stability
        features = averageFeatures(featureBuffer)
        features.timestamp = timestamp
        
        // Identify speaker
        let (speakerId, confidence) = identifySpeaker(features: features, timestamp: timestamp)
        
        speakerConfidence = confidence
        
        // Update current speaker's profile
        if var profile = speakers.first(where: { $0.id == speakerId }) {
            let segmentDuration = timestamp - max(currentSegmentStart, profile.lastActiveTime)
            profile.update(with: features, duration: segmentDuration)
            
            if let index = speakers.firstIndex(where: { $0.id == speakerId }) {
                speakers[index] = profile
            }
        }
        
        return speakerId
    }
    
    // MARK: - Feature Extraction
    private func extractFeatures(
        from samples: UnsafePointer<Float>,
        frameLength: Int,
        sampleRate: Float,
        timestamp: TimeInterval
    ) -> VoiceFeatures {
        var features = VoiceFeatures()
        features.timestamp = timestamp
        
        // 1. Calculate RMS Energy
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(frameLength))
        features.energy = 20 * log10(max(rms, 1e-10))
        
        // Check for voice activity
        features.isVoiced = features.energy > silenceThreshold
        
        guard features.isVoiced else {
            return features
        }
        
        // 2. Calculate Zero Crossing Rate
        var crossings = 0
        for i in 1..<frameLength {
            if (samples[i] >= 0) != (samples[i-1] >= 0) {
                crossings += 1
            }
        }
        features.zeroCrossingRate = Float(crossings) / Float(frameLength)
        
        // 3. Estimate Pitch using Autocorrelation
        features.pitch = estimatePitch(
            samples: samples,
            frameLength: min(frameLength, fftSize),
            sampleRate: sampleRate
        )
        
        // 4. Calculate Spectral Features using FFT
        if let spectralFeatures = calculateSpectralFeatures(
            samples: samples,
            frameLength: min(frameLength, fftSize),
            sampleRate: sampleRate
        ) {
            features.spectralCentroid = spectralFeatures.centroid
            features.spectralFlatness = spectralFeatures.flatness
            features.mfccCoefficients = spectralFeatures.mfcc
        }
        
        return features
    }
    
    // MARK: - Pitch Estimation (Autocorrelation Method)
    private func estimatePitch(
        samples: UnsafePointer<Float>,
        frameLength: Int,
        sampleRate: Float
    ) -> Float {
        // Autocorrelation for pitch detection
        let minLag = Int(sampleRate / 500)  // Max freq 500Hz
        let maxLag = Int(sampleRate / 50)   // Min freq 50Hz
        
        guard maxLag < frameLength else { return 0 }
        
        var maxCorr: Float = 0
        var bestLag = minLag
        
        for lag in minLag..<min(maxLag, frameLength / 2) {
            var correlation: Float = 0
            var energy1: Float = 0
            var energy2: Float = 0
            
            for i in 0..<(frameLength - lag) {
                correlation += samples[i] * samples[i + lag]
                energy1 += samples[i] * samples[i]
                energy2 += samples[i + lag] * samples[i + lag]
            }
            
            // Normalized correlation
            let normalizer = sqrt(energy1 * energy2)
            if normalizer > 0 {
                correlation /= normalizer
            }
            
            if correlation > maxCorr {
                maxCorr = correlation
                bestLag = lag
            }
        }
        
        // Only return pitch if correlation is strong enough (voiced speech)
        if maxCorr > 0.3 {
            return sampleRate / Float(bestLag)
        }
        
        return 0
    }
    
    // MARK: - Spectral Features
    private func calculateSpectralFeatures(
        samples: UnsafePointer<Float>,
        frameLength: Int,
        sampleRate: Float
    ) -> (centroid: Float, flatness: Float, mfcc: [Float])? {
        guard frameLength >= fftSize else { return nil }
        
        // Apply Hamming window
        var windowedSamples = [Float](repeating: 0, count: fftSize)
        for i in 0..<fftSize {
            let window = 0.54 - 0.46 * cos(2 * Float.pi * Float(i) / Float(fftSize - 1))
            windowedSamples[i] = samples[i] * window
        }
        
        // Calculate magnitude spectrum
        var realPart = [Float](repeating: 0, count: fftSize)
        var imagPart = [Float](repeating: 0, count: fftSize)
        
        windowedSamples.withUnsafeBufferPointer { inputBuffer in
            realPart.withUnsafeMutableBufferPointer { realBuffer in
                imagPart.withUnsafeMutableBufferPointer { imagBuffer in
                    var splitComplex = DSPSplitComplex(
                        realp: realBuffer.baseAddress!,
                        imagp: imagBuffer.baseAddress!
                    )
                    
                    inputBuffer.baseAddress!.withMemoryRebound(
                        to: DSPComplex.self,
                        capacity: fftSize / 2
                    ) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
                    }
                    
                    if let setup = fftSetup {
                        vDSP_DFT_Execute(setup, realBuffer.baseAddress!, imagBuffer.baseAddress!, realBuffer.baseAddress!, imagBuffer.baseAddress!)
                    }
                }
            }
        }
        
        // Calculate magnitudes
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        for i in 0..<fftSize/2 {
            magnitudes[i] = sqrt(realPart[i] * realPart[i] + imagPart[i] * imagPart[i])
        }
        
        // Spectral Centroid
        var weightedSum: Float = 0
        var magnitudeSum: Float = 0
        let freqResolution = sampleRate / Float(fftSize)
        
        for i in 0..<magnitudes.count {
            let freq = Float(i) * freqResolution
            weightedSum += freq * magnitudes[i]
            magnitudeSum += magnitudes[i]
        }
        
        let centroid = magnitudeSum > 0 ? weightedSum / magnitudeSum : 0
        
        // Spectral Flatness (geometric mean / arithmetic mean)
        var logSum: Float = 0
        var sum: Float = 0
        var validCount = 0
        
        for mag in magnitudes where mag > 1e-10 {
            logSum += log(mag)
            sum += mag
            validCount += 1
        }
        
        var flatness: Float = 0
        if validCount > 0 && sum > 0 {
            let geometricMean = exp(logSum / Float(validCount))
            let arithmeticMean = sum / Float(validCount)
            flatness = geometricMean / arithmeticMean
        }
        
        // Simplified MFCC (first 13 coefficients)
        let mfcc = calculateMFCC(magnitudes: magnitudes, sampleRate: sampleRate)
        
        return (centroid, flatness, mfcc)
    }
    
    // MARK: - MFCC Calculation
    private func calculateMFCC(magnitudes: [Float], sampleRate: Float) -> [Float] {
        let numFilters = 26
        let numCoeffs = 13
        
        // Create mel filterbank
        let melFilters = createMelFilterbank(
            numFilters: numFilters,
            fftSize: magnitudes.count * 2,
            sampleRate: sampleRate
        )
        
        // Apply mel filters
        var melEnergies = [Float](repeating: 0, count: numFilters)
        for i in 0..<numFilters {
            for j in 0..<magnitudes.count {
                melEnergies[i] += magnitudes[j] * melFilters[i][j]
            }
            melEnergies[i] = log(max(melEnergies[i], 1e-10))
        }
        
        // DCT to get MFCCs
        var mfcc = [Float](repeating: 0, count: numCoeffs)
        for i in 0..<numCoeffs {
            for j in 0..<numFilters {
                mfcc[i] += melEnergies[j] * cos(Float.pi * Float(i) * (Float(j) + 0.5) / Float(numFilters))
            }
        }
        
        return mfcc
    }
    
    private func createMelFilterbank(numFilters: Int, fftSize: Int, sampleRate: Float) -> [[Float]] {
        let lowMel = hzToMel(0)
        let highMel = hzToMel(sampleRate / 2)
        
        // Mel points evenly spaced
        var melPoints = [Float](repeating: 0, count: numFilters + 2)
        for i in 0..<(numFilters + 2) {
            melPoints[i] = lowMel + Float(i) * (highMel - lowMel) / Float(numFilters + 1)
        }
        
        // Convert back to Hz
        var hzPoints = melPoints.map { melToHz($0) }
        
        // Convert to FFT bins
        var binPoints = hzPoints.map { Int($0 / sampleRate * Float(fftSize)) }
        
        // Create triangular filters
        var filterbank = [[Float]](repeating: [Float](repeating: 0, count: fftSize / 2), count: numFilters)
        
        for i in 0..<numFilters {
            for j in binPoints[i]..<binPoints[i + 1] {
                if j < fftSize / 2 && binPoints[i + 1] > binPoints[i] {
                    filterbank[i][j] = Float(j - binPoints[i]) / Float(binPoints[i + 1] - binPoints[i])
                }
            }
            for j in binPoints[i + 1]..<binPoints[i + 2] {
                if j < fftSize / 2 && binPoints[i + 2] > binPoints[i + 1] {
                    filterbank[i][j] = Float(binPoints[i + 2] - j) / Float(binPoints[i + 2] - binPoints[i + 1])
                }
            }
        }
        
        return filterbank
    }
    
    private func hzToMel(_ hz: Float) -> Float {
        return 2595 * log10(1 + hz / 700)
    }
    
    private func melToHz(_ mel: Float) -> Float {
        return 700 * (pow(10, mel / 2595) - 1)
    }
    
    // MARK: - Speaker Identification
    private func identifySpeaker(features: VoiceFeatures, timestamp: TimeInterval) -> (Int, Float) {
        // Calculate similarity to all known speakers
        var bestSpeakerId = currentSpeakerId
        var bestSimilarity: Float = 0
        
        for speaker in speakers {
            let similarity = speaker.similarity(to: features)
            if similarity > bestSimilarity {
                bestSimilarity = similarity
                bestSpeakerId = speaker.id
            }
        }
        
        // Debounce speaker changes
        let timeSinceLastChange = timestamp - lastSpeakerChangeTime
        
        // If best match is current speaker, keep it
        if bestSpeakerId == currentSpeakerId && bestSimilarity >= minSpeakerSimilarity * 0.8 {
            return (currentSpeakerId, bestSimilarity)
        }
        
        // If similarity is low and we can add more speakers, consider new speaker
        if bestSimilarity < minSpeakerSimilarity && speakers.count < maxSpeakers && timeSinceLastChange > speakerChangeDebounce {
            let newSpeakerId = speakers.count
            let newSpeaker = VoiceProfile(
                id: newSpeakerId,
                label: "Speaker \(newSpeakerId + 1)",
                color: VoiceProfile.colorFor(speakerId: newSpeakerId)
            )
            speakers.append(newSpeaker)
            
            currentSpeakerId = newSpeakerId
            lastSpeakerChangeTime = timestamp
            currentSegmentStart = timestamp
            
            print("🆕 New speaker detected: Speaker \(newSpeakerId + 1)")
            return (newSpeakerId, 0.5)
        }
        
        // Switch to best matching existing speaker
        if bestSpeakerId != currentSpeakerId && 
           bestSimilarity >= minSpeakerSimilarity &&
           timeSinceLastChange > speakerChangeDebounce {
            
            currentSpeakerId = bestSpeakerId
            lastSpeakerChangeTime = timestamp
            currentSegmentStart = timestamp
            
            print("🔄 Speaker change: Speaker \(bestSpeakerId + 1) (confidence: \(Int(bestSimilarity * 100))%)")
        }
        
        return (currentSpeakerId, bestSimilarity)
    }
    
    // MARK: - Average Features
    private func averageFeatures(_ buffer: [VoiceFeatures]) -> VoiceFeatures {
        guard !buffer.isEmpty else { return VoiceFeatures() }
        
        var averaged = VoiceFeatures()
        var validCount: Float = 0
        
        for features in buffer where features.isVoiced {
            averaged.pitch += features.pitch
            averaged.energy += features.energy
            averaged.zeroCrossingRate += features.zeroCrossingRate
            averaged.spectralCentroid += features.spectralCentroid
            averaged.spectralFlatness += features.spectralFlatness
            
            if averaged.mfccCoefficients.isEmpty {
                averaged.mfccCoefficients = features.mfccCoefficients
            } else if !features.mfccCoefficients.isEmpty {
                for i in 0..<min(averaged.mfccCoefficients.count, features.mfccCoefficients.count) {
                    averaged.mfccCoefficients[i] += features.mfccCoefficients[i]
                }
            }
            
            validCount += 1
        }
        
        if validCount > 0 {
            averaged.pitch /= validCount
            averaged.energy /= validCount
            averaged.zeroCrossingRate /= validCount
            averaged.spectralCentroid /= validCount
            averaged.spectralFlatness /= validCount
            
            for i in 0..<averaged.mfccCoefficients.count {
                averaged.mfccCoefficients[i] /= validCount
            }
            
            averaged.isVoiced = true
        }
        
        return averaged
    }
    
    // MARK: - Speaker Management
    func renameSpeaker(id: Int, name: String) {
        if let index = speakers.firstIndex(where: { $0.id == id }) {
            speakers[index].label = name
        }
    }
    
    func mergeSpeakers(from sourceId: Int, to targetId: Int) {
        guard let sourceIndex = speakers.firstIndex(where: { $0.id == sourceId }),
              let targetIndex = speakers.firstIndex(where: { $0.id == targetId }) else {
            return
        }
        
        // Merge profiles (weighted average based on sample count)
        let source = speakers[sourceIndex]
        var target = speakers[targetIndex]
        
        let totalSamples = Float(source.sampleCount + target.sampleCount)
        let sourceWeight = Float(source.sampleCount) / totalSamples
        let targetWeight = Float(target.sampleCount) / totalSamples
        
        target.pitchMean = source.pitchMean * sourceWeight + target.pitchMean * targetWeight
        target.energyMean = source.energyMean * sourceWeight + target.energyMean * targetWeight
        target.zeroCrossingRate = source.zeroCrossingRate * sourceWeight + target.zeroCrossingRate * targetWeight
        target.spectralCentroid = source.spectralCentroid * sourceWeight + target.spectralCentroid * targetWeight
        target.sampleCount = source.sampleCount + target.sampleCount
        target.totalDuration = source.totalDuration + target.totalDuration
        
        speakers[targetIndex] = target
        speakers.remove(at: sourceIndex)
        
        print("🔗 Merged Speaker \(source.label) into Speaker \(target.label)")
    }
    
    func getSpeaker(for id: Int) -> VoiceProfile? {
        return speakers.first { $0.id == id }
    }
}
