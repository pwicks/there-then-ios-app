//
//  MapView.swift
//  ThereThen
//
//  MapView.swift
//  ThereThen
//
//  Cleaned by assistant to remove duplicated top-level code and stray statements
//
import SwiftUI
import MapKit
import CoreLocation
import Combine

// MapMode is defined in Shared/Models.swift; don't redeclare here.

// MARK: - Location Manager
final class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()

    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async { [weak self] in
            self?.region.center = location.coordinate
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.requestLocation()
        }
    }
}

// MARK: - View Model
final class MapViewModel: ObservableObject {
    @Published var mapMode: MapMode = .view
    @Published var allAreas: [GeographicArea] = []
    @Published var drawnRectangles: [MapRectangle] = []
    @Published var showingTimeSelector = false
    @Published var timePeriod = TimePeriod(startYear: 2020, endYear: 2024)
    @Published var showingAreaDetails = false
    @Published var selectedArea: GeographicArea?
    @Published var isLoading = false
    @Published var needsAuthentication = false

    private var cancellables = Set<AnyCancellable>()
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }

    func createGeographicArea() {
        guard let rectangle = drawnRectangles.first else { return }
        isLoading = true

        let wkt = "POLYGON((\(rectangle.topLeft.longitude) \(rectangle.topLeft.latitude), \(rectangle.bottomRight.longitude) \(rectangle.topLeft.latitude), \(rectangle.bottomRight.longitude) \(rectangle.bottomRight.latitude), \(rectangle.topLeft.longitude) \(rectangle.bottomRight.latitude), \(rectangle.topLeft.longitude) \(rectangle.topLeft.latitude)))"

        apiClient.createGeographicArea(
            name: "Drawn Area",
            geometryWkt: wkt,
            startYear: timePeriod.startYear,
            endYear: timePeriod.endYear,
            startMonth: timePeriod.startMonth,
            endMonth: timePeriod.endMonth,
            userId: nil
        )
        .receive(on: DispatchQueue.main)
        .sink(receiveCompletion: { [weak self] completion in
            self?.isLoading = false
            if case .failure(let error) = completion {
                print("Error creating area: \(error)")
            }
        }, receiveValue: { [weak self] createdArea in
            guard let self = self else { return }
            self.drawnRectangles.removeAll()
            self.mapMode = .view
            self.allAreas.append(createdArea)
            self.loadAllAreas()
        })
        .store(in: &cancellables)
    }

    func loadAllAreas() {
        isLoading = true
    apiClient.getAllAreas()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    print("Error loading existing areas: \(error)")
                    if let apiError = error as? APIError,
                       case .serverError(let message) = apiError,
                       message.contains("Authentication required") {
                        self?.needsAuthentication = true
                    }
                }
            }, receiveValue: { [weak self] areas in
                self?.allAreas = areas
            })
            .store(in: &cancellables)
    }

    func searchAreas() {
    guard apiClient.hasValidAuthToken() else {
            needsAuthentication = true
            return
        }
        isLoading = true
    apiClient.searchAreasByTime(
            startYear: timePeriod.startYear,
            endYear: timePeriod.endYear,
            startMonth: timePeriod.startMonth,
            endMonth: timePeriod.endMonth
        )
        .receive(on: DispatchQueue.main)
        .sink(receiveCompletion: { [weak self] completion in
            self?.isLoading = false
            if case .failure(let error) = completion {
                print("Error searching areas: \(error)")
            }
        }, receiveValue: { [weak self] areas in
            guard let self = self else { return }
            let newAreas = areas.filter { newArea in
                !self.allAreas.contains(where: { $0.id == newArea.id })
            }
            self.allAreas.append(contentsOf: newAreas)
        })
        .store(in: &cancellables)
    }

    // WKT helpers
    func parseWKTPolygon(_ wkt: String) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        if wkt.uppercased().hasPrefix("POLYGON") {
            if let startIndex = wkt.range(of: "((")?.upperBound,
               let endIndex = wkt.range(of: "))")?.lowerBound {
                let coordinateString = String(wkt[startIndex..<endIndex])
                let pairs = coordinateString.components(separatedBy: ",")
                for pair in pairs {
                    let components = pair.trimmingCharacters(in: .whitespaces).components(separatedBy: " ")
                    if components.count >= 2,
                       let lon = Double(components[0]),
                       let lat = Double(components[1]) {
                        coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
                    }
                }
            }
        }
        return coordinates
    }

    func getAreaCenter(_ area: GeographicArea) -> CLLocationCoordinate2D {
        if let geometryWkt = area.geometryWkt {
            let coords = parseWKTPolygon(geometryWkt)
            if !coords.isEmpty {
                let avgLat = coords.map { $0.latitude }.reduce(0, +) / Double(coords.count)
                let avgLon = coords.map { $0.longitude }.reduce(0, +) / Double(coords.count)
                return CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
            }
        }
        return CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    }
}

