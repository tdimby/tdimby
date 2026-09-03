import Foundation

enum FirestoreError: LocalizedError {
    case notConfigured
    case notSignedIn
    case transportFailed(String)
    case httpError(Int, String)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "MusicRate isn't connected to a Firebase project yet — add your API key in FirebaseConfig.swift."
        case .notSignedIn:
            return "Sign in first."
        case .transportFailed(let detail):
            return "Couldn't reach the database: \(detail)"
        case .httpError(let status, let message):
            return "Database error (HTTP \(status)): \(message)"
        case .decodingFailed:
            return "The database returned something MusicRate couldn't understand."
        }
    }
}

/// A document fetched from Firestore, already unwrapped into plain values.
struct FirestoreDocument {
    let id: String
    let fields: [String: Any]
}

/// Firestore's REST API, authenticated with the ID token from
/// `FirebaseAuthService`/`AccountStore`. Plain HTTPS + JSON (via
/// `FirestoreValue`'s wire-format helpers) rather than the Firebase SDK.
enum FirestoreService {
    private static var baseURL: String {
        "https://firestore.googleapis.com/v1/projects/\(FirebaseConfig.projectID)/databases/(default)/documents"
    }

    static func getDocument(path: String, idToken: String) async throws -> FirestoreDocument? {
        var request = URLRequest(url: URL(string: "\(baseURL)/\(path)")!)
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        do {
            let data = try await send(request)
            guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw FirestoreError.decodingFailed
            }
            guard let id = FirestoreValue.documentID(from: raw) else { return nil }
            return FirestoreDocument(id: id, fields: FirestoreValue.fields(from: raw))
        } catch FirestoreError.httpError(404, _) {
            return nil
        }
    }

    @discardableResult
    static func setDocument(path: String, fields: [String: Any?], idToken: String) async throws -> FirestoreDocument {
        var request = URLRequest(url: URL(string: "\(baseURL)/\(path)")!)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: FirestoreValue.documentBody(from: fields))

        let data = try await send(request)
        guard
            let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let id = FirestoreValue.documentID(from: raw)
        else { throw FirestoreError.decodingFailed }
        return FirestoreDocument(id: id, fields: FirestoreValue.fields(from: raw))
    }

    static func deleteDocument(path: String, idToken: String) async throws {
        var request = URLRequest(url: URL(string: "\(baseURL)/\(path)")!)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        _ = try? await send(request)
    }

    /// Fetches every document in `collectionPath` matching all of
    /// `equals` (field == value, ANDed together). Firestore requires
    /// `runQuery` (not a plain GET) for any filtered/sorted read.
    static func query(
        collectionPath: String,
        equals: [String: Any] = [:],
        orderBy: String? = nil,
        descending: Bool = false,
        limit: Int? = nil,
        idToken: String
    ) async throws -> [FirestoreDocument] {
        var segments = collectionPath.components(separatedBy: "/")
        let collectionID = segments.removeLast()
        let parentPath = segments.joined(separator: "/")
        let parentURL = parentPath.isEmpty ? baseURL : "\(baseURL)/\(parentPath)"

        var structuredQuery: [String: Any] = [
            "from": [["collectionId": collectionID]]
        ]

        if !equals.isEmpty {
            let filters: [[String: Any]] = equals.map { key, value in
                [
                    "fieldFilter": [
                        "field": ["fieldPath": key],
                        "op": "EQUAL",
                        "value": queryValue(value)
                    ]
                ]
            }
            if filters.count == 1 {
                structuredQuery["where"] = filters[0]
            } else {
                structuredQuery["where"] = ["compositeFilter": ["op": "AND", "filters": filters]]
            }
        }

        if let orderBy {
            structuredQuery["orderBy"] = [[
                "field": ["fieldPath": orderBy],
                "direction": descending ? "DESCENDING" : "ASCENDING"
            ]]
        }
        if let limit {
            structuredQuery["limit"] = limit
        }

        var request = URLRequest(url: URL(string: "\(parentURL):runQuery")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["structuredQuery": structuredQuery])

        let data = try await send(request)
        guard let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw FirestoreError.decodingFailed
        }

        return rows.compactMap { row -> FirestoreDocument? in
            guard let doc = row["document"] as? [String: Any], let id = FirestoreValue.documentID(from: doc) else {
                return nil
            }
            return FirestoreDocument(id: id, fields: FirestoreValue.fields(from: doc))
        }
    }

    private static func queryValue(_ value: Any) -> [String: Any] {
        switch value {
        case let v as String: return ["stringValue": v]
        case let v as Bool: return ["booleanValue": v]
        case let v as Int: return ["integerValue": String(v)]
        default: return ["stringValue": String(describing: value)]
        }
    }

    private static func send(_ request: URLRequest) async throws -> Data {
        guard FirebaseConfig.isConfigured else { throw FirestoreError.notConfigured }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw FirestoreError.transportFailed(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw FirestoreError.transportFailed("no HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw FirestoreError.httpError(http.statusCode, String(body.prefix(200)))
        }
        return data
    }
}
