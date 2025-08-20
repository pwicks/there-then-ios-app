//
//  MapView.swift
//  There Then
//
//  Created by Paul Wicks on 8/13/25.
//
import SwiftUI
import MapKit
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject {
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


    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse {
            locationManager.requestLocation()
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        region.center = location.coordinate
    }
}

struct MapView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var mapMode: MapMode = .view
    @State private var allAreas: [GeographicArea] = []
    @State private var drawnRectangles: [MapRectangle] = []
    @State private var showingTimeSelector = false
    @State private var timePeriod = TimePeriod(startYear: 2020, endYear: 2024, startMonth: nil, endMonth: nil)
    @State private var showingAreaDetails = false
    @State private var selectedArea: GeographicArea?
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            ZStack {
                mapSection
                if mapMode == .draw {
                    DrawingOverlay(
                        drawnRectangles: $drawnRectangles,
                        region: locationManager.region,
                        onRectangleComplete: { rectangle in
                            drawnRectangles.append(rectangle)
                        }
                    )
                }
                topControls
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("My Location") {
                        locationManager.requestLocation()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button("Refresh") {
                            loadExistingAreas()
                        }
                        Button("Search") {
                            searchAreas()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingTimeSelector) {
                TimeSelectorView(timePeriod: $timePeriod)
            }
            .sheet(isPresented: $showingAreaDetails) {
                if let area = selectedArea {
                    AreaDetailsView(area: area)
                }
            }
            .onAppear {
                locationManager.requestLocation()
                loadExistingAreas()
            }
        }
    }

    private var mapSection: some View {
        Map(coordinateRegion: $locationManager.region, showsUserLocation: true, annotationItems: allAreas) { area in
            MapAnnotation(coordinate: getAreaCenter(area)) {
                AreaAnnotationView(area: area) {
                    selectedArea = area
                    showingAreaDetails = true
                }
            }
        }
        .ignoresSafeArea()
    }

    private var topControls: some View {
        VStack {
            HStack {
                Spacer()
                modePickerAndTimeSelector
            }
            Spacer()
            if mapMode == .draw {
                bottomControls
            }
            // Show area count
            if !allAreas.isEmpty {
                HStack {
                    Spacer()
                    Text("\(allAreas.count) areas on map")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(8)
                }
                .padding(.bottom)
            }
        }
    }

    private var modePickerAndTimeSelector: some View {
        VStack(spacing: 10) {
            Picker("Map Mode", selection: $mapMode) {
                Image(systemName: "eye").tag(MapMode.view)
                Image(systemName: "pencil").tag(MapMode.draw)
                Image(systemName: "hand.tap").tag(MapMode.select)
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(width: 150)
            .background(Color.white.opacity(0.9))
            .cornerRadius(8)
            Button(action: { showingTimeSelector = true }) {
                HStack {
                    Image(systemName: "clock")
                    Text(timePeriod.displayText)
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.9))
                .cornerRadius(8)
            }
        }
        .padding()
    }

    private var bottomControls: some View {
        HStack {
            Button("Clear All") {
                drawnRectangles.removeAll()
                allAreas.removeAll()
            }
                .buttonStyle(.bordered)
            Spacer()
            Button("Create Area") { createGeographicArea() }
                .buttonStyle(.borderedProminent)
                .disabled(drawnRectangles.isEmpty)
        }
        .padding()
        .background(Color.white.opacity(0.9))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.bottom)
    }

    private func getAreaCenter(_ area: GeographicArea) -> CLLocationCoordinate2D {
        // Try to parse the WKT geometry to get the actual center
        if let geometryWkt = area.geometryWkt {
            // Simple parsing for POLYGON format: POLYGON((lon1 lat1, lon2 lat2, ...))
            let coordinates = parseWKTPolygon(geometryWkt)
            if !coordinates.isEmpty {
                let avgLat = coordinates.map { $0.latitude }.reduce(0, +) / Double(coordinates.count)
                let avgLon = coordinates.map { $0.longitude }.reduce(0, +) / Double(coordinates.count)
                return CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
            }
        }

        // Fallback to default coordinate if parsing fails
        return CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    }

    private func parseWKTPolygon(_ wkt: String) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []

        // Extract coordinates from POLYGON((lon1 lat1, lon2 lat2, ...))
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

        return coordinates
    }

    private func createGeographicArea() {
        guard let rectangle = drawnRectangles.first else { return }

        isLoading = true

        // Convert rectangle to WKT format
        let wkt = "POLYGON((\(rectangle.topLeft.longitude) \(rectangle.topLeft.latitude), \(rectangle.bottomRight.longitude) \(rectangle.topLeft.latitude), \(rectangle.bottomRight.longitude) \(rectangle.bottomRight.latitude), \(rectangle.topLeft.longitude) \(rectangle.bottomRight.latitude), \(rectangle.topLeft.longitude) \(rectangle.topLeft.latitude)))"

        APIClient.shared.createGeographicArea(
            name: "Drawn Area",
            geometryWkt: wkt,
            startYear: timePeriod.startYear,
            endYear: timePeriod.endYear,
            startMonth: timePeriod.startMonth,
            endMonth: timePeriod.endMonth
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completion in
                isLoading = false
                if case .failure(let error) = completion {
                    print("Error creating area: \(error)")
                }
            },
            receiveValue: { area in
                // Add the new area to the map
                allAreas.append(area)
                drawnRectangles.removeAll()
                mapMode = .view

                // Center the map on the new area
                if let geometryWkt = area.geometryWkt {
                    let center = getAreaCenter(area)
                    locationManager.region.center = center
                    locationManager.region.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                }
            }
        )
        .store(in: &cancellables)
    }

    private func searchAreas() {
        isLoading = true

        APIClient.shared.searchAreasByTime(
            startYear: timePeriod.startYear,
            endYear: timePeriod.endYear,
            startMonth: timePeriod.startMonth,
            endMonth: timePeriod.endMonth
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completion in
                isLoading = false
                if case .failure(let error) = completion {
                    print("Error searching areas: \(error)")
                }
            },
            receiveValue: { areas in
                // Add search results to existing areas, avoiding duplicates
                let newAreas = areas.filter { newArea in
                    !allAreas.contains { existingArea in
                        existingArea.id == newArea.id
                    }
                }
                allAreas.append(contentsOf: newAreas)
            }
        )
        .store(in: &cancellables)
    }

    private func loadExistingAreas() {
        isLoading = true

        // Load areas from the server
        APIClient.shared.getAllAreas()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case .failure(let error) = completion {
                        print("Error loading existing areas: \(error)")
                    }
                },
                receiveValue: { areas in
                    allAreas = areas
                }
            )
            .store(in: &cancellables)
    }

    @State private var cancellables = Set<AnyCancellable>()
}

