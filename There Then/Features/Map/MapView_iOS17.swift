import SwiftUI
import MapKit

// iOS-17-only map wrapper (availability gated). Implemented with an MKMapView
// UIViewRepresentable to avoid SwiftUI Map overload/typechecking issues while we
// iteratively migrate to the new content-builder API.
@available(iOS 17.0, *)
struct MapContent_iOS17: View {
    @Binding var region: MKCoordinateRegion
    var areas: [GeographicArea]

    /// Provide a coordinate for each area. Caller should pass a real provider.
    var coordinateFor: (GeographicArea) -> CLLocationCoordinate2D = { _ in
        CLLocationCoordinate2D(latitude: 0, longitude: 0)
    }

    var body: some View {
        MKMapViewRepresentable(region: $region, areas: areas, coordinateFor: coordinateFor)
            .edgesIgnoringSafeArea(.all)
    }
}

@available(iOS 17.0, *)
private struct MKMapViewRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var areas: [GeographicArea]
    var coordinateFor: (GeographicArea) -> CLLocationCoordinate2D

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.showsCompass = true
        map.showsUserLocation = true
        map.setRegion(region, animated: false)
        return map
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Keep region in sync
        uiView.setRegion(region, animated: false)

        // Build a set of IDs we currently have on the map
        let existing = uiView.annotations.compactMap { $0 as? AreaAnnotation }
        let existingIds = Set(existing.map { $0.id })
        let newIds = Set(areas.map { $0.id })

        // Remove annotations that no longer exist
        for ann in existing where !newIds.contains(ann.id) {
            uiView.removeAnnotation(ann)
        }

        // Add new annotations
        for area in areas where !existingIds.contains(area.id) {
            let coord = coordinateFor(area)
            let ann = AreaAnnotation(id: area.id, coordinate: coord, title: area.name)
            uiView.addAnnotation(ann)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MKMapViewRepresentable
        init(_ parent: MKMapViewRepresentable) { self.parent = parent }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // only handle our AreaAnnotation instances
            guard annotation is AreaAnnotation else { return nil }
            let id = "area-annotation"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
            if view == nil {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
                view?.canShowCallout = true
                view?.markerTintColor = .systemRed
                view?.glyphImage = UIImage(systemName: "mappin")
            } else {
                view?.annotation = annotation
            }
            view?.clusteringIdentifier = "area"
            return view
        }
    }
}

@available(iOS 17.0, *)
private final class AreaAnnotation: NSObject, MKAnnotation {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String?

    init(id: String, coordinate: CLLocationCoordinate2D, title: String?) {
        self.id = id
        self.coordinate = coordinate
        self.title = title
        super.init()
    }
}

@available(iOS 17.0, *)
struct MapContent_iOS17_Previews: PreviewProvider {
    static var previews: some View {
        MapContent_iOS17(region: .constant(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 51.5072, longitude: -0.1276), span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5))), areas: [], coordinateFor: { _ in CLLocationCoordinate2D(latitude: 51.5072, longitude: -0.1276) })
    }
}
