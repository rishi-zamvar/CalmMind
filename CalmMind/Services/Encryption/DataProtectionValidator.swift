import Foundation

/// Data protection levels for iOS file encryption
enum DataProtectionLevel {
    case complete
    case completeUnlessOpen
    case completeUntilFirstUserAuthentication
    case none

    var fileProtectionType: FileProtectionType {
        switch self {
        case .complete:
            return .complete
        case .completeUnlessOpen:
            return .completeUnlessOpen
        case .completeUntilFirstUserAuthentication:
            return .completeUntilFirstUserAuthentication
        case .none:
            return .none
        }
    }

    init?(from type: FileProtectionType) {
        switch type {
        case .complete:
            self = .complete
        case .completeUnlessOpen:
            self = .completeUnlessOpen
        case .completeUntilFirstUserAuthentication:
            self = .completeUntilFirstUserAuthentication
        case .none:
            self = .none
        default:
            return nil
        }
    }
}

/// Result of database protection validation
struct DatabaseProtectionResult {
    let databaseFileChecked: Bool
    let databaseProtectionLevel: DataProtectionLevel?
    let walFileChecked: Bool
    let walProtectionLevel: DataProtectionLevel?
    let shmFileChecked: Bool
    let shmProtectionLevel: DataProtectionLevel?
    let allFilesProtected: Bool
    let issues: [String]
}

/// Validates and manages iOS Data Protection for files
/// iOS automatically encrypts files using hardware keys when Data Protection is enabled
final class DataProtectionValidator {

    // MARK: - Dependencies

    private let fileManager: FileManager

    // MARK: - Initialization

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    // MARK: - Public API

    /// Get the protection level for a file
    /// - Parameter url: The file URL to check
    /// - Returns: The protection level, or nil if it can't be determined
    func getProtectionLevel(for url: URL) -> DataProtectionLevel? {
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            if let protectionValue = attributes[.protectionKey] as? FileProtectionType {
                return DataProtectionLevel(from: protectionValue)
            }
        } catch {
            // In simulator or when protection isn't available
            return nil
        }

        return nil
    }

    /// Set the protection level for a file or directory
    /// - Parameters:
    ///   - level: The desired protection level
    ///   - url: The file or directory URL
    /// - Returns: True if successful
    @discardableResult
    func setProtectionLevel(_ level: DataProtectionLevel, for url: URL) -> Bool {
        do {
            try fileManager.setAttributes(
                [.protectionKey: level.fileProtectionType],
                ofItemAtPath: url.path
            )
            return true
        } catch {
            // May fail in simulator or without proper entitlements
            return false
        }
    }

    /// Validate protection levels for SQLite database files
    /// SQLite uses WAL mode which creates additional files that also need protection
    /// - Parameters:
    ///   - directory: The directory containing the database
    ///   - databaseName: The name of the SQLite file (e.g., "store.sqlite")
    /// - Returns: Validation result with details about each file
    func validateDatabaseProtection(at directory: URL, databaseName: String) -> DatabaseProtectionResult {
        let dbPath = directory.appendingPathComponent(databaseName)
        let walPath = directory.appendingPathComponent("\(databaseName)-wal")
        let shmPath = directory.appendingPathComponent("\(databaseName)-shm")

        var issues: [String] = []

        // Check main database file
        let dbExists = fileManager.fileExists(atPath: dbPath.path)
        let dbLevel = getProtectionLevel(for: dbPath)

        // Check WAL file (may not exist yet)
        let walExists = fileManager.fileExists(atPath: walPath.path)
        let walLevel = walExists ? getProtectionLevel(for: walPath) : nil

        // Check SHM file (may not exist yet)
        let shmExists = fileManager.fileExists(atPath: shmPath.path)
        let shmLevel = shmExists ? getProtectionLevel(for: shmPath) : nil

        // Check for issues
        if dbExists && dbLevel != .complete && dbLevel != nil {
            issues.append("Database file not protected with 'complete' level")
        }
        if walExists && walLevel != .complete && walLevel != nil {
            issues.append("WAL file not protected with 'complete' level")
        }
        if shmExists && shmLevel != .complete && shmLevel != nil {
            issues.append("SHM file not protected with 'complete' level")
        }

        let allProtected = issues.isEmpty && dbExists

        return DatabaseProtectionResult(
            databaseFileChecked: dbExists,
            databaseProtectionLevel: dbLevel,
            walFileChecked: walExists,
            walProtectionLevel: walLevel,
            shmFileChecked: shmExists,
            shmProtectionLevel: shmLevel,
            allFilesProtected: allProtected,
            issues: issues
        )
    }

    /// Apply complete protection to all database files
    /// - Parameters:
    ///   - directory: The directory containing the database
    ///   - databaseName: The name of the SQLite file
    /// - Returns: True if all files were protected successfully
    @discardableResult
    func protectDatabaseFiles(at directory: URL, databaseName: String) -> Bool {
        let files = [
            directory.appendingPathComponent(databaseName),
            directory.appendingPathComponent("\(databaseName)-wal"),
            directory.appendingPathComponent("\(databaseName)-shm")
        ]

        var allSuccess = true
        for file in files {
            if fileManager.fileExists(atPath: file.path) {
                if !setProtectionLevel(.complete, for: file) {
                    allSuccess = false
                }
            }
        }

        return allSuccess
    }

    /// Protect the App Group container directory
    /// - Parameter groupIdentifier: The app group identifier
    /// - Returns: True if protection was applied
    @discardableResult
    func protectAppGroupContainer(groupIdentifier: String) -> Bool {
        guard let containerURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: groupIdentifier
        ) else {
            return false
        }

        return setProtectionLevel(.complete, for: containerURL)
    }
}