struct DrawingOverlay: View {
    @Binding var drawnRectangles: [MapRectangle]
    let region: MKCoordinateRegion
    let onRectangleComplete: (MapRectangle) -> Void

    @State private var isDrawing = false
    @State private var startPoint: CGPoint?
    @State private var currentPoint: CGPoint?
    @State private var screenRectangles: [CGRect] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.yellow.opacity(0.1) // Debug: overlay background for gesture testing
                ForEach(screenRectangles, id: \ .self) { rect in
                    Rectangle()
                        .stroke(Color.blue, lineWidth: 2)
                        .background(Color.blue.opacity(0.1))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }
                currentDrawingRectangleView(geometry: geometry)
            }
            .gesture(dragGesture(geometry: geometry))
            .ignoresSafeArea() // Ensure overlay covers the map
        }
    }

    private func currentDrawingRectangleView(geometry: GeometryProxy) -> some View {
        Group {
            if isDrawing, let start = startPoint, let current = currentPoint {
                Rectangle()
                    .stroke(Color.red, style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .background(Color.red.opacity(0.1))
                    .frame(width: abs(current.x - start.x), height: abs(current.y - start.y))
                    .position(x: (start.x + current.x) / 2, y: (start.y + current.y) / 2)
            }
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
                DispatchQueue.main.async {
                    if let start = startPoint {
                        let end = value.location
                        let rect = CGRect(
                            x: min(start.x, end.x),
                            y: min(start.y, end.y),
                            width: abs(end.x - start.x),
                            height: abs(end.y - start.y)
                        )
                        screenRectangles.append(rect)
                        func pointToCoordinate(_ point: CGPoint) -> CLLocationCoordinate2D {
                            let lat = region.center.latitude + region.span.latitudeDelta * (0.5 - point.y / geometry.size.height)
                            let lon = region.center.longitude + region.span.longitudeDelta * (point.x / geometry.size.width - 0.5)
                            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        }
                        let topLeft = pointToCoordinate(CGPoint(x: min(start.x, end.x), y: min(start.y, end.y)))
                        let bottomRight = pointToCoordinate(CGPoint(x: max(start.x, end.x), y: max(start.y, end.y)))
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

struct AreaAnnotationView: View {
    let area: GeographicArea
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Image(systemName: "mappin.circle.fill")
                    .font(.title)
                    .foregroundColor(.red)

                Text(area.name ?? "Area")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white)
                    .cornerRadius(4)

                Text("\(area.startYear)-\(area.endYear)")
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.blue.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(3)
            }
        }
    }
}

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
                    timePeriod = TimePeriod(
                        startYear: startYear,
                        endYear: endYear,
                        startMonth: startMonth,
                        endMonth: endMonth
                    )
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

struct AreaDetailsView: View {
    let area: GeographicArea

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
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

                    if let startMonth = area.startMonth, let endMonth = area.endMonth {
                        Text("Months: \(startMonth) - \(endMonth)")
                            .font(.subheadline)
                    }
                }

                Spacer()

                Button("Join Channel") {
                    // Handle joining channel
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

#Preview {
    MapView()
}
