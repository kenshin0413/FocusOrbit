import Foundation

protocol SessionPersisting: AnyObject {
    func loadSession() -> FocusSession?
    func saveSession(_ session: FocusSession)
    func clearSession()
}

@MainActor
final class SessionPersistenceStore: SessionPersisting {
    static let shared = SessionPersistenceStore()

    private let defaults: UserDefaults
    private let sessionKey = "focusOrbit.focusSession.v1"
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        decoder.dateDecodingStrategy = .millisecondsSince1970
    }

    func loadSession() -> FocusSession? {
        guard let data = defaults.data(forKey: sessionKey) else { return nil }
        guard let session = try? decoder.decode(FocusSession.self, from: data), session.isValid else {
            defaults.removeObject(forKey: sessionKey)
            return nil
        }
        return session
    }

    func saveSession(_ session: FocusSession) {
        guard session.isValid, let data = try? encoder.encode(session) else { return }
        defaults.set(data, forKey: sessionKey)
    }

    func clearSession() {
        defaults.removeObject(forKey: sessionKey)
    }
}

@MainActor
final class InMemorySessionPersistenceStore: SessionPersisting {
    var session: FocusSession?
    func loadSession() -> FocusSession? { session }
    func saveSession(_ session: FocusSession) { self.session = session }
    func clearSession() { session = nil }
}
