import SwiftUI
import MapKit

struct LocationMapView: View {
    @EnvironmentObject var locationManager: LocationManager
    
    // Kaaba Coordinates
    let kaabaCoordinate = CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262)
    
    @State private var position: MapCameraPosition = .automatic
    @State private var mapRotation: Double = 0
    @State private var centeredKey: Int = 0 // Key to force re-center
    
    // Manual Selection
    @State private var cameraCenter: CLLocationCoordinate2D?
    @State private var isManuallyMoving = false
    
    // Search & Styles
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var mapStyle: MapStyleSelection = .imagery
    
    enum MapStyleSelection: String, CaseIterable {
        case standard = "Standard"
        case imagery = "Satellite"
        case hybrid = "Hybrid"
        
        var style: MapStyle {
            switch self {
            case .standard: return .standard
            case .imagery: return .imagery(elevation: .realistic)
            case .hybrid: return .hybrid(elevation: .realistic)
            }
        }
    }
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                let size = geometry.size
                let diagonal = sqrt(size.width * size.width + size.height * size.height)
                
                Map(position: $position, interactionModes: [.all]) {
                    if let userLoc = locationManager.location?.coordinate {
                        Marker("Current Context", coordinate: userLoc)
                            .tint(locationManager.isUsingManualLocation ? .orange : .blue)
                        
                        Marker("Kaaba", coordinate: kaabaCoordinate)
                        
                        MapPolyline(coordinates: [userLoc, kaabaCoordinate], contourStyle: .geodesic)
                            .stroke(locationManager.isUsingManualLocation ? .orange : .blue, lineWidth: 3)
                    }
                }
                .mapStyle(mapStyle.style)
                .frame(width: diagonal, height: diagonal) // Oversize to cover corners when rotated
                .position(x: size.width / 2, y: size.height / 2)
                .onMapCameraChange(frequency: .continuous) { context in
                    self.cameraCenter = context.region.center
                    self.isManuallyMoving = true
                }
                .rotationEffect(.degrees(-mapRotation))
            }
            .ignoresSafeArea()
            
            .ignoresSafeArea()
            .onReceive(locationManager.$heading) { heading in
                if !locationManager.isUsingManualLocation, let trueHeading = heading?.trueHeading {
                    withAnimation(.linear(duration: 0.1)) {
                        self.mapRotation = trueHeading
                    }
                }
            }
            
            // Search Bar Overlay
            VStack {
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search for a place...", text: $searchText)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            .onSubmit { performSearch() }
                    }
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .shadow(radius: 2)
                    
                    if !searchText.isEmpty {
                        Button("Cancel") {
                            searchText = ""
                            searchResults = []
                            isSearching = false
                        }
                        .padding(.leading, 5)
                    }
                }
                .padding()
                
                if isSearching && !searchResults.isEmpty {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(searchResults, id: \.self) { item in
                                Button(action: { selectResult(item) }) {
                                    VStack(alignment: .leading) {
                                        Text(item.name ?? "Unknown Place")
                                            .font(.headline)
                                        Text(item.placemark.title ?? "")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(.ultraThinMaterial)
                                }
                                Divider()
                            }
                        }
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .frame(maxHeight: 300)
                    }
                }
                
                Spacer()
                
                // Style Picker
                Picker("Map Style", selection: $mapStyle) {
                    ForEach(MapStyleSelection.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                .padding()
                
                if locationManager.isUsingManualLocation {
                    Button(action: {
                        locationManager.resetToGPS()
                        withAnimation {
                            position = .userLocation(fallback: .automatic)
                            mapRotation = 0
                            isManuallyMoving = false
                        }
                    }) {
                        HStack {
                            Image(systemName: "location.fill")
                            Text("Reset to GPS")
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .foregroundColor(.blue)
                    }
                    .padding(.bottom, 20)
                } else if isManuallyMoving {
                    Button(action: {
                        if let center = cameraCenter {
                            let newLoc = CLLocation(latitude: center.latitude, longitude: center.longitude)
                            locationManager.setManualLocation(newLoc)
                            mapRotation = 0 
                        }
                    }) {
                        HStack {
                            Image(systemName: "hand.tap.fill")
                            Text("Set Location Here")
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .foregroundColor(.orange)
                    }
                    .padding(.bottom, 20)
                }
            }
            
            // Center Pin Overlay for selection
            if isManuallyMoving && !isSearching {
                Image(systemName: "mappin")
                    .font(.largeTitle)
                    .foregroundColor(.red)
                    .shadow(radius: 2)
                    .offset(y: -20)
            }
        }
        .navigationTitle("Location")
        .safeAreaInset(edge: .bottom) {
            if let userLoc = locationManager.location {
                let distance = userLoc.distance(from: CLLocation(latitude: kaabaCoordinate.latitude, longitude: kaabaCoordinate.longitude))
                VStack {
                    Text("Distance to Kaaba")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(distance / 1000)) km")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(10)
                .padding()
            }
        }
        .onAppear {
            if let userLoc = locationManager.location?.coordinate {
                // Default to a closer zoom (1000m altitude/distance) on load
                position = .camera(MapCamera(centerCoordinate: userLoc, distance: 1000))
            }
            locationManager.startHeadingUpdates()
        }
        .onDisappear {
            locationManager.stopHeadingUpdates()
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let response = response else { return }
            self.searchResults = response.mapItems
        }
    }
    
    private func selectResult(_ item: MKMapItem) {
        let coord = item.placemark.coordinate
        let newLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        locationManager.setManualLocation(newLoc)
        
        withAnimation {
            position = .camera(MapCamera(centerCoordinate: coord, distance: 5000))
            isManuallyMoving = false
            isSearching = false
            searchText = ""
            searchResults = []
        }
    }
}
