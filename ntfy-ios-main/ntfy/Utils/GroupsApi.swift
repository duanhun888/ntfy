import Foundation

struct ChatGroup: Codable, Identifiable {
    let id: String
    let name: String
    let topic: String
    let created: Int64?
    let memberCount: Int64?
    let role: String?
    let ownerUserId: String?

    enum CodingKeys: String, CodingKey {
        case id, name, topic, created, role
        case memberCount = "member_count"
        case ownerUserId = "owner_user_id"
    }
}

struct ChatMember: Codable, Identifiable {
    var id: String { userId }
    let userId: String
    let username: String?
    let role: String?
    let joined: Int64?

    enum CodingKeys: String, CodingKey {
        case role, joined, username
        case userId = "user_id"
    }
}

struct ChatBot: Codable, Identifiable {
    let id: String
    let groupId: String?
    let name: String
    let tokenHint: String?
    let created: Int64?

    enum CodingKeys: String, CodingKey {
        case id, name, created
        case groupId = "group_id"
        case tokenHint = "token_hint"
    }
}

struct BotCreateResponse: Codable {
    let id: String
    let groupId: String?
    let name: String
    let token: String?
    let webhookUrl: String?
    let created: Int64?

    enum CodingKeys: String, CodingKey {
        case id, name, token, created
        case groupId = "group_id"
        case webhookUrl = "webhook_url"
    }
}

enum GroupsApiError: LocalizedError {
    case unauthorized
    case badURL
    case server(String)
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return NSLocalizedString("groups_api_unauthorized", comment: "")
        case .badURL:
            return NSLocalizedString("groups_api_bad_url", comment: "")
        case .server(let message):
            return message
        case .http(let code):
            return String(format: NSLocalizedString("groups_api_http", comment: ""), code)
        }
    }
}

/// Client for DingTalk-style /v1/groups APIs (Basic auth, same as Android).
class GroupsApi {
    static let shared = GroupsApi()
    private let tag = "GroupsApi"
    private let decoder = JSONDecoder()

    func listGroups(baseUrl: String, user: BasicUser, completion: @escaping (Result<[ChatGroup], Error>) -> Void) {
        guard let url = URL(string: "\(normalizeBaseUrl(baseUrl))/v1/groups") else {
            completion(.failure(GroupsApiError.badURL))
            return
        }
        request(url: url, method: "GET", user: user, body: nil) { data, error in
            if let error { completion(.failure(error)); return }
            do {
                let groups = try self.decoder.decode([ChatGroup].self, from: data ?? Data("[]".utf8))
                completion(.success(groups))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func createGroup(baseUrl: String, user: BasicUser, name: String, completion: @escaping (Result<ChatGroup, Error>) -> Void) {
        guard let url = URL(string: "\(normalizeBaseUrl(baseUrl))/v1/groups") else {
            completion(.failure(GroupsApiError.badURL))
            return
        }
        let body = try? JSONSerialization.data(withJSONObject: ["name": name])
        request(url: url, method: "POST", user: user, body: body) { data, error in
            if let error { completion(.failure(error)); return }
            do {
                let group = try self.decoder.decode(ChatGroup.self, from: data ?? Data())
                completion(.success(group))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func deleteGroup(baseUrl: String, user: BasicUser, groupId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(normalizeBaseUrl(baseUrl))/v1/groups/\(groupId)") else {
            completion(.failure(GroupsApiError.badURL))
            return
        }
        request(url: url, method: "DELETE", user: user, body: nil) { _, error in
            if let error { completion(.failure(error)); return }
            completion(.success(()))
        }
    }

    func listMembers(baseUrl: String, user: BasicUser, groupId: String, completion: @escaping (Result<[ChatMember], Error>) -> Void) {
        guard let url = URL(string: "\(normalizeBaseUrl(baseUrl))/v1/groups/\(groupId)/members") else {
            completion(.failure(GroupsApiError.badURL))
            return
        }
        request(url: url, method: "GET", user: user, body: nil) { data, error in
            if let error { completion(.failure(error)); return }
            do {
                let members = try self.decoder.decode([ChatMember].self, from: data ?? Data("[]".utf8))
                completion(.success(members))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func addMember(baseUrl: String, user: BasicUser, groupId: String, username: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(normalizeBaseUrl(baseUrl))/v1/groups/\(groupId)/members") else {
            completion(.failure(GroupsApiError.badURL))
            return
        }
        let body = try? JSONSerialization.data(withJSONObject: ["username": username])
        request(url: url, method: "POST", user: user, body: body) { _, error in
            if let error { completion(.failure(error)); return }
            completion(.success(()))
        }
    }

    func removeMember(baseUrl: String, user: BasicUser, groupId: String, userKey: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let encoded = userKey.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? userKey
        guard let url = URL(string: "\(normalizeBaseUrl(baseUrl))/v1/groups/\(groupId)/members/\(encoded)") else {
            completion(.failure(GroupsApiError.badURL))
            return
        }
        request(url: url, method: "DELETE", user: user, body: nil) { _, error in
            if let error { completion(.failure(error)); return }
            completion(.success(()))
        }
    }

    func listBots(baseUrl: String, user: BasicUser, groupId: String, completion: @escaping (Result<[ChatBot], Error>) -> Void) {
        guard let url = URL(string: "\(normalizeBaseUrl(baseUrl))/v1/groups/\(groupId)/bots") else {
            completion(.failure(GroupsApiError.badURL))
            return
        }
        request(url: url, method: "GET", user: user, body: nil) { data, error in
            if let error { completion(.failure(error)); return }
            do {
                let bots = try self.decoder.decode([ChatBot].self, from: data ?? Data("[]".utf8))
                completion(.success(bots))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func createBot(baseUrl: String, user: BasicUser, groupId: String, name: String, completion: @escaping (Result<BotCreateResponse, Error>) -> Void) {
        guard let url = URL(string: "\(normalizeBaseUrl(baseUrl))/v1/groups/\(groupId)/bots") else {
            completion(.failure(GroupsApiError.badURL))
            return
        }
        let body = try? JSONSerialization.data(withJSONObject: ["name": name])
        request(url: url, method: "POST", user: user, body: body) { data, error in
            if let error { completion(.failure(error)); return }
            do {
                let bot = try self.decoder.decode(BotCreateResponse.self, from: data ?? Data())
                completion(.success(bot))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func deleteBot(baseUrl: String, user: BasicUser, groupId: String, botId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(normalizeBaseUrl(baseUrl))/v1/groups/\(groupId)/bots/\(botId)") else {
            completion(.failure(GroupsApiError.badURL))
            return
        }
        request(url: url, method: "DELETE", user: user, body: nil) { _, error in
            if let error { completion(.failure(error)); return }
            completion(.success(()))
        }
    }

    private func request(url: URL, method: String, user: BasicUser, body: Data?, completion: @escaping (Data?, Error?) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(ApiService.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(user.toHeader(), forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        Log.d(tag, "\(method) \(url)")
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        URLSession(configuration: config).dataTask(with: request) { data, response, error in
            if let error {
                completion(nil, error)
                return
            }
            guard let http = response as? HTTPURLResponse else {
                completion(nil, GroupsApiError.http(0))
                return
            }
            if http.statusCode == 401 || http.statusCode == 403 {
                completion(nil, GroupsApiError.unauthorized)
                return
            }
            guard (200..<300).contains(http.statusCode) else {
                if let data, let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let msg = obj["error"] as? String {
                    completion(nil, GroupsApiError.server(msg))
                } else {
                    completion(nil, GroupsApiError.http(http.statusCode))
                }
                return
            }
            completion(data, nil)
        }.resume()
    }
}
