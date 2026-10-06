import Foundation

public enum YouTubeLink {
    /// The 11-character video id from any common YouTube URL shape, or nil.
    public static func videoId(_ input: String) -> String? {
        let raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return nil }
        if isId(raw) { return raw }
        guard let url = components(raw), var host = url.host?.lowercased() else { return nil }
        for prefix in ["www.", "m.", "music."] where host.hasPrefix(prefix) {
            host.removeFirst(prefix.count)
        }
        let path = url.path.split(separator: "/").map(String.init)
        if host == "youtu.be" {
            return path.first.flatMap { isId($0) ? $0 : nil }
        }
        if host == "youtube.com" || host == "youtube-nocookie.com" {
            if let v = url.queryItems?.first(where: { $0.name == "v" })?.value, isId(v) { return v }
            if path.count >= 2, ["embed", "shorts", "live", "v"].contains(path[0]), isId(path[1]) { return path[1] }
        }
        return nil
    }

    /// Start time from t= / start= (90, 1m30s, 1h2m3s) in seconds, or nil.
    public static func startSeconds(_ input: String) -> Int? {
        guard let url = components(input.trimmingCharacters(in: .whitespacesAndNewlines)),
              let t = url.queryItems?.first(where: { $0.name == "t" || $0.name == "start" })?.value, !t.isEmpty
        else { return nil }
        if let n = Int(t) { return n }
        var total = 0, number = "", sawUnit = false
        for ch in t {
            if ch.isASCII && ch.isNumber {
                number.append(ch)
            } else {
                guard let n = Int(number) else { return nil }
                switch ch {
                case "h": total += n * 3600
                case "m": total += n * 60
                case "s": total += n
                default: return nil
                }
                number = ""
                sawUnit = true
            }
        }
        return sawUnit && number.isEmpty ? total : nil
    }

    /// 83.4 -> "1:23"
    public static func formatTime(_ seconds: Double?) -> String {
        guard let seconds, seconds.isFinite else { return "—" }
        let s = max(0, Int(seconds.rounded(.down)))
        return "\(s / 60):\(pad2(s % 60))"
    }

    static func isId(_ s: String) -> Bool {
        s.count == 11 && s.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }
    }

    static func components(_ raw: String) -> URLComponents? {
        let lower = raw.lowercased()
        let withScheme = lower.hasPrefix("http://") || lower.hasPrefix("https://") ? raw : "https://" + raw
        return URLComponents(string: withScheme)
    }
}

public enum LinkKind: String, Sendable, Equatable {
    case youtube, pdf, link
}

public enum LinkDetect {
    /// What a pasted link is, for the Capture banner. Nil when it isn't a link.
    public static func detect(_ input: String) -> LinkKind? {
        let s = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return nil }
        if YouTubeLink.videoId(s) != nil && s.lowercased().contains("youtu") { return .youtube }
        let lower = s.lowercased()
        let isURL = lower.hasPrefix("http://") || lower.hasPrefix("https://")
        let path = lower.split(separator: "?", maxSplits: 1).first.map(String.init) ?? lower
        if isURL && path.hasSuffix(".pdf") { return .pdf }
        if isURL && !s.contains(where: \.isWhitespace) { return .link }
        return nil
    }
}
