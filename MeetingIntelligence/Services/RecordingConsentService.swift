//
//  RecordingConsentService.swift
//  MeetingIntelligence
//
//  Recording Consent Service
//  Manages consent policy and audit logging for meeting recordings
//  GDPR/Legal compliant consent management
//

import Foundation
import AVFoundation
import UIKit
import Combine
import FirebaseAuth

// MARK: - Audio Player Delegate for Completion Callback
private class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    private let onComplete: () -> Void
    
    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        super.init()
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onComplete()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("⚠️ Audio decode error: \(error?.localizedDescription ?? "unknown")")
        onComplete()
    }
}

// MARK: - Models

struct ConsentPolicy: Codable {
    let id: String?
    let version: String
    let title: String
    let purposeOfRecording: String
    let dataRetentionPolicy: String
    let dataSecurityPolicy: String
    let dataSharingPolicy: String
    let userRights: String
    let effectiveDate: String?
}

struct ConsentRecord: Codable {
    let id: String
    let consentHash: String
    let consentTimestamp: String
    let policyVersion: String
    let message: String
}

struct ConsentRecordRequest: Codable {
    let meetingId: String
    let userId: String
    let userEmail: String
    let userFirstName: String
    let userLastName: String
    let userPhoneNumber: String?
    let policyId: String?
    let policyVersion: String
    let consentType: String
    let consentMethod: String
    let deviceId: String?
    let deviceModel: String
    let osVersion: String
    let appVersion: String
    let geoLocation: String?
    let allParticipantsNotified: Bool
    let audioAnnouncementPlayed: Bool
}

struct ConsentAPIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let error: String?
    let message: String?
}

// MARK: - TTS Request for OpenAI
private struct ConsentTTSRequest: Codable {
    let text: String
    let voice: String
    let speed: Double
}

// MARK: - Consent User Info (for passing user data)
struct ConsentUserInfo {
    let uid: String
    let email: String
    let firstName: String
    let lastName: String
    let phoneNumber: String?
}

// MARK: - Service

@MainActor
class RecordingConsentService: ObservableObject {
    static let shared = RecordingConsentService()
    
    @Published var currentPolicy: ConsentPolicy?
    @Published var isLoading = false
    @Published var error: String?
    @Published var currentConsentRecord: ConsentRecord?
    @Published var isPlayingAnnouncement = false
    @Published var announcementProgress: Double = 0
    
    private let baseURL = "https://dashmet-rca-api.onrender.com/api"
    private var audioPlayer: AVAudioPlayer?
    private var audioDelegate: AudioPlayerDelegate?  // Keep strong reference to delegate
    
    private init() {}
    
    // MARK: - Fetch Policy
    
