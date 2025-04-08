import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections

extension UIView {
    var parentViewController: UIViewController? {
        var parentResponder: UIResponder? = self
        while parentResponder != nil {
            parentResponder = parentResponder!.next
            if let viewController = parentResponder as? UIViewController {
                return viewController
            }
        }
        return nil
    }
}

public protocol MapboxCarPlayDelegate {
    func connect(with navigationView: MapboxNavigationView)
    func disconnect()
}

public protocol MapboxCarPlayNavigationDelegate {
    func startNavigation(with navigationView: MapboxNavigationView)
    func endNavigation()
}

public class MapboxNavigationView: UIView, NavigationViewControllerDelegate {
    public weak var navViewController: NavigationViewController?
    public var indexedRouteResponse: IndexedRouteResponse?
    
    var embedded: Bool
    var embedding: Bool

    @objc public var startOrigin: NSArray = [] {
        didSet { setNeedsLayout() }
    }
    
    var waypoints: [Waypoint] = [] {
        didSet { setNeedsLayout() }
    }
    
    func setWaypoints(waypoints: [MapboxWaypoint]) {
      self.waypoints = waypoints.enumerated().map { (index, waypointData) in
          let name = waypointData.name as? String ?? "\(index)"
          let waypoint = Waypoint(coordinate: waypointData.coordinate, name: name)
          waypoint.separatesLegs = waypointData.separatesLegs
          return waypoint
      }
    }
    
    @objc var destination: NSArray = [] {
        didSet { setNeedsLayout() }
    }
    
    @objc var shouldSimulateRoute: Bool = false
    @objc var showsEndOfRouteFeedback: Bool = false
    @objc var showCancelButton: Bool = false
    @objc var hideStatusView: Bool = false
    @objc var mute: Bool = false
    @objc var distanceUnit: NSString = "imperial"
    @objc var language: NSString = "us"
    @objc var destinationTitle: NSString = "Destination"
    @objc var travelMode: NSString = "driving-traffic"
    @objc var mapStyle: NSString = "mapbox-streets" {
        didSet {
            updateMapStyle()
        }
    }

    @objc var onLocationChange: RCTDirectEventBlock?
    @objc var onRouteProgressChange: RCTDirectEventBlock?
    @objc var onError: RCTDirectEventBlock?
    @objc var onCancelNavigation: RCTDirectEventBlock?
    @objc var onArrive: RCTDirectEventBlock?
    @objc var vehicleMaxHeight: NSNumber?
    @objc var vehicleMaxWidth: NSNumber?

    override init(frame: CGRect) {
        self.embedded = false
        self.embedding = false
        super.init(frame: frame)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        if (navViewController == nil && !embedding && !embedded) {
            embed()
        } else {
            navViewController?.view.frame = bounds
        }
    }

    public override func removeFromSuperview() {
        super.removeFromSuperview()
        // cleanup and teardown any existing resources
        self.navViewController?.removeFromParent()
        
        // MARK: End CarPlay Navigation
        if let carPlayNavigation = UIApplication.shared.delegate as? MapboxCarPlayNavigationDelegate {
            carPlayNavigation.endNavigation()
        }
        NotificationCenter.default.removeObserver(self, name: .navigationSettingsDidChange, object: nil)
    }

