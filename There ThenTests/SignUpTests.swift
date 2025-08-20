import XCTest
@testable import There_Then

class SignUpTests: XCTestCase {
    func testSignUpDecoding() {
        let apiClient = APIClient.shared
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
                apiClient.setAuthToken(loginResponse.access)
                apiClient.getCurrentUser()
                    .sink(
                        receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                XCTFail("Fetching user failed: \(error)")
                                expectation.fulfill()
                            }
                        },
                        receiveValue: { user in
                            XCTAssertEqual(user.email, testEmail)
                            XCTAssertEqual(user.username, testUsername)
                            XCTAssertEqual(user.firstName, testFirstName)
                            XCTAssertEqual(user.lastName, testLastName)
                            expectation.fulfill()
                        }
                    )
                    .store(in: &cancellables)
            }
        )
        .store(in: &cancellables)

        waitForExpectations(timeout: 10, handler: nil)
    }
}
