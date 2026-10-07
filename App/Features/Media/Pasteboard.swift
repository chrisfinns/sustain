import AppKit

extension NSPasteboard {
    /// Files copied in Finder. Checked before images, since Finder also puts the file's icon on the clipboard.
    var fileURLs: [URL] {
        (readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
    }

    /// An image on the clipboard as PNG data. Screenshots arrive as PNG or TIFF.
    var pngImage: Data? {
        if let data = data(forType: .png) { return data }
        if let tiff = data(forType: .tiff), let rep = NSBitmapImageRep(data: tiff) {
            return rep.representation(using: .png, properties: [:])
        }
        return nil
    }
}