    private func embed() {
        guard startOrigin.count == 2 && destination.count == 2 else { return }

        embedding = true

        let originWaypoint = Waypoint(coordinate: CLLocationCoordinate2D(latitude: startOrigin[1] as! CLLocationDegrees, longitude: startOrigin[0] as! CLLocationDegrees))
        var waypointsArray = [originWaypoint]

        // Add Waypoints
        waypointsArray.append(contentsOf: waypoints)

        let destinationWaypoint = Waypoint(coordinate: CLLocationCoordinate2D(latitude: destination[1] as! CLLocationDegrees, longitude: destination[0] as! CLLocationDegrees), name: destinationTitle as String)
        waypointsArray.append(destinationWaypoint)

        let profile: MBDirectionsProfileIdentifier

        switch travelMode {
            case "cycling":
                profile = .cycling
            case "walking":
                profile = .walking
            case "driving-traffic":
                profile = .automobileAvoidingTraffic
            default:
                profile = .automobile
        }

        let options = NavigationRouteOptions(waypoints: waypointsArray, profileIdentifier: profile)

        let locale = self.language.replacingOccurrences(of: "-", with: "_")
        options.locale = Locale(identifier: locale)
        options.distanceMeasurementSystem =  distanceUnit == "imperial" ? .imperial : .metric

        Directions.shared.calculateRoutes(options: options) { [weak self] result in
            guard let strongSelf = self, let parentVC = strongSelf.parentViewController else {
                return
            }

            switch result {
            case .failure(let error):
                strongSelf.onError!(["message": error.localizedDescription])
            case .success(let response):
                strongSelf.indexedRouteResponse = response
                let navigationOptions = NavigationOptions(simulationMode: strongSelf.shouldSimulateRoute ? .always : .never)
                let vc = NavigationViewController(for: response, navigationOptions: navigationOptions)

                // Set initial map style
                if let styleURL = URL(string: "mapbox://styles/mapbox/\(strongSelf.mapStyle)") {
                    vc.navigationMapView?.mapView.mapboxMap.style.uri = styleURL
                }

                vc.showsEndOfRouteFeedback = strongSelf.showsEndOfRouteFeedback
                StatusView.appearance().isHidden = strongSelf.hideStatusView

                NavigationSettings.shared.voiceMuted = strongSelf.mute
                NavigationSettings.shared.distanceUnit = strongSelf.distanceUnit == "imperial" ? .mile : .kilometer

                vc.delegate = strongSelf

                parentVC.addChild(vc)
                strongSelf.addSubview(vc.view)
                vc.view.frame = strongSelf.bounds
                vc.didMove(toParent: parentVC)
                strongSelf.navViewController = vc
            }

            strongSelf.embedding = false
            strongSelf.embedded = true
            
            // MARK: Start CarPlay Navigation
            if let carPlayNavigation = UIApplication.shared.delegate as? MapboxCarPlayNavigationDelegate {
                carPlayNavigation.startNavigation(with: strongSelf)
            }
        }
    }

    public func navigationViewController(_ navigationViewController: NavigationViewController, didUpdate progress: RouteProgress, with location: CLLocation, rawLocation: CLLocation) {
        onLocationChange?([
            "longitude": location.coordinate.longitude,
            "latitude": location.coordinate.latitude,
            "heading": 0,
            "accuracy": location.horizontalAccuracy.magnitude
        ])
        onRouteProgressChange?([
            "distanceTraveled": progress.distanceTraveled,
            "durationRemaining": progress.durationRemaining,
            "fractionTraveled": progress.fractionTraveled,
            "distanceRemaining": progress.distanceRemaining
        ])
    }

    public func navigationViewControllerDidDismiss(_ navigationViewController: NavigationViewController, byCanceling canceled: Bool) {
        if (!canceled) {
            return;
        }
        onCancelNavigation?(["message": "Navigation Cancel"]);
    }

    public func navigationViewController(_ navigationViewController: NavigationViewController, didArriveAt waypoint: Waypoint) -> Bool {
        onArrive?([
          "name": waypoint.name ?? waypoint.description,
          "longitude": waypoint.coordinate.latitude,
          "latitude": waypoint.coordinate.longitude,
        ])
        return true;
    }

    private func updateMapStyle() {
        guard let navigationVC = navViewController else { return }
        
        let styleURL: URL
        switch mapStyle as String {
            case "standard":
                styleURL = URL(string: "mapbox://styles/mapbox/standard")!
            case "mapbox-streets":
                styleURL = URL(string: "mapbox://styles/mapbox/streets-v12")!
            case "outdoors":
                styleURL = URL(string: "mapbox://styles/mapbox/outdoors-v12")!
            case "light":
                styleURL = URL(string: "mapbox://styles/mapbox/light-v11")!
            case "dark":
                styleURL = URL(string: "mapbox://styles/mapbox/dark-v11")!
            case "satellite":
                styleURL = URL(string: "mapbox://styles/mapbox/satellite-v9")!
            case "satellite-streets":
                styleURL = URL(string: "mapbox://styles/mapbox/satellite-streets-v12")!
            case "traffic-day":
                styleURL = URL(string: "mapbox://styles/mapbox/traffic-day-v2")!
            case "traffic-night":
                styleURL = URL(string: "mapbox://styles/mapbox/traffic-night-v2")!
            case "navigation-day":
                styleURL = URL(string: "mapbox://styles/mapbox/navigation-day-v1")!
            case "navigation-night":
                styleURL = URL(string: "mapbox://styles/mapbox/navigation-night-v1")!
            default:
                styleURL = URL(string: "mapbox://styles/mapbox/streets-v12")!
        }
        
        navigationVC.navigationMapView?.mapView.mapboxMap.style.uri = styleURL
    }
}
