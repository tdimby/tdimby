import Foundation

/// Firestore's REST API doesn't use plain JSON for document fields — each
/// value is wrapped by type, e.g. `{"stringValue": "hi"}` or
/// `{"integerValue": "4"}`. These helpers convert between that wire format
/// and ordinary Swift dictionaries so the rest of the app never has to
/// think about it.
enum FirestoreValue {
    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Turns a plain `[String: Any?]` (nil values are simply omitted) into
    /// a Firestore REST document body: `{"fields": {...}}`.
    static func documentBody(from fields: [String: Any?]) -> [String: Any] {
        var wrapped: [String: Any] = [:]
        for (key, value) in fields {
            guard let value, !(value is NSNull) else { continue }
            wrapped[key] = encode(value)
        }
        return ["fields": wrapped]
    }

    private static func encode(_ value: Any) -> [String: Any] {
        switch value {
        case let v as String:
            return ["stringValue": v]
        case let v as Bool:
            // Must check Bool before Int - Bool bridges to NSNumber too.
            return ["booleanValue": v]
        case let v as Int:
            return ["integerValue": String(v)]
        case let v as Double:
            return ["doubleValue": v]
        case let v as Date:
            return ["timestampValue": dateFormatter.string(from: v)]
        case let v as [String]:
            return ["arrayValue": ["values": v.map { ["stringValue": $0] }]]
        default:
            return ["stringValue": String(describing: value)]
        }
    }

    /// Reads a Firestore REST document (`{"name":..., "fields": {...}}`)
    /// back into a plain `[String: Any]`, unwrapping each typed value.
    static func fields(from document: [String: Any]) -> [String: Any] {
        guard let rawFields = document["fields"] as? [String: Any] else { return [:] }
        var result: [String: Any] = [:]
        for (key, wrapped) in rawFields {
            if let decoded = decode(wrapped as? [String: Any] ?? [:]) {
                result[key] = decoded
            }
        }
        return result
    }

    private static func decode(_ wrapped: [String: Any]) -> Any? {
        if let s = wrapped["stringValue"] as? String { return s }
        if let i = wrapped["integerValue"] as? String { return Int(i) }
        if let d = wrapped["doubleValue"] as? Double { return d }
        if let b = wrapped["booleanValue"] as? Bool { return b }
        if let t = wrapped["timestampValue"] as? String { return dateFormatter.date(from: t) }
        if let arr = wrapped["arrayValue"] as? [String: Any] {
            let values = arr["values"] as? [[String: Any]] ?? []
            return values.compactMap(decode)
        }
        if wrapped["nullValue"] != nil { return nil }
        return nil
    }

    /// The document ID is the last path segment of a document's `name`.
    static func documentID(from document: [String: Any]) -> String? {
        guard let name = document["name"] as? String else { return nil }
        return name.components(separatedBy: "/").last
    }
}
