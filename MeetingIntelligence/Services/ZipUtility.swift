//
//  ZipUtility.swift
//  MeetingIntelligence
//
//  Native ZIP file creation utility for DOCX generation
//  No external dependencies required
//

import Foundation

final class ZipUtility {
    
    /// Creates a ZIP file from the contents of a directory
    /// - Parameters:
    ///   - sourceDirectory: Directory containing files to zip
    ///   - destinationPath: Path where the ZIP file will be created
    /// - Returns: Bool indicating success
    static func createZipFile(from sourceDirectory: URL, to destinationPath: URL) throws -> Bool {
        let fileManager = FileManager.default
        
        // Get all files in directory recursively
        // Do NOT skip hidden files - .rels files are required for DOCX
        guard let enumerator = fileManager.enumerator(
            at: sourceDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: []
        ) else {
            throw ZipError.cannotEnumerateDirectory
        }
        
        var files: [(URL, String)] = []
        while let fileURL = enumerator.nextObject() as? URL {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            if resourceValues.isRegularFile == true {
                let fileName = fileURL.lastPathComponent
                // Skip macOS metadata and any docx files (output destination)
                if fileName == ".DS_Store" || fileName.hasSuffix(".docx") {
                    continue
                }
                let relativePath = fileURL.path.replacingOccurrences(of: sourceDirectory.path + "/", with: "")
                files.append((fileURL, relativePath))
            }
        }
        
        // Create ZIP data
        let zipData = try createZipData(files: files)
        
        // Write to destination
        try zipData.write(to: destinationPath)
        
        return true
    }
    
    /// Creates ZIP data from an array of files
    private static func createZipData(files: [(URL, String)]) throws -> Data {
        var zipData = Data()
        var centralDirectory = Data()
        var localFileHeaders: [LocalFileHeader] = []
        
        let currentDate = Date()
        let dosTime = getDOSTime(from: currentDate)
        let dosDate = getDOSDate(from: currentDate)
        
        // Write local file headers and file data
        for (fileURL, relativePath) in files {
            let fileData = try Data(contentsOf: fileURL)
            let crc = crc32(data: fileData)
            
            let localHeader = LocalFileHeader(
                signature: 0x04034b50,
                versionNeeded: 20,
                generalPurpose: 0,
                compressionMethod: 0, // Store (no compression)
                lastModTime: dosTime,
                lastModDate: dosDate,
                crc32: crc,
                compressedSize: UInt32(fileData.count),
                uncompressedSize: UInt32(fileData.count),
                fileNameLength: UInt16(relativePath.utf8.count),
                extraFieldLength: 0,
                fileName: relativePath,
                localHeaderOffset: UInt32(zipData.count)
            )
            
            localFileHeaders.append(localHeader)
            
            // Append local file header
            zipData.append(localHeader.toData())
            
            // Append file data
            zipData.append(fileData)
        }
        
        // Build central directory
        let centralDirectoryOffset = UInt32(zipData.count)
        
        for header in localFileHeaders {
            let centralEntry = CentralDirectoryEntry(
                signature: 0x02014b50,
                versionMadeBy: 20,
                versionNeeded: 20,
                generalPurpose: 0,
                compressionMethod: 0,
                lastModTime: header.lastModTime,
                lastModDate: header.lastModDate,
                crc32: header.crc32,
                compressedSize: header.compressedSize,
                uncompressedSize: header.uncompressedSize,
                fileNameLength: header.fileNameLength,
                extraFieldLength: 0,
                commentLength: 0,
                diskStart: 0,
                internalAttributes: 0,
                externalAttributes: 0,
                localHeaderOffset: header.localHeaderOffset,
                fileName: header.fileName
            )
            centralDirectory.append(centralEntry.toData())
        }
        
        let centralDirectorySize = UInt32(centralDirectory.count)
        
        // Append central directory
        zipData.append(centralDirectory)
        
        // Append end of central directory record
        let endRecord = EndOfCentralDirectory(
            signature: 0x06054b50,
            diskNumber: 0,
            centralDirectoryDisk: 0,
            entriesOnDisk: UInt16(localFileHeaders.count),
            totalEntries: UInt16(localFileHeaders.count),
            centralDirectorySize: centralDirectorySize,
            centralDirectoryOffset: centralDirectoryOffset,
            commentLength: 0
        )
        zipData.append(endRecord.toData())
        
        return zipData
    }
    
    // MARK: - DOS Time Conversion
    
    private static func getDOSTime(from date: Date) -> UInt16 {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hour = UInt16(components.hour ?? 0)
        let minute = UInt16(components.minute ?? 0)
        let second = UInt16((components.second ?? 0) / 2)
        return (hour << 11) | (minute << 5) | second
    }
    