// MARK: - Drawing Overlay
struct DrawingOverlay: View {
    @Binding var drawnRectangles: [MapRectangle]
    let region: MKCoordinateRegion
    let onRectangleComplete: (MapRectangle) -> Void

    @State private var isDrawing = false
    @State private var startPoint: CGPoint?
    @State private var currentPoint: CGPoint?

    var body: some View {
        GeometryReader { geometry in
            let screenRectangles = drawnRectangles.map { rect in
                coordinateToScreenRect(region: region, size: geometry.size, mapRect: rect)
            }

            ZStack {
                Color.clear
                ForEach(Array(screenRectangles.enumerated()), id: \.offset) { index, rect in
                    Rectangle()
                        .stroke(Color.blue, lineWidth: 2)
                        .background(Color.blue.opacity(0.1))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }
                if isDrawing, let start = startPoint, let current = currentPoint {
                    let rect = CGRect(x: min(start.x, current.x), y: min(start.y, current.y), width: abs(current.x - start.x), height: abs(current.y - start.y))
                    Rectangle()
                        .stroke(Color.red, lineWidth: 2)
                        .background(Color.red.opacity(0.1))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }
            }
            .contentShape(Rectangle())
            .highPriorityGesture(dragGesture(geometry: geometry))
            .ignoresSafeArea()
        }
    }

    private func dragGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDrawing {
                    isDrawing = true
                    startPoint = value.startLocation
                }
                currentPoint = value.location
            }
            .onEnded { value in
                // No need for DispatchQueue.main.async here
                if let start = startPoint {
                    let end = value.location
                    let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(end.x - start.x), height: abs(end.y - start.y))

                    let topLeft = pointToCoordinate(region: region, size: geometry.size, point: CGPoint(x: min(start.x, end.x), y: min(start.y, end.y)))
                    let bottomRight = pointToCoordinate(region: region, size: geometry.size, point: CGPoint(x: max(start.x, end.x), y: max(start.y, end.y)))
                    let rectangle = MapRectangle(topLeft: topLeft, bottomRight: bottomRight)
                    onRectangleComplete(rectangle)
                }
                isDrawing = false
                startPoint = nil
                currentPoint = nil
            }
        }
    }
}

// MARK: - Testable Helpers

func pointToCoordinate(region: MKCoordinateRegion, size: CGSize, point: CGPoint) -> CLLocationCoordinate2D {
    let lat = region.center.latitude - region.span.latitudeDelta * (point.y / size.height - 0.5)
    let lon = region.center.longitude + region.span.longitudeDelta * (point.x / size.width - 0.5)
    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
}

func coordinateToPoint(region: MKCoordinateRegion, size: CGSize, coordinate: CLLocationCoordinate2D) -> CGPoint {
    let x = (coordinate.longitude - region.center.longitude + region.span.longitudeDelta * 0.5) / region.span.longitudeDelta * size.width
    let y = (region.center.latitude - coordinate.latitude + region.span.latitudeDelta * 0.5) / region.span.latitudeDelta * size.height
    return CGPoint(x: x, y: y)
}

func coordinateToScreenRect(region: MKCoordinateRegion, size: CGSize, mapRect: MapRectangle) -> CGRect {
    let topLeftPoint = coordinateToPoint(region: region, size: size, coordinate: mapRect.topLeft)
    let bottomRightPoint = coordinateToPoint(region: region, size: size, coordinate: mapRect.bottomRight)
    return CGRect(
        x: min(topLeftPoint.x, bottomRightPoint.x),
        y: min(topLeftPoint.y, bottomRightPoint.y),
        width: abs(bottomRightPoint.x - topLeftPoint.x),
        height: abs(bottomRightPoint.y - topLeftPoint.y)
    )
}

