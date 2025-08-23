import XCTest
import CoreLocation
import MapKit
@testable import ThereThen

final class MapViewHelperTests: XCTestCase {
    let epsilon = 1e-6
    let region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0),
        span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 4.0)
    )
    let size = CGSize(width: 100, height: 200)

    func testCenterPointReturnsRegionCenter() {
        let centerPoint = CGPoint(x: size.width / 2, y: size.height / 2)
        let coord = pointToCoordinate(region: region, size: size, point: centerPoint)
        XCTAssertEqual(coord.latitude, region.center.latitude, accuracy: epsilon)
        XCTAssertEqual(coord.longitude, region.center.longitude, accuracy: epsilon)
    }

    func testTopLeftReturnsExpectedCoordinate() {
        let topLeft = CGPoint(x: 0, y: 0)
        let coord = pointToCoordinate(region: region, size: size, point: topLeft)
        let expectedLat = region.center.latitude + region.span.latitudeDelta / 2
        let expectedLon = region.center.longitude - region.span.longitudeDelta / 2
        XCTAssertEqual(coord.latitude, expectedLat, accuracy: epsilon)
        XCTAssertEqual(coord.longitude, expectedLon, accuracy: epsilon)
    }

    func testBottomRightReturnsExpectedCoordinate() {
        let bottomRight = CGPoint(x: size.width, y: size.height)
        let coord = pointToCoordinate(region: region, size: size, point: bottomRight)
        let expectedLat = region.center.latitude - region.span.latitudeDelta / 2
        let expectedLon = region.center.longitude + region.span.longitudeDelta / 2
        XCTAssertEqual(coord.latitude, expectedLat, accuracy: epsilon)
        XCTAssertEqual(coord.longitude, expectedLon, accuracy: epsilon)
    }
}
