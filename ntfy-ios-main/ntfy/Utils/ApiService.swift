import Foundation

class ApiService {
    static let shared = ApiService()
    static let userAgent = "ntfy/\(Config.version) (build \(Config.build); iOS \(Config.osVersion))"
    
    private let tag = "ApiService"
    
    func poll(subscription: Subscription, user: BasicUser?, completionHandler: @escaping ([Message]?, Error?) -> Void) {
        guard let url = URL(string: subscription.urlString()) else {
            completionHandler(nil, URLError(.badURL))
            return
        }
        let since = subscription.lastNotificationId ?? "all"
        let urlString = "\(url)/json?poll=1&since=\(since)"
        
        Log.d(tag, "Polling from \(urlString) with user \(user?.username ?? "anonymous")")
        fetchJsonData(urlString: urlString, user: user, completionHandler: completionHandler)
    }
    
    func poll(subscription: Subscription, messageId: String, user: BasicUser?, completionHandler: @escaping (Message?, Error?) -> Void) {
        poll(baseUrl: subscription.baseUrl ?? "?", topic: subscription.topic ?? "?", messageId: messageId, user: user, completionHandler: completionHandler)
    }

    func poll(baseUrl: String, topic: String, messageId: String, user: BasicUser?, completionHandler: @escaping (Message?, Error?) -> Void) {
        guard let url = URL(string: "\(topicUrl(baseUrl: baseUrl, topic: topic))/json?poll=1&id=\(messageId)") else {
            completionHandler(nil, URLError(.badURL))
            return
        }
        Log.d(tag, "Polling single message from \(url) with user \(user?.username ?? "anonymous")")
        
        let request = newRequest(url: url, user: user)
        newSession(timeout: 30).dataTask(with: request) { (data, response, error) in
            if let error = error {
                completionHandler(nil, error)
                return
            }
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                completionHandler(nil, URLError(.badServerResponse))
                return
            }
            guard let data = data else {
                completionHandler(nil, URLError(.badServerResponse))
                return
            }
            do {
                let message = try JSONDecoder().decode(Message.self, from: data)
                completionHandler(message, nil)
            } catch {
                completionHandler(nil, error)
            }
        }.resume()
    }

    func publish(
        subscription: Subscription,
        user: BasicUser?,
        message: String,
        title: String,
        priority: Int = 3,
        tags: [String] = [],
        completionHandler: (() -> Void)? = nil
    ) {
        publish(
            subscription: subscription,
            user: user,
            message: message,
            title: title,
            priority: priority,
            tags: tags,
            markdown: false,
            click: nil,
            delay: nil,
            email: nil,
            call: nil,
            attachUrl: nil,
            attachData: nil,
            attachFilename: nil,
            attachMime: nil,
            customHeaders: []
        ) { error in
            if error == nil {
                completionHandler?()
            }
        }
    }

    func publish(
        subscription: Subscription,
        user: BasicUser?,
        message: String,
        title: String,
        priority: Int = 3,
        tags: [String] = [],
        markdown: Bool = false,
        click: String? = nil,
        delay: String? = nil,
        email: String? = nil,
        call: String? = nil,
        attachUrl: String? = nil,
        attachData: Data? = nil,
        attachFilename: String? = nil,
        attachMime: String? = nil,
        customHeaders: [(name: String, value: String)] = [],
        completionHandler: ((Error?) -> Void)? = nil
    ) {
        guard let url = URL(string: subscription.urlString()) else {
            completionHandler?(URLError(.badURL))
            return
        }
        var request = newRequest(url: url, user: user, customHeaders: customHeaders)
        request.httpMethod = "POST"
        if !title.isEmpty {
            request.setValue(title, forHTTPHeaderField: "Title")
        }
        request.setValue(String(priority), forHTTPHeaderField: "Priority")
        if !tags.isEmpty {
            request.setValue(tags.joined(separator: ","), forHTTPHeaderField: "Tags")
        }
        if markdown {
            request.setValue("yes", forHTTPHeaderField: "Markdown")
        }
        if let click, !click.isEmpty {
            request.setValue(click, forHTTPHeaderField: "Click")
        }
        if let delay, !delay.isEmpty {
            request.setValue(delay, forHTTPHeaderField: "Delay")
        }
        if let email, !email.isEmpty {
            request.setValue(email, forHTTPHeaderField: "Email")
        }
        if let call, !call.isEmpty {
            request.setValue(call, forHTTPHeaderField: "Call")
        }
        if let attachUrl, !attachUrl.isEmpty {
            request.setValue(attachUrl, forHTTPHeaderField: "Attach")
        }

        Log.d(tag, "Publishing to \(url)")

        if let attachData, let attachFilename, !attachFilename.isEmpty {
            request.setValue(message, forHTTPHeaderField: "Message")
            request.setValue(attachFilename, forHTTPHeaderField: "Filename")
            if let attachMime, !attachMime.isEmpty {
                request.setValue(attachMime, forHTTPHeaderField: "Content-Type")
            } else {
                request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            }
            request.httpBody = attachData
        } else {
            request.httpBody = message.data(using: .utf8)
        }

        newSession(timeout: 120).dataTask(with: request) { (_, response, error) in
            if let error {
                Log.e(self.tag, "Error publishing message", error)
                completionHandler?(error)
                return
            }
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                let err = NSError(domain: "ApiService", code: http.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"
                ])
                completionHandler?(err)
                return
            }
            Log.d(self.tag, "Publishing message succeeded", response)
            completionHandler?(nil)
        }.resume()
    }
    
    func checkAuth(baseUrl: String, topic: String, user: BasicUser?, completionHandler: @escaping(AuthResult) -> Void) {
        guard let url = URL(string: topicAuthUrl(baseUrl: baseUrl, topic: topic)) else { return }
        let request = newRequest(url: url, user: user)
        Log.d(tag, "Checking auth for \(url) with user \(user?.username ?? "anonymous")")
        newSession(timeout: 10).dataTask(with: request) { (data, response, error) in
            if let error = error {
                Log.e(self.tag, "Error checking auth: \(error)")
                completionHandler(.Error(error.localizedDescription))
            } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    completionHandler(.Unauthorized)
                } else {
                    completionHandler(.Error("Unexpected response from server: \(httpResponse.statusCode)"))
                }
            } else if let data = data {
                do {
                    let result = try JSONDecoder().decode(AuthCheckResponse.self, from: data)
                    Log.d(self.tag, "Auth result: \(result)")
                    if result.success == true {
                        completionHandler(.Success)
                    } else {
                        completionHandler(.Error("Unexpected response from server"))
                    }
                } catch {
                    Log.e(self.tag, "Error handling auth response: \(error)")
                    completionHandler(.Error("Unexpected response from server. Is this a ntfy server?"))
                }
            }
        }.resume()
    }

    private func fetchJsonData<T: Decodable>(urlString: String, user: BasicUser?, completionHandler: @escaping ([T]?, Error?) -> ()) {
        guard let url = URL(string: urlString) else {
            completionHandler(nil, URLError(.badURL))
            return
        }
        let request = newRequest(url: url, user: user)
        newSession(timeout: 30).dataTask(with: request) { (data, response, error) in
            if let error {
                Log.e(self.tag, "Error fetching data", error)
                completionHandler(nil, error)
                return
            }
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                completionHandler(nil, URLError(.badServerResponse))
                return
            }
            guard let data = data else {
                completionHandler(nil, URLError(.badServerResponse))
                return
            }
            do {
                let lines = String(decoding: data, as: UTF8.self).split(whereSeparator: \.isNewline)
                var notifications: [T] = []
                for jsonLine in lines {
                    guard let jsonData = jsonLine.data(using: .utf8) else {
                        throw URLError(.cannotDecodeContentData)
                    }
                    notifications.append(try JSONDecoder().decode(T.self, from: jsonData))
                }
                completionHandler(notifications, nil)
            } catch {
                Log.e(self.tag, "Error fetching data", error)
                completionHandler(nil, error)
            }
        }.resume()
    }
    
    private func newRequest(url: URL, user: BasicUser?, customHeaders: [(name: String, value: String)] = []) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(ApiService.userAgent, forHTTPHeaderField: "User-Agent")
        if let user = user {
            request.setValue(user.toHeader(), forHTTPHeaderField: "Authorization")
        }
        let headers = customHeaders.isEmpty ? Store.shared.getCustomHeaders() : customHeaders
        for header in headers {
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }
        return request
    }
    
    private func newSession(timeout: TimeInterval) -> URLSession {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = timeout
        sessionConfig.timeoutIntervalForResource = timeout
        return URLSession(configuration: sessionConfig)
    }
}

struct BasicUser {
    let username: String
    let password: String
    
    func toHeader() -> String {
        return "Basic " + String(format: "%@:%@", username, password).data(using: String.Encoding.utf8)!.base64EncodedString()
    }
}

enum AuthResult {
    case Success
    case Unauthorized
    case Error(String)
}

struct AuthCheckResponse: Codable {
    let success: Bool?
    let code: Int?
    let http: Int?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success, code, http, error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.success = try container.decodeIfPresent(Bool.self, forKey: .success)
        self.code = try container.decodeIfPresent(Int.self, forKey: .code)
        self.http = try container.decodeIfPresent(Int.self, forKey: .http)
        self.error = try container.decodeIfPresent(String.self, forKey: .error)
    }
}
