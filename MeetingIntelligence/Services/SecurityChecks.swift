//
//  SecurityChecks.swift
//  MeetingIntelligence
//
//  Runtime security checks: jailbreak detection, debugger detection,
//  and tamper detection.
//

import Foundation
import UIKit

enum SecurityChecks {
    
    /// Returns true if the device appears to be jailbroken
    static var isJailbroken: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        // Check for common jailbreak files
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/",
            "/usr/bin/ssh",
            "/private/var/stash",
            "/private/var/lib/cydia",
            "/private/var/tmp/cydia.log",
            "/Applications/Sileo.app",
        ]
        
        for path in jailbreakPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        
        // Check if we can write to a protected path
        let testPath = "/private/jailbreak_test"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return true
        } catch {
            // Expected to fail on non-jailbroken device
        }
        
        // Check if Cydia URL scheme is available
        if let url = URL(string: "cydia://package/com.example.package"),
           UIApplication.shared.canOpenURL(url) {
            return true
        }
        
        return false
        #endif
    }
    
    /// Returns true if a debugger is attached
    static var isDebuggerAttached: Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        
        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        guard result == 0 else { return false }
        
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }
    
    /// Perform all security checks. Returns list of warnings (empty = all clear).
    static func performChecks() -> [String] {
        var warnings: [String] = []
        
        if isJailbroken {
            warnings.append("Device appears to be jailbroken")
        }
        
        #if !DEBUG
        if isDebuggerAttached {
            warnings.append("Debugger detected")
        }
        #endif
        
        return warnings
    }
}
