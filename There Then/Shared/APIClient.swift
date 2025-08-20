//
//  APIClient.swift
//  There Then
//
//  Created by Paul Wicks on 8/13/25.
//
import Foundation
import Combine

class APIClient: ObservableObject {
    static let shared = APIClient()

    private let baseURL = "http://localhost:8000/api"
    private var authToken: String?

    private init() {}

    // MARK: - Authentication
    func setAuthToken(_ token: String) {
        self.authToken = token
    }

    func login(email: String, password: String) -> AnyPublisher<LoginResponse, Error> {
        let loginData = [
            "email": email,
            "password": password
        ]

        let body = try? JSONSerialization.data(withJSONObject: loginData)
        return makeRequest("/token/", method: "POST", body: body)
    }

    func refreshToken(_ refreshToken: String) -> AnyPublisher<LoginResponse, Error> {
        let refreshData = [
            "refresh": refreshToken
        ]

        let body = try? JSONSerialization.data(withJSONObject: refreshData)
        return makeRequest("/token/refresh/", method: "POST", body: body)
    }

    private func getHeaders() -> [String: String] {
        var headers = ["Content-Type": "application/json"]
        if let token = authToken {
            headers["Authorization"] = "Bearer \(token)"
        }
        return headers
    }

    // MARK: - Generic Request Method
    private func makeRequest<T: Codable>(_ endpoint: String, method: String = "GET", body: Data? = nil) -> AnyPublisher<T, Error> {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.allHTTPHeaderFields = getHeaders()

        if let body = body {
            request.httpBody = body
        }

        let decoder = JSONDecoder()

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output -> Data in
                guard let httpResponse = output.response as? HTTPURLResponse else {
                    throw APIError.serverError("Invalid response")
                }
                guard (200...299).contains(httpResponse.statusCode) else {
                    if let serverError = try? decoder.decode(ErrorResponse.self, from: output.data) {
                        throw APIError.serverError(serverError.error)
                    }
                    if let text = String(data: output.data, encoding: .utf8) {
                        throw APIError.serverError("HTTP \(httpResponse.statusCode): \(text)")
                    }
                    throw APIError.serverError("HTTP \(httpResponse.statusCode)")
                }
                return output.data
            }
            .decode(type: T.self, decoder: decoder)
            .mapError { error in
                if let apiError = error as? APIError { return apiError }
                if let decodingError = error as? DecodingError {
                    return APIError.serverError("Decoding error: \(decodingError)")
                }
                return APIError.networkError(error)
            }
            .eraseToAnyPublisher()
    }

    // MARK: - User Management
    func createUser(email: String, username: String, password: String, firstName: String?, lastName: String?) -> AnyPublisher<LoginResponse, Error> {
        let userData = [
            "email": email,
            "username": username,
            "password": password,
            "password_confirm": password,
            "first_name": firstName ?? "",
            "last_name": lastName ?? ""
        ]

        let body = try? JSONSerialization.data(withJSONObject: userData)
        return makeRequest("/users/", method: "POST", body: body)
    }

    func getCurrentUser() -> AnyPublisher<User, Error> {
        return makeRequest("/users/me/")
    }

    func updateProfile(firstName: String?, lastName: String?) -> AnyPublisher<User, Error> {
        let profileData = [
            "first_name": firstName ?? "",
            "last_name": lastName ?? ""
        ]

        let body = try? JSONSerialization.data(withJSONObject: profileData)
        return makeRequest("/users/update_profile/", method: "PATCH", body: body)
    }

    // MARK: - Geographic Areas
    func createGeographicArea(
        name: String?,
        geometryWkt: String,
        startYear: Int,
        endYear: Int,
        startMonth: Int?,
        endMonth: Int?,
        userId: String? = nil
    ) -> AnyPublisher<GeographicArea, Error> {
        var areaData: [String: Any] = [
            "name": name ?? "",
            "geometry_wkt": geometryWkt,
            "start_year": startYear,
            "end_year": endYear
        ]
        if let startMonth = startMonth { areaData["start_month"] = startMonth }
        if let endMonth = endMonth { areaData["end_month"] = endMonth }
        if userId != nil {
            areaData["created_by"] = userId ?? ""
        }

        let body = try? JSONSerialization.data(withJSONObject: areaData)
        return makeRequest("/areas/", method: "POST", body: body)
    }

    func searchAreasByLocation(latitude: Double, longitude: Double, radiusKm: Double = 10) -> AnyPublisher<[GeographicArea], Error> {
        let locationData = [
            "latitude": latitude,
            "longitude": longitude,
            "radius_km": radiusKm
        ]

        let body = try? JSONSerialization.data(withJSONObject: locationData)
        return makeRequest("/areas/search_by_location/", method: "POST", body: body)
    }

    func searchAreasByTime(startYear: Int?, endYear: Int?, startMonth: Int?, endMonth: Int?) -> AnyPublisher<[GeographicArea], Error> {
        var timeData: [String: Any] = [:]
        if let startYear = startYear { timeData["start_year"] = startYear }
        if let endYear = endYear { timeData["end_year"] = endYear }
        if let startMonth = startMonth { timeData["start_month"] = startMonth }
        if let endMonth = endMonth { timeData["end_month"] = endMonth }

        let body = try? JSONSerialization.data(withJSONObject: timeData)
        return makeRequest("/areas/search_by_time/", method: "POST", body: body)
    }

    func searchAreasByIntersection(geometryWkt: String) -> AnyPublisher<[GeographicArea], Error> {
        let intersectionData = ["geometry": geometryWkt]
        let body = try? JSONSerialization.data(withJSONObject: intersectionData)
        return makeRequest("/areas/search_by_intersection/", method: "POST", body: body)
    }

    func getAllAreas() -> AnyPublisher<[GeographicArea], Error> {
        return makeRequest("/areas/")
    }

    // MARK: - Channels
    func createChannel(name: String, areaId: String, isPrivate: Bool = false) -> AnyPublisher<Channel, Error> {
        let channelData = [
            "name": name,
            "area": areaId,
            "is_private": isPrivate
        ] as [String : Any]

        let body = try? JSONSerialization.data(withJSONObject: channelData)
        return makeRequest("/channels/", method: "POST", body: body)
    }

    func getMyChannels() -> AnyPublisher<[Channel], Error> {
        return makeRequest("/channels/my_channels/")
    }

    func joinChannel(_ channelId: String) -> AnyPublisher<ChannelMembership, Error> {
        return makeRequest("/channels/\(channelId)/join/", method: "POST")
    }

    func leaveChannel(_ channelId: String) -> AnyPublisher<[String: String], Error> {
        return makeRequest("/channels/\(channelId)/leave/", method: "POST")
    }

    func getChannelMembers(_ channelId: String) -> AnyPublisher<[ChannelMembership], Error> {
        return makeRequest("/channels/\(channelId)/members/")
    }

    // MARK: - Messages
    func createMessage(channelId: String, content: String, isAnonymous: Bool = true, containsPii: Bool = false, restrictedToNames: [String] = []) -> AnyPublisher<Message, Error> {
        let messageData = [
            "channel": channelId,
            "content": content,
            "is_anonymous": isAnonymous,
            "contains_pii": containsPii,
            "restricted_to_names": restrictedToNames
        ] as [String : Any]

        let body = try? JSONSerialization.data(withJSONObject: messageData)
        return makeRequest("/messages/", method: "POST", body: body)
    }

    func getMessagesByChannel(_ channelId: String) -> AnyPublisher<[Message], Error> {
        return makeRequest("/messages/by_channel/?channel_id=\(channelId)")
    }

    func reactToMessage(_ messageId: String, reactionType: String) -> AnyPublisher<MessageReaction, Error> {
        let reactionData = [
            "message": messageId,
            "reaction_type": reactionType
        ]

        let body = try? JSONSerialization.data(withJSONObject: reactionData)
        return makeRequest("/reactions/", method: "POST", body: body)
    }

    // MARK: - Direct Messages
    func sendDirectMessage(recipientId: String, content: String) -> AnyPublisher<DirectMessage, Error> {
        let messageData = [
            "recipient": recipientId,
            "content": content
        ]

        let body = try? JSONSerialization.data(withJSONObject: messageData)
        return makeRequest("/direct-messages/", method: "POST", body: body)
    }

    func getConversation(with userId: String) -> AnyPublisher<[DirectMessage], Error> {
        return makeRequest("/direct-messages/conversation/?user_id=\(userId)")
    }

    func markMessageAsRead(_ messageId: String) -> AnyPublisher<DirectMessage, Error> {
        return makeRequest("/direct-messages/\(messageId)/mark_read/", method: "POST")
    }

    func getUnreadCount() -> AnyPublisher<[String: Int], Error> {
        return makeRequest("/direct-messages/unread_count/")
    }

    // MARK: - User Locations
    func createUserLocation(areaId: String, visitedYear: Int, visitedMonth: Int?) -> AnyPublisher<UserLocation, Error> {
        var locationData: [String: Any] = [
            "area": areaId,
            "visited_year": visitedYear
        ]
        if let visitedMonth = visitedMonth {
            locationData["visited_month"] = visitedMonth
        }

        let body = try? JSONSerialization.data(withJSONObject: locationData)
        return makeRequest("/locations/", method: "POST", body: body)
    }

    func getUserLocations() -> AnyPublisher<[UserLocation], Error> {
        return makeRequest("/locations/")
    }

    func getUserLocationsByArea(_ areaId: String) -> AnyPublisher<[UserLocation], Error> {
        return makeRequest("/locations/by_area/?area_id=\(areaId)")
    }
}

// MARK: - API Error Types
enum APIError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError:
            return "Failed to decode response"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}
