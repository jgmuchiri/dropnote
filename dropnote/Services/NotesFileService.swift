import Foundation

final class NotesFileService {
    static let shared = NotesFileService()
    
    private let notesPath: URL
    
    private init() {
        self.notesPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/DropNote/notes.json")
    }
    
    // MARK: - Public Methods
    
    func loadNotes() -> [Note]? {
        guard FileManager.default.fileExists(atPath: notesPath.path),
              let data = try? Data(contentsOf: notesPath),
              var decoded = try? JSONDecoder().decode([Note].self, from: data) else {
            return nil
        }
        
        ensureAllNotesHaveModifiedDate(&decoded)
        return decoded
    }
    
    func saveNotes(_ notes: [Note]) {
        let folderURL = notesPath.deletingLastPathComponent()
        try? FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        
        if let data = try? JSONEncoder().encode(notes) {
            writeProtected(data)
        }
    }
    
    // MARK: - Private Methods
    
    private func ensureAllNotesHaveModifiedDate(_ notes: inout [Note]) {
        var needsSave = false
        for i in 0..<notes.count {
            if notes[i].lastModified == nil {
                notes[i].lastModified = Date()
                needsSave = true
            }
        }
        
        if needsSave {
            if let updatedData = try? JSONEncoder().encode(notes) {
                writeProtected(updatedData)
            }
        }
    }

    /// Atomic write (a crash can't leave a truncated file) readable only by the user.
    private func writeProtected(_ data: Data) {
        do {
            try data.write(to: notesPath, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: notesPath.path)
        } catch {
            NSLog("DropNote: failed to save notes: \(error.localizedDescription)")
        }
    }
}
