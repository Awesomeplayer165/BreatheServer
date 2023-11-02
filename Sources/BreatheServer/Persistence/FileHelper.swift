//
//  FileHelper.swift
//  BreatheServer
//
//  Created by Jacob Trentini on 7/11/23.
//

import Foundation

/// Abstraction for FileManager with the focus of improving and generically but easily writing/reading/deleting pre-define files.
class FileHelper {
    
    /// Shared instance of FileHelper
    public static let shared = FileHelper()
    
    /// Runs startup tasks
    private init() {
        createEmptyFilesIfNotExists()
    }
    
    /// One of the starting tasks charged with creating empty files from `WriteLocation` if they do not already exist.
    /// Note: If they already exist, then it will not be created or overwritten.
    private func createEmptyFilesIfNotExists() {
        for location in WriteLocation.allCases {
            if !FileManager.default.fileExists(atPath: location.url.path) {
                FileManager.default.createFile(atPath: location.url.path, contents: nil)
            }
        }
    }
    
    /// Specifies the different locations that `FileHelper` wrapper will know about.
    /// It is important to include every path as a case you plan to use through here
    enum WriteLocation: String, CaseIterable {
        case boundariesByPlace           = "boundariesByPlace.json"
        case sensorsByPlace              = "sensorsByPlace.json"
        case reverseGeoCodedDataByPlace  = "reverseGeoCodedDataByPlace.json"
        
        /// Creates a URL combining the documents directory and the associated value's last component path
        var url: URL {
            FileManager.getDocumentsDirectory().appendingPathComponent(self.rawValue)
        }
    }
    
    /// Appends json to the specificed `WriteLocation`
    /// - Parameters:
    ///   - location: Specified `WriteLocation` for the wrapper to write to
    ///   - type: Codable-conforming type of what is being read and written to
    ///   - appendingOperation: Closure to customize how to merge (or append) existing content and new content. Note that if decoding fails, then parameter `existingDecodedContent` will be nil, thus opening a chance to replace the inout parameter with new data.
    public func appendJson<T: Codable>(to location: WriteLocation,
                                       type: T,
                                       appendingOperation: (_ existingDecodedContent: inout T?) -> Void
    ) throws {
        var json = try? readJson(from: location, type: type)
        
        appendingOperation(&json)
        
        let newData = try JSONEncoder().encode(json)
        try newData.write(to: location.url)
    }
    
    /// Reads json from the specified `WriteLocation`
    /// - Parameters:
    ///   - location: Specified `WriteLocation` for the wrapper to write to
    ///   - type: Codable-conforming type of what is being read from
    /// - Returns: The Codable-conforming type generically specified above
    public func readJson<T: Decodable>(from location: WriteLocation,
                                       type: T
    ) throws -> T {
        let data = try Data(contentsOf: location.url)
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    /// Deletes the file from the specified `WriteLocation`
    /// - Parameter location: Specified `WriteLocation` for the wrapper to write to
    public func delete(location: WriteLocation) throws {
        try FileManager.default.removeItem(at: location.url)
    }
    
    /// Deletes all files in all cases of `WriteLocation`
    public func deleteAll() throws {
        FileHelper.WriteLocation.allCases.forEach { try? delete(location: $0) }
    }
}

extension FileManager {
    public static func getDocumentsDirectory() -> URL {
        let paths = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        return paths
    }
}