    private static func getDOSDate(from date: Date) -> UInt16 {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = UInt16((components.year ?? 1980) - 1980)
        let month = UInt16(components.month ?? 1)
        let day = UInt16(components.day ?? 1)
        return (year << 9) | (month << 5) | day
    }
    
    // MARK: - CRC32 Calculation
    
    private static let crcTable: [UInt32] = {
        var table = [UInt32](repeating: 0, count: 256)
        for i in 0..<256 {
            var crc = UInt32(i)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = (crc >> 1) ^ 0xEDB88320
                } else {
                    crc >>= 1
                }
            }
            table[i] = crc
        }
        return table
    }()
    
    private static func crc32(data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ crcTable[index]
        }
        return crc ^ 0xFFFFFFFF
    }
}

// MARK: - Error Types

enum ZipError: Error {
    case cannotEnumerateDirectory
    case cannotReadFile
    case cannotWriteZip
}

// MARK: - ZIP Structures

private struct LocalFileHeader {
    let signature: UInt32
    let versionNeeded: UInt16
    let generalPurpose: UInt16
    let compressionMethod: UInt16
    let lastModTime: UInt16
    let lastModDate: UInt16
    let crc32: UInt32
    let compressedSize: UInt32
    let uncompressedSize: UInt32
    let fileNameLength: UInt16
    let extraFieldLength: UInt16
    let fileName: String
    let localHeaderOffset: UInt32
    
    func toData() -> Data {
        var data = Data()
        data.append(littleEndian: signature)
        data.append(littleEndian: versionNeeded)
        data.append(littleEndian: generalPurpose)
        data.append(littleEndian: compressionMethod)
        data.append(littleEndian: lastModTime)
        data.append(littleEndian: lastModDate)
        data.append(littleEndian: crc32)
        data.append(littleEndian: compressedSize)
        data.append(littleEndian: uncompressedSize)
        data.append(littleEndian: fileNameLength)
        data.append(littleEndian: extraFieldLength)
        data.append(fileName.data(using: .utf8) ?? Data())
        return data
    }
}

private struct CentralDirectoryEntry {
    let signature: UInt32
    let versionMadeBy: UInt16
    let versionNeeded: UInt16
    let generalPurpose: UInt16
    let compressionMethod: UInt16
    let lastModTime: UInt16
    let lastModDate: UInt16
    let crc32: UInt32
    let compressedSize: UInt32
    let uncompressedSize: UInt32
    let fileNameLength: UInt16
    let extraFieldLength: UInt16
    let commentLength: UInt16
    let diskStart: UInt16
    let internalAttributes: UInt16
    let externalAttributes: UInt32
    let localHeaderOffset: UInt32
    let fileName: String
    
    func toData() -> Data {
        var data = Data()
        data.append(littleEndian: signature)
        data.append(littleEndian: versionMadeBy)
        data.append(littleEndian: versionNeeded)
        data.append(littleEndian: generalPurpose)
        data.append(littleEndian: compressionMethod)
        data.append(littleEndian: lastModTime)
        data.append(littleEndian: lastModDate)
        data.append(littleEndian: crc32)
        data.append(littleEndian: compressedSize)
        data.append(littleEndian: uncompressedSize)
        data.append(littleEndian: fileNameLength)
        data.append(littleEndian: extraFieldLength)
        data.append(littleEndian: commentLength)
        data.append(littleEndian: diskStart)
        data.append(littleEndian: internalAttributes)
        data.append(littleEndian: externalAttributes)
        data.append(littleEndian: localHeaderOffset)
        data.append(fileName.data(using: .utf8) ?? Data())
        return data
    }
}

private struct EndOfCentralDirectory {
    let signature: UInt32
    let diskNumber: UInt16
    let centralDirectoryDisk: UInt16
    let entriesOnDisk: UInt16
    let totalEntries: UInt16
    let centralDirectorySize: UInt32
    let centralDirectoryOffset: UInt32
    let commentLength: UInt16
    
    func toData() -> Data {
        var data = Data()
        data.append(littleEndian: signature)
        data.append(littleEndian: diskNumber)
        data.append(littleEndian: centralDirectoryDisk)
        data.append(littleEndian: entriesOnDisk)
        data.append(littleEndian: totalEntries)
        data.append(littleEndian: centralDirectorySize)
        data.append(littleEndian: centralDirectoryOffset)
        data.append(littleEndian: commentLength)
        return data
    }
}

// MARK: - Data Extension for Little Endian

private extension Data {
    mutating func append<T: FixedWidthInteger>(littleEndian value: T) {
        var littleEndianValue = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndianValue) { buffer in
            self.append(contentsOf: buffer)
        }
    }
}
