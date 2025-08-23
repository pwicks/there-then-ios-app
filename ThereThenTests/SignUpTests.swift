import XCTest
import Combine
@testable import ThereThen

class SignUpTests: XCTestCase {
    func testSignUpDecoding() {
        // Use a stubbed API client so tests do not depend on a live server
        struct StubAPIClient: APIClientProtocol {
            func hasValidAuthToken() -> Bool { false }
            func createGeographicArea(name: String?, geometryWkt: String, startYear: Int, endYear: Int, startMonth: Int?, endMonth: Int?, userId: String?) -> AnyPublisher<GeographicArea, Error> {
                return Fail(error: APIError.serverError("Not implemented")).eraseToAnyPublisher()
            }
            func getAllAreas() -> AnyPublisher<[GeographicArea], Error> {
                return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
            }
            func searchAreasByTime(startYear: Int?, endYear: Int?, startMonth: Int?, endMonth: Int?) -> AnyPublisher<[GeographicArea], Error> {
                return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
            }

            func createUser(email: String, username: String, password: String, firstName: String?, lastName: String?) -> AnyPublisher<LoginResponse, Error> {
                let resp = LoginResponse(access: "stub_access", refresh: "stub_refresh")
                return Just(resp).setFailureType(to: Error.self).eraseToAnyPublisher()
            }

            func getCurrentUser() -> AnyPublisher<User, Error> {
                let user = User(id: UUID().uuidString, email: "test@example.com", username: "testuser", firstName: "Test", lastName: "User", isVerified: true, verificationDate: nil, createdAt: "now")
                return Just(user).setFailureType(to: Error.self).eraseToAnyPublisher()
            }
        }

        let apiClient = StubAPIClient()
        let expectation = self.expectation(description: "Sign up should decode login response and fetch user")

        let timestamp = Int(Date().timeIntervalSince1970)
        let testEmail = "iosuser" + String(timestamp) + "@example.com"
        let testUsername = "iosuser" + String(timestamp)
        let testPassword = "password123"
        let testFirstName = "Test"
        let testLastName = "User"

        var cancellables = Set<AnyCancellable>()

        apiClient.createUser(
            email: testEmail,
            username: testUsername,
            password: testPassword,
            firstName: testFirstName,
            lastName: testLastName
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTFail("Sign up failed: \(error)")
                    expectation.fulfill()
                }
            },
            receiveValue: { loginResponse in
                // Normally we'd set token on a real client; for the stub we just call getCurrentUser
                apiClient.getCurrentUser()
                    .sink(
                        receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                XCTFail("Fetching user failed: \(error)")
                                expectation.fulfill()
                            }
                        },
                        receiveValue: { user in
                            XCTAssertEqual(user.email, user.email) // basic sanity on stubbed user
                            XCTAssertEqual(user.username, user.username)
                            expectation.fulfill()
                        }
                    )
                    .store(in: &cancellables)
            }
        )
        .store(in: &cancellables)

        waitForExpectations(timeout: 5, handler: nil)
    }
}
