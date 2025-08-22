import SwiftUI
import MapKit

// Minimal, isolated iOS 17 Map content using the new Annotation content-builder API.
// This file is availability-gated so it won't affect builds on older SDKs or cause
// overload ambiguity in existing files. It is intentionally small and typed to
// make future migration straightforward.
@available(iOS 17.0, *)
struct MapContent_iOS17: View {
    @Binding var region: MKCoordinateRegion
    var areas: [GeographicArea]

    /// Provide a coordinate for each area. Defaults to (0,0) so this file compiles
    /// even if the caller hasn't wired a real coordinate provider yet.
    var coordinateFor: (GeographicArea) -> CLLocationCoordinate2D = { _ in
        CLLocationCoordinate2D(latitude: 0, longitude: 0)
    }

    var body: some View {
        // Placeholder implementation to keep this iOS17-only file compiling.
        // The real iOS17 Map content using `Annotation` can be added here
        // later in a small, isolated patch to avoid confusing the compiler.
        VStack(spacing: 8) {
            Image(systemName: "map")
                .font(.largeTitle)
            Text("iOS 17 Map placeholder")
                .font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Small preview helper when building with iOS 17 SDKs.
@available(iOS 17.0, *)
struct MapContent_iOS17_Previews: PreviewProvider {
    static var previews: some View {
        // Provide a dummy region and empty areas for preview/build-time checks.
        MapContent_iOS17(region: .constant(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 51.5072, longitude: -0.1276), span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1))), areas: [])
    }
}