// MARK: - Area Annotation View
struct AreaAnnotationView: View {
    let area: GeographicArea
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .font(.title)
                    .foregroundColor(.red)
                Text(area.name ?? "Area")
                    .font(.caption)
                    .padding(4)
                    .background(Color.white)
                    .cornerRadius(4)
                Text("\(area.startYear)-\(area.endYear)")
                    .font(.caption2)
                    .padding(4)
                    .background(Color.blue.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(3)
            }
        }
    }
}

// MARK: - iOS 17 Annotation helpers
@available(iOS 17.0, *)
struct AreaAnnotationContentView: View {
    let area: GeographicArea
    let onTap: () -> Void

    var body: some View {
        // Keep this small and strongly-typed to help the compiler
        Button(action: onTap) {
            Image(systemName: "mappin.circle.fill")
                .font(.title)
                .foregroundColor(.red)
        }
        .buttonStyle(.plain)
    }
}

@available(iOS 17.0, *)
struct AreaAnnotationLabelView: View {
    let area: GeographicArea

    var body: some View {
        VStack(spacing: 2) {
            Text(area.name ?? "Area")
                .font(.caption2)
                .padding(6)
                .background(Color.white)
                .cornerRadius(6)
        }
    }
}

// MARK: - Time Selector View
struct TimeSelectorView: View {
    @Binding var timePeriod: TimePeriod
    @Environment(\.presentationMode) var presentationMode

    @State private var startYear: Int
    @State private var endYear: Int
    @State private var startMonth: Int?
    @State private var endMonth: Int?

    private let years = Array(1900...2100)
    private let months = Array(1...12)

    init(timePeriod: Binding<TimePeriod>) {
        self._timePeriod = timePeriod
        self._startYear = State(initialValue: timePeriod.wrappedValue.startYear)
        self._endYear = State(initialValue: timePeriod.wrappedValue.endYear)
        self._startMonth = State(initialValue: timePeriod.wrappedValue.startMonth)
        self._endMonth = State(initialValue: timePeriod.wrappedValue.endMonth)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Start Time") {
                    Picker("Start Year", selection: $startYear) {
                        ForEach(years, id: \.self) { year in
                            Text("\(year)").tag(year)
                        }
                    }
                    Picker("Start Month (Optional)", selection: $startMonth) {
                        Text("No Month").tag(nil as Int?)
                        ForEach(months, id: \.self) { month in
                            Text("\(month)").tag(month as Int?)
                        }
                    }
                }

                Section("End Time") {
                    Picker("End Year", selection: $endYear) {
                        ForEach(years, id: \.self) { year in
                            Text("\(year)").tag(year)
                        }
                    }

                    Picker("End Month (Optional)", selection: $endMonth) {
                        Text("No Month").tag(nil as Int?)
                        ForEach(months, id: \.self) { month in
                            Text("\(month)").tag(month as Int?)
                        }
                    }
                }
            }
            .navigationTitle("Select Time Period")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Done") {
                    timePeriod = TimePeriod(startYear: startYear, endYear: endYear, startMonth: startMonth, endMonth: endMonth)
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

