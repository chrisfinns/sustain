import Foundation
import UniformTypeIdentifiers

/// Attachment files live in Application Support/Sustain/Media, named by attachment id.
/// The database stores only the file name, so PDFKit, AVFoundation and Quick Look get real URLs.
struct MediaStore {
    let root: URL

    static func appDefault() throws -> MediaStore {
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                  appropriateFor: nil, create: true)
        let root = support.appending(path: "Sustain/Media", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return MediaStore(root: root)
    }

    /// A fresh folder in tmp, for UI tests and the demo, so they never touch the real media.
    static func temporary() throws -> MediaStore {
        let root = FileManager.default.temporaryDirectory.appending(path: "Sustain-Media-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return MediaStore(root: root)
    }

    func url(for fileName: String) -> URL {
        root.appending(path: fileName, directoryHint: .notDirectory)
    }

    /// Copies a file in. Returns the stored file name and its size.
    func add(fileAt source: URL, id: String) throws -> (fileName: String, size: Int) {
        let ext = source.pathExtension.isEmpty ? "bin" : source.pathExtension.lowercased()
        let name = "\(id).\(ext)"
        let dest = url(for: name)
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        if FileManager.default.fileExists(atPath: dest.path) { try FileManager.default.removeItem(at: dest) }
        try FileManager.default.copyItem(at: source, to: dest)
        let size = (try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? Int) ?? 0
        return (name, size)
    }

    /// Writes pasted data (e.g. a screenshot).
    func add(data: Data, ext: String, id: String) throws -> (fileName: String, size: Int) {
        let name = "\(id).\(ext)"
        try data.write(to: url(for: name), options: .atomic)
        return (name, data.count)
    }

    func remove(_ fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    /// Deletes files no attachment points to, if they're older than `olderThan` (so an in-flight capture is safe).
    func removeOrphans(keeping: Set<String>, olderThan: Date) {
        let files = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        for file in files where !keeping.contains(file.lastPathComponent) {
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantFuture
            if modified < olderThan { try? FileManager.default.removeItem(at: file) }
        }
    }

    static func kind(of url: URL) -> AttachmentKind {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return .file }
        if type.conforms(to: .image) { return .image }
        if type.conforms(to: .pdf) { return .pdf }
        if type.conforms(to: .audio) { return .audio }
        return .file
    }

    static func mime(of url: URL) -> String {
        UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
    }
}
