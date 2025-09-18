import SwiftUI
import MapLibre
import CoreLocation

final class LocationPermissionManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var lastLocation: CLLocation?

    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestWhenInUse() {
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            startUpdates()
        }
    }

    func startUpdates() {
        manager.startUpdatingLocation()
    }

    func stopUpdates() {
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            startUpdates()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
    }
}

struct ContentView: View {
    @StateObject private var locationPermission = LocationPermissionManager()
    @State private var mapZoom: Double = 2.0
    @State private var mapCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    @State private var showDeniedAlert: Bool = false
    @State private var shouldCenterOnNextLocation: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
            MapLibreMapView(
                centerCoordinate: $mapCenter,
                zoomLevel: $mapZoom,
                userLocation: $locationPermission.lastLocation,
                isAuthorized: .constant(locationPermission.authorizationStatus == .authorizedWhenInUse || locationPermission.authorizationStatus == .authorizedAlways)
            )
            .ignoresSafeArea()

            HStack(spacing: 24) {
                Button("–") { mapZoom = max(mapZoom - 1, 1) }
                Button("Найти меня") {
                    if locationPermission.authorizationStatus == .notDetermined {
                        shouldCenterOnNextLocation = true
                        locationPermission.requestWhenInUse()
                    } else if let loc = locationPermission.lastLocation {
                        mapCenter = loc.coordinate
                    } else if locationPermission.authorizationStatus == .denied || locationPermission.authorizationStatus == .restricted {
                        showDeniedAlert = true
                    } else {
                        shouldCenterOnNextLocation = true
                        locationPermission.startUpdates()
                    }
                }
                Button("+") { mapZoom = min(mapZoom + 1, 20) }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(.bottom, 24)
            .alert("Доступ к геолокации отключён", isPresented: $showDeniedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Разрешите доступ в Настройках, чтобы центрировать карту по вам.")
            }
        }
        .onChange(of: locationPermission.lastLocation) { newValue in
            if shouldCenterOnNextLocation, let loc = newValue {
                mapCenter = loc.coordinate
                shouldCenterOnNextLocation = false
            }
        }
    }
}

struct MapLibreMapView: UIViewRepresentable {
    @Binding var centerCoordinate: CLLocationCoordinate2D
    @Binding var zoomLevel: Double
    @Binding var userLocation: CLLocation?
    @Binding var isAuthorized: Bool

    func makeUIView(context: Context) -> MLNMapView {
        let styleURL = Bundle.main.url(forResource: "osm_style", withExtension: "json")
        let view: MLNMapView
        if let url = styleURL {
            view = MLNMapView(frame: .zero, styleURL: url)
        } else {
            view = MLNMapView(frame: .zero)
        }
        view.setCenter(centerCoordinate, zoomLevel: zoomLevel, animated: false)
        view.showsUserLocation = false
        // Отключаем жесты масштабирования (pinch, double-tap)
        DispatchQueue.main.async {
            view.gestureRecognizers?.forEach { gr in
                if gr is UIPinchGestureRecognizer {
                    gr.isEnabled = false
                }
                if let tap = gr as? UITapGestureRecognizer, tap.numberOfTapsRequired == 2 {
                    tap.isEnabled = false
                }
            }
        }
        return view
    }

    func updateUIView(_ uiView: MLNMapView, context: Context) {
        uiView.setCenter(centerCoordinate, zoomLevel: zoomLevel, animated: true)
        uiView.showsUserLocation = isAuthorized
    }
}