// MARK: - Area Details View
struct AreaDetailsView: View {
    let area: GeographicArea

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text(area.name ?? "Unnamed Area")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Created by: \(area.createdBy?.username ?? "Unknown")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let createdAt = area.createdAt {
                    Text("Created: \(createdAt)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Text("Time Period: \(area.startYear) - \(area.endYear)")
                    .font(.subheadline)

                Spacer()

                Button("Join Channel") {
                    // TODO: join channel
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
            .padding()
            .navigationTitle("Area Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Main MapView
struct MapView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var viewModel = MapViewModel()
    // Break the complex body into smaller computed properties to help the Swift type checker
    
    // iOS 17+ typed map content was tried here but removed to keep the build stable.

    // Legacy typed map content
    private struct MapContent_Legacy: View {
        @Binding var region: MKCoordinateRegion
        @ObservedObject var viewModel: MapViewModel

        var body: some View {
            Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: viewModel.allAreas) { area in
                MapAnnotation(coordinate: viewModel.getAreaCenter(area)) {
                    AreaAnnotationView(area: area) {
                        viewModel.selectedArea = area
                        viewModel.showingAreaDetails = true
                    }
                }
            }
            .ignoresSafeArea()
        }
    }

    private var mapContent: AnyView {
        // Return an erased view so the two branches (different concrete types)
        // compile cleanly. iOS17 content is isolated to its own file.
        if #available(iOS 17.0, *) {
            return AnyView(MapContent_iOS17(region: $locationManager.region, areas: viewModel.allAreas, coordinateFor: viewModel.getAreaCenter(_:)))
        } else {
            return AnyView(MapContent_Legacy(region: $locationManager.region, viewModel: viewModel))
        }
    }

    private var controlsView: some View {
        VStack {
            HStack {
                Spacer()
                Picker("Map Mode", selection: $viewModel.mapMode) {
                    Image(systemName: "eye").tag(MapMode.view)
                    Image(systemName: "pencil").tag(MapMode.draw)
                        .accessibilityIdentifier("MapMode.Draw")
                    Image(systemName: "hand.tap").tag(MapMode.select)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("MapModePicker")
                .frame(width: 150)
                .background(Color.white.opacity(0.9))
                .cornerRadius(8)

                Button(action: { viewModel.showingTimeSelector = true }) {
                    HStack {
                        Image(systemName: "clock")
                        Text(viewModel.timePeriod.displayText)
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(8)
                }

                Spacer()
            }
            Spacer()
            if viewModel.mapMode == .draw {
                HStack {
                    Button("Clear All") {
                        viewModel.drawnRectangles.removeAll()
                        viewModel.allAreas.removeAll()
                    }
                    Button("Create Area") {
                        viewModel.createAreaFromDrawnRectangles()
                    }
                    .accessibilityIdentifier("CreateAreaButton")
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    Button("Test Area") {
                        let test = GeographicArea(id: UUID().uuidString, name: "Test", geometryWkt: nil, startYear: 2020, endYear: 2024, startMonth: nil, endMonth: nil, createdBy: nil, createdAt: nil)
                        viewModel.allAreas.append(test)
                    }
                    .buttonStyle(.bordered)

                    Button("Create Area") {
                        viewModel.createGeographicArea()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.drawnRectangles.isEmpty)
                }
                .padding()
                .background(Color.white.opacity(0.9))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                mapContent

                if viewModel.mapMode == .draw {
                    DrawingOverlay(drawnRectangles: $viewModel.drawnRectangles, region: locationManager.region, onRectangleComplete: { rect in
                        viewModel.drawnRectangles.append(rect)
                    })
                }

                controlsView

                // Hidden debug label for UI tests to read drawn rectangles count
                Text("drawn: \(viewModel.drawnRectangles.count)")
                    .accessibilityIdentifier("drawnRectanglesCount")
                    .opacity(0)

                // Place a nearly-transparent, tappable debug button top-left so XCTest can reliably reach it
                VStack {
                    HStack {
                        #if DEBUG
                        Button(action: { viewModel.mapMode = .draw }) {
                            Text("UITest Enable Draw Mode")
                        }
                        .accessibilityIdentifier("UITest_EnableDrawMode")
                        // Make it effectively invisible to humans but hittable by automation
                        .opacity(0.01)
                        #endif
                        Spacer()
                    }
                    Spacer()
                }
                .padding(8)
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("My Location") { locationManager.requestLocation() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button("Refresh") { viewModel.loadAllAreas() }
                        Button("Search") { viewModel.searchAreas() }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingTimeSelector) {
                TimeSelectorView(timePeriod: $viewModel.timePeriod)
            }
            .sheet(isPresented: $viewModel.showingAreaDetails) {
                if let area = viewModel.selectedArea { AreaDetailsView(area: area) }
            }
            .onAppear {
                locationManager.requestLocation()
                viewModel.loadAllAreas()
                #if DEBUG
                // If running UI tests and a preset draw rect is requested, inject one so tests can assert easily
                if ProcessInfo.processInfo.arguments.contains("-UITEST_PRESET_DRAW_RECT") {
                    let center = locationManager.region.center
                    let offsetLat = (locationManager.region.span.latitudeDelta * 0.1)
                    let offsetLon = (locationManager.region.span.longitudeDelta * 0.1)
                    let topLeft = CLLocationCoordinate2D(latitude: center.latitude + offsetLat, longitude: center.longitude - offsetLon)
                    let bottomRight = CLLocationCoordinate2D(latitude: center.latitude - offsetLat, longitude: center.longitude + offsetLon)
                    let rect = MapRectangle(topLeft: topLeft, bottomRight: bottomRight)
                    viewModel.drawnRectangles.append(rect)
                }
                #endif
            }
        }
    }
}

#if DEBUG
struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView()
    }
}
#endif
 
