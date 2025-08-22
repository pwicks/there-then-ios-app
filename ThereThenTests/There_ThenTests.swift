//
//  There_ThenTests.swift
//  ThereThenTests
//
//  Created by Paul Wicks on 8/13/25.
//

import XCTest
import Combine
import CoreLocation
@testable import There_Then

final class There_ThenTests: XCTestCase {
    var cancellables = Set<AnyCancellable>()

    struct StubAPIClient: APIClientProtocol {
        func hasValidAuthToken() -> Bool { true }
        func createGeographicArea(name: String?, geometryWkt: String, startYear: Int, endYear: Int, startMonth: Int?, endMonth: Int?, userId: String?) -> AnyPublisher<GeographicArea, Error> {
            let area = GeographicArea(id: UUID().uuidString, name: name, geometryWkt: geometryWkt, startYear: startYear, endYear: endYear, startMonth: startMonth, endMonth: endMonth, createdBy: nil, createdAt: nil)
            return Just(area)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        func getAllAreas() -> AnyPublisher<[GeographicArea], Error> {
            return Just([])
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        func searchAreasByTime(startYear: Int?, endYear: Int?, startMonth: Int?, endMonth: Int?) -> AnyPublisher<[GeographicArea], Error> {
            return Just([])
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
    }

    func testCreateGeographicArea_appendsAreaImmediately() {
        let stub = StubAPIClient()
        let vm = MapViewModel(apiClient: stub)

        // add a drawn rectangle so createGeographicArea has something to use
        let rect = MapRectangle(topLeft: CLLocationCoordinate2D(latitude: 10, longitude: 10), bottomRight: CLLocationCoordinate2D(latitude: 9, longitude: 11))
        vm.drawnRectangles = [rect]

        let expect = expectation(description: "Area appended")
        XCTAssertTrue(vm.allAreas.isEmpty)

        // Observe the published allAreas and fulfill when an area appears
        vm.$allAreas
            .dropFirst()
            .sink { areas in
                if !areas.isEmpty {
                    expect.fulfill()
                }
            }
            .store(in: &cancellables)

        vm.createGeographicArea()

        wait(for: [expect], timeout: 2.0)
        XCTAssertEqual(vm.allAreas.count, 1)
    }
}
