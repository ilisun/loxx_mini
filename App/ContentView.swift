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
    @State private var showVectorErrorAlert: Bool = false
    @State private var isFollowingUser: Bool = false

    enum MapMode: String, Hashable {
        case raster
        case vectorFlat
        case vector3d
    }

    @State private var mapMode: MapMode = .raster

    var body: some View {
        ZStack(alignment: .bottom) {
            MapLibreMapView(
                centerCoordinate: $mapCenter,
                zoomLevel: $mapZoom,
                userLocation: $locationPermission.lastLocation,
                isAuthorized: .constant(locationPermission.authorizationStatus == .authorizedWhenInUse || locationPermission.authorizationStatus == .authorizedAlways),
                isVectorStyle: mapMode != .raster,
                isThreeD: mapMode == .vector3d,
                isFollowingUser: $isFollowingUser
            )
            .ignoresSafeArea()
            .id(mapMode)

            HStack(spacing: 24) {
                Button("–") { mapZoom = max(mapZoom - 1, 1) }
                Button("Следить") {
                    // Тоггл режима слежения
                    if isFollowingUser {
                        isFollowingUser = false
                        shouldCenterOnNextLocation = false
                        locationPermission.stopUpdates()
                    } else {
                    if locationPermission.authorizationStatus == .notDetermined {
                        shouldCenterOnNextLocation = true
                        locationPermission.requestWhenInUse()
                    } else if locationPermission.authorizationStatus == .denied || locationPermission.authorizationStatus == .restricted {
                        showDeniedAlert = true
                    } else {
                            isFollowingUser = true
                        shouldCenterOnNextLocation = true
                        locationPermission.startUpdates()
                            if let loc = locationPermission.lastLocation {
                                mapCenter = loc.coordinate
                            }
                    }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isFollowingUser ? Color.accentColor : Color.clear)
                .foregroundStyle(isFollowingUser ? Color.white : Color.primary)
                .clipShape(Capsule())
                Button("+") { mapZoom = min(mapZoom + 1, 20) }
                // Режимы: R (растровый), V (вектор плоский), V3d (вектор 3D)
                Button("R") { mapMode = .raster }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(mapMode == .raster ? Color.accentColor : Color.clear)
                .foregroundStyle(mapMode == .raster ? Color.white : Color.primary)
                .clipShape(Capsule())
                Button("V") {
                    if let urlString = Bundle.main.object(forInfoDictionaryKey: "LibertyStyleURL") as? String,
                       let _ = URL(string: urlString), !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        mapMode = .vectorFlat
                    } else {
                        showVectorErrorAlert = true
                        mapMode = .raster
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(mapMode == .vectorFlat ? Color.accentColor : Color.clear)
                .foregroundStyle(mapMode == .vectorFlat ? Color.white : Color.primary)
                .clipShape(Capsule())
                Button("V3d") {
                    if let urlString = Bundle.main.object(forInfoDictionaryKey: "LibertyStyleURL") as? String,
                       let _ = URL(string: urlString), !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        mapMode = .vector3d
                    } else {
                        showVectorErrorAlert = true
                        mapMode = .raster
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(mapMode == .vector3d ? Color.accentColor : Color.clear)
                .foregroundStyle(mapMode == .vector3d ? Color.white : Color.primary)
                .clipShape(Capsule())
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
            .alert("Невозможно загрузить векторный стиль", isPresented: $showVectorErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Проверьте LibertyStyleURL в Info.plist и соединение с интернетом.")
            }

            VStack {
                Spacer()
                HStack {
                    Text("© OpenFreeMap / OpenMapTiles / OSM contributors")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    Spacer()
                }
                .padding(.leading, 12)
                .padding(.bottom, 72)
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
    var isVectorStyle: Bool
    var isThreeD: Bool
    @Binding var isFollowingUser: Bool

    func makeUIView(context: Context) -> MLNMapView {
        let view: MLNMapView
        if isVectorStyle,
           let styleURLString = Bundle.main.object(forInfoDictionaryKey: "LibertyStyleURL") as? String,
           let styleURL = URL(string: styleURLString), !styleURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            view = MLNMapView(frame: .zero, styleURL: styleURL)
        } else if let rasterURL = Bundle.main.url(forResource: "osm_style", withExtension: "json") {
            view = MLNMapView(frame: .zero, styleURL: rasterURL)
        } else {
            view = MLNMapView(frame: .zero)
        }
        view.delegate = context.coordinator
        view.setCenter(centerCoordinate, zoomLevel: zoomLevel, animated: false)
        // Поворачиваем камеру для видимой 3D-экструзии в векторном режиме
        if isVectorStyle && isThreeD {
            let cam = view.camera
            cam.pitch = 45
            view.setCamera(cam, animated: false)
        }
        // Разрешаем наклон (на случай ручного жеста и корректной отрисовки)
        view.allowsTilting = true
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
        // Обновляем наклон камеры в зависимости от режима
        let cam = uiView.camera
        let targetPitch: CGFloat = (isVectorStyle && isThreeD) ? 45 : 0
        if cam.pitch != targetPitch {
            cam.pitch = targetPitch
            uiView.setCamera(cam, animated: true)
        }
        // Если идёт пользовательский жест, не навязываем никаких изменений
        if !isFollowingUser, context.coordinator.isUserGestureActive {
            uiView.showsUserLocation = isAuthorized
            return
        }
        // Если слежение выключено — не навязываем центр, только зум при неизменном центре
        if isFollowingUser {
            uiView.setCenter(centerCoordinate, zoomLevel: zoomLevel, animated: true)
        } else {
            let currentCenter = uiView.centerCoordinate
            let centerChanged = abs(currentCenter.latitude - centerCoordinate.latitude) > 1e-6 || abs(currentCenter.longitude - centerCoordinate.longitude) > 1e-6
            if centerChanged {
                // Центр обновили внешне (например, кнопкой режимов) — применим
                uiView.setCenter(centerCoordinate, zoomLevel: zoomLevel, animated: true)
            } else if fabs(uiView.zoomLevel - zoomLevel) > 1e-3 {
                // Только зум — оставляем текущий центр экрана
                uiView.setZoomLevel(zoomLevel, animated: true)
            }
        }
        uiView.showsUserLocation = isAuthorized
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, MLNMapViewDelegate {
        private let parent: MapLibreMapView
        var isUserGestureActive: Bool = false

        init(_ parent: MapLibreMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MLNMapView, regionWillChangeAnimated animated: Bool) {
            isUserGestureActive = true
        }

        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            // Синхронизируем биндинги фактическим положением карты
            parent.centerCoordinate = mapView.centerCoordinate
            parent.zoomLevel = mapView.zoomLevel
            isUserGestureActive = false
        }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            guard parent.isVectorStyle else { return }
            // Проверяем наличие нужного векторного источника из Liberty
            guard let vectorSource = style.source(withIdentifier: "openmaptiles") as? MLNVectorTileSource else { return }

            // Локализация подписей: предпочитаем name:ru, иначе name
            localizeLabelsToRussian(style: style)

            // Если в стиле уже есть слой building-3d, полагаемся на него
            if !parent.isThreeD {
                // В плоском режиме ещё и гарантируем нулевой pitch
                if mapView.camera.pitch != 0 {
                    let camera = mapView.camera
                    camera.pitch = 0
                    mapView.setCamera(camera, animated: true)
                }
                return
            }
            if style.layer(withIdentifier: "building-3d") != nil {
                // Устанавливаем наклон камеры для видимости 3D, даже если слой есть в стиле
                let camera = mapView.camera
                if camera.pitch != 45 {
                    camera.pitch = 45
                    mapView.setCamera(camera, animated: true)
                }
                return
            }

            // Создаём 3D-экструзию для зданий (аналогично стилю Liberty)
            let layerId = "building-3d-custom"
            let extrude = MLNFillExtrusionStyleLayer(identifier: layerId, source: vectorSource)
            extrude.sourceLayerIdentifier = "building"
            extrude.minimumZoomLevel = 14
            extrude.fillExtrusionOpacity = NSExpression(forConstantValue: 0.8)
            // hsl(35,8%,85%) ≈ тёплый светло‑серый
            extrude.fillExtrusionColor = NSExpression(forConstantValue: UIColor(hue: 35.0/360.0, saturation: 0.08, brightness: 0.85, alpha: 1.0))
            // Используем вычисленные атрибуты стиля Liberty
            extrude.fillExtrusionHeight = NSExpression(mglJSONObject: ["get", "render_height"])
            extrude.fillExtrusionBase = NSExpression(mglJSONObject: ["get", "render_min_height"])

            // Вставляем слой над другими строительными полигонами (если есть), иначе в конец
            if let labelLayer = style.layers.reversed().first(where: { $0 is MLNSymbolStyleLayer }) {
                style.insertLayer(extrude, below: labelLayer)
            } else {
                style.addLayer(extrude)
            }

            // Гарантируем наклон камеры после добавления экструзии
            let camera = mapView.camera
            if camera.pitch != 45 {
                camera.pitch = 45
                mapView.setCamera(camera, animated: true)
            }
        }

        private func localizeLabelsToRussian(style: MLNStyle) {
            for layer in style.layers {
                guard let symbolLayer = layer as? MLNSymbolStyleLayer else { continue }
                if symbolLayer.text != nil {
                    symbolLayer.text = NSExpression(mglJSONObject: ["coalesce", ["get", "name:ru"], ["get", "name"]])
                }
            }
        }
    }
}

