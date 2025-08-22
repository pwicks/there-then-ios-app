//
//  Models.swift
//  ThereThen
//
//  Created by Paul Wicks on 8/13/25.
//
import Foundation
import CoreLocation
import MapKit

// MARK: - Authentication Models
struct LoginResponse: Codable {
    let access: String
    let refresh: String
}

// MARK: - User Model
struct User: Codable, Identifiable {
    let id: String
    let email: String
    let username: String
    let firstName: String?
    let lastName: String?
    let isVerified: Bool
    let verificationDate: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case firstName = "first_name"
        case lastName = "last_name"
        case isVerified = "is_verified"
        case verificationDate = "verification_date"
        case createdAt = "created_at"
    }
}

// MARK: - Geographic Area Model
struct GeographicArea: Codable, Identifiable {
    let id: String
    let name: String?
    let geometryWkt: String?
    let startYear: Int
    let endYear: Int
    let startMonth: Int?
    let endMonth: Int?
    let createdBy: User?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case geometryWkt = "geometry_wkt"
        case startYear = "start_year"
        case endYear = "end_year"
        case startMonth = "start_month"
        case endMonth = "end_month"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}

// MARK: - Channel Model
struct Channel: Codable, Identifiable {
    let id: String
    let name: String
    let area: GeographicArea
    let createdBy: User?
    let isPrivate: Bool
    let createdAt: String?
    let updatedAt: String?
    let memberCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case area
        case createdBy = "created_by"
        case isPrivate = "is_private"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case memberCount = "member_count"
    }
}

// MARK: - Message Model
struct Message: Codable, Identifiable {
    let id: String
    let channel: Channel
    let author: User
    let content: String
    let isAnonymous: Bool
    let containsPii: Bool
    let restrictedToNames: [String]
    let createdAt: String?
    let updatedAt: String?
    let reactions: [String: Int]

    enum CodingKeys: String, CodingKey {
        case id
        case channel
        case author
        case content
        case isAnonymous = "is_anonymous"
        case containsPii = "contains_pii"
        case restrictedToNames = "restricted_to_names"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case reactions
    }
}

// MARK: - Direct Message Model
struct DirectMessage: Codable, Identifiable {
    let id: String
    let sender: User
    let recipient: User
    let content: String
    let isRead: Bool
    let createdAt: String
    let createdBy: User?

    enum CodingKeys: String, CodingKey {
        case id
        case sender
        case recipient
        case content
        case isRead = "is_read"
        case createdAt = "created_at"
        case createdBy = "created_by"
    }
}

// MARK: - Channel Membership Model
struct ChannelMembership: Codable, Identifiable {
    let id: String
    let channel: Channel
    let user: User
    let joinedAt: String
    let isAdmin: Bool
    let createdAt: String
    let createdBy: User?

    enum CodingKeys: String, CodingKey {
        case id
        case channel
        case user
        case joinedAt = "joined_at"
        case isAdmin = "is_admin"
        case createdAt = "created_at"
        case createdBy = "created_by"
    }
}

// MARK: - User Location Model
struct UserLocation: Codable, Identifiable {
    let id: String
    let user: User
    let area: GeographicArea
    let visitedYear: Int
    let visitedMonth: Int?
    let createdAt: String
    let createdBy: User?

    enum CodingKeys: String, CodingKey {
        case id
        case user
        case area
        case visitedYear = "visited_year"
        case visitedMonth = "visited_month"
        case createdAt = "created_at"
        case createdBy = "created_by"
    }
}

// MARK: - API Response Models
struct APIResponse<T: Codable>: Codable {
    let count: Int
    let next: String?
    let previous: String?
    let results: [T]
}

struct ErrorResponse: Codable {
    let error: String
}

// MARK: - Map Drawing Models
struct MapRectangle {
    let topLeft: CLLocationCoordinate2D
    let bottomRight: CLLocationCoordinate2D

    var center: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: (topLeft.latitude + bottomRight.latitude) / 2,
            longitude: (topLeft.longitude + bottomRight.longitude) / 2
        )
    }

    var span: MKCoordinateSpan {
        MKCoordinateSpan(
            latitudeDelta: abs(topLeft.latitude - bottomRight.latitude),
            longitudeDelta: abs(topLeft.longitude - bottomRight.longitude)
        )
    }
}

// MARK: - Time Period Model
struct TimePeriod {
    let startYear: Int
    let endYear: Int
    let startMonth: Int?
    let endMonth: Int?

    init(startYear: Int, endYear: Int, startMonth: Int? = nil, endMonth: Int? = nil) {
        self.startYear = startYear
        self.endYear = endYear
        self.startMonth = startMonth
        self.endMonth = endMonth
    }

    var displayText: String {
        if let startMonth = startMonth, let endMonth = endMonth {
            return "\(startMonth)/\(startYear) - \(endMonth)/\(endYear)"
        } else {
            return "\(startYear) - \(endYear)"
        }
    }
}

// MARK: - Message Reaction Model
struct MessageReaction: Codable, Identifiable {
    let id: String
    let message: Message
    let user: User
    let reactionType: String
    let createdAt: String
    let createdBy: User?

    enum CodingKeys: String, CodingKey {
        case id
        case message
        case user
        case reactionType = "reaction_type"
        case createdAt = "created_at"
        case createdBy = "created_by"
    }
}

// MARK: - App State Models
enum AppTab {
    case map
    case messages
    case channels
    case profile
}

enum MapMode {
    case view
    case draw
    case select
}

enum MessageFilter {
    case all
    case anonymous
    case withPii
    case restricted
}