    func fetchCurrentPolicy() async throws -> ConsentPolicy {
        isLoading = true
        defer { isLoading = false }
        
        guard let url = URL(string: "\(baseURL)/consent/policy") else {
            throw NSError(domain: "ConsentService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "ConsentService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch policy"])
        }
        
        let apiResponse = try JSONDecoder().decode(ConsentAPIResponse<ConsentPolicy>.self, from: data)
        
        guard let policy = apiResponse.data else {
            throw NSError(domain: "ConsentService", code: -3, userInfo: [NSLocalizedDescriptionKey: "No policy data"])
        }
        
        self.currentPolicy = policy
        return policy
    }
    
    // MARK: - Record Consent
    
    func recordConsent(
        meetingId: String,
        user: ConsentUserInfo,
        policy: ConsentPolicy,
        allParticipantsNotified: Bool = true
    ) async throws -> ConsentRecord {
        isLoading = true
        defer { isLoading = false }
        
        guard let url = URL(string: "\(baseURL)/consent/record") else {
            throw NSError(domain: "ConsentService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let deviceInfo = getDeviceInfo()
        
        let consentRequest = ConsentRecordRequest(
            meetingId: meetingId,
            userId: user.uid,
            userEmail: user.email,
            userFirstName: user.firstName,
            userLastName: user.lastName,
            userPhoneNumber: user.phoneNumber,
            policyId: policy.id,
            policyVersion: policy.version,
            consentType: "RECORDING_START",
            consentMethod: "IN_APP_MODAL",
            deviceId: deviceInfo.deviceId,
            deviceModel: deviceInfo.model,
            osVersion: deviceInfo.osVersion,
            appVersion: deviceInfo.appVersion,
            geoLocation: nil,
            allParticipantsNotified: allParticipantsNotified,
            audioAnnouncementPlayed: false
        )
        
        request.httpBody = try JSONEncoder().encode(consentRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "ConsentService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        if httpResponse.statusCode == 409 {
            // Consent already exists - that's okay
            print("ℹ️ Consent already recorded for this meeting")
        } else if httpResponse.statusCode != 201 {
            throw NSError(domain: "ConsentService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to record consent"])
        }
        
        let apiResponse = try JSONDecoder().decode(ConsentAPIResponse<ConsentRecord>.self, from: data)
        
        guard let record = apiResponse.data else {
            throw NSError(domain: "ConsentService", code: -3, userInfo: [NSLocalizedDescriptionKey: "No consent record returned"])
        }
        
        self.currentConsentRecord = record
        print("✅ Consent recorded: \(record.consentHash)")
        
        return record
    }
    
    // MARK: - Mark Announcement Played
    
    func markAnnouncementPlayed(consentId: String?, meetingId: String) async {
        guard let url = URL(string: "\(baseURL)/consent/announcement-played") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "consentId": consentId ?? "",
            "meetingId": meetingId
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let _ = try await URLSession.shared.data(for: request)
            print("✅ Announcement marked as played")
        } catch {
            print("⚠️ Failed to mark announcement: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Verify Consent
    
    func verifyConsent(meetingId: String, userId: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/consent/verify?meetingId=\(meetingId)&userId=\(userId)") else {
            return false
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            struct VerifyResponse: Codable {
                let success: Bool
                let data: VerifyData?
            }
            
            struct VerifyData: Codable {
                let hasValidConsent: Bool
                let audioAnnouncementPlayed: Bool?
            }
            
            let response = try JSONDecoder().decode(VerifyResponse.self, from: data)
            return response.data?.hasValidConsent ?? false
            
        } catch {
            print("⚠️ Failed to verify consent: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Audio Announcement (OpenAI TTS - Natural Voice)
    
    /// Generate and play a natural-sounding announcement using OpenAI TTS
    /// Returns when the announcement has finished playing
    func playRecordingAnnouncement() async throws {
        isPlayingAnnouncement = true
        announcementProgress = 0
        
        defer { 
            isPlayingAnnouncement = false
            announcementProgress = 1.0
        }
        
        // Configure audio session for playback
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try audioSession.setActive(true)
        } catch {
            print("⚠️ Failed to configure audio session: \(error)")
            throw error
        }
        
        let announcement = "Attention please. This meeting is now being recorded for transcription and summary purposes. By remaining in this meeting, you consent to this recording. Thank you."
        
        // Generate TTS audio using OpenAI API
        let audioData = try await generateAnnouncementAudio(text: announcement)
        
        // Play the audio and wait for completion
        try await playAudioAndWait(audioData)
        
        print("✅ Recording announcement completed")
    }
    
    /// Generate announcement audio using OpenAI TTS API
    private func generateAnnouncementAudio(text: String) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/transcripts/summary-audio") else {
            throw NSError(domain: "ConsentService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid TTS URL"])
        }
        
        // Get auth token
        guard let token = try? await FirebaseAuthService.shared.getIDToken() else {
            throw NSError(domain: "ConsentService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        // Use "nova" voice - natural female voice, professional and clear
        // Other options: alloy, echo, fable, onyx, shimmer
        let ttsRequest = ConsentTTSRequest(
            text: text,
            voice: "nova",  // Professional, natural-sounding female voice
            speed: 0.95     // Slightly slower for clarity
        )
        
        request.httpBody = try JSONEncoder().encode(ttsRequest)
        
        print("🎙️ Generating natural voice announcement with OpenAI TTS...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "ConsentService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        if httpResponse.statusCode != 200 {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ TTS Error: \(errorString)")
            }
            throw NSError(domain: "ConsentService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "TTS generation failed"])
        }
        
        // Verify it's audio data
        guard let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
              contentType.contains("audio") else {
            throw NSError(domain: "ConsentService", code: -4, userInfo: [NSLocalizedDescriptionKey: "Invalid audio data received"])
        }
        
        print("✅ TTS audio generated: \(data.count) bytes")
        return data
    }
    
    /// Play audio data and wait for it to complete
    private func playAudioAndWait(_ audioData: Data) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            do {
                audioPlayer = try AVAudioPlayer(data: audioData)
                
                // Create and retain the delegate
                audioDelegate = AudioPlayerDelegate { [weak self] in
                    Task { @MainActor in
                        self?.audioPlayer = nil
                        self?.audioDelegate = nil
                        continuation.resume()
                    }
                }
                audioPlayer?.delegate = audioDelegate
                audioPlayer?.prepareToPlay()
                
                let didPlay = audioPlayer?.play() ?? false
                print("🔊 Playing announcement... (started: \(didPlay))")
                
                if !didPlay {
                    audioDelegate = nil
                    continuation.resume(throwing: NSError(domain: "ConsentService", code: -5, userInfo: [NSLocalizedDescriptionKey: "Failed to play audio"]))
                }
                
            } catch {
                audioDelegate = nil
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Preview the announcement (for testing in consent modal)
    func previewAnnouncement() {
        Task {
            do {
                try await playRecordingAnnouncement()
            } catch {
                print("⚠️ Preview failed: \(error.localizedDescription)")
                // Fall back to system speech if OpenAI fails
                playFallbackAnnouncement()
            }
        }
    }
    
    /// Fallback announcement using system speech (if OpenAI TTS fails)
    private func playFallbackAnnouncement() {
        let synthesizer = AVSpeechSynthesizer()
        let announcement = "Attention. This meeting is now being recorded for transcription and summary purposes."
        
        let utterance = AVSpeechUtterance(string: announcement)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        synthesizer.speak(utterance)
    }
    
    func stopAnnouncement() {
        audioPlayer?.stop()
        audioPlayer = nil
        audioDelegate = nil
        isPlayingAnnouncement = false
    }
    
    // MARK: - Device Info
    
    private func getDeviceInfo() -> (deviceId: String, model: String, osVersion: String, appVersion: String) {
        let device = UIDevice.current
        let deviceId = device.identifierForVendor?.uuidString ?? "unknown"
        let model = device.model + " " + getDeviceModelName()
        let osVersion = "iOS \(device.systemVersion)"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        
        return (deviceId, model, osVersion, appVersion)
    }
    
    private func getDeviceModelName() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
    
    // MARK: - Local Consent Cache
    
    func cacheConsentLocally(meetingId: String, consentRecord: ConsentRecord) {
        let key = "consent_\(meetingId)"
        if let data = try? JSONEncoder().encode(consentRecord) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    func getCachedConsent(meetingId: String) -> ConsentRecord? {
        let key = "consent_\(meetingId)"
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ConsentRecord.self, from: data)
    }
    
    func clearCachedConsent(meetingId: String) {
        let key = "consent_\(meetingId)"
        UserDefaults.standard.removeObject(forKey: key)
    }
}
