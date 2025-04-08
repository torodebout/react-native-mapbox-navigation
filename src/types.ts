import type { StyleProp, ViewStyle } from 'react-native';

import type { Language } from './locals';

export type Coordinate = {
  latitude: number;
  longitude: number;
};

export type Waypoint = Coordinate & {
  name?: string;
  /**
   * Indicates whether the `onArrive` event is triggered when reaching the waypoint effectively.
   * @Default true
   */
  separatesLegs?: boolean;
};

export type WaypointEvent = Coordinate & {
  /**
   * Name of Waypoint if provided or index of legs/waypoint
   * @available iOS
   **/
  name?: string;
  /**
   * Index of legs/waypoint
   * @available Android
   **/
  index?: number;
};

export type Location = {
  latitude: number;
  longitude: number;
  heading: number;
  accuracy: number;
};

export type NativeEvent<T> = {
  nativeEvent: T;
};

export type RouteProgress = {
  distanceTraveled: number;
  durationRemaining: number;
  fractionTraveled: number;
  distanceRemaining: number;
};

export type MapboxEvent = {
  message?: string;
};

export type MapboxStyle =
  | 'standard'
  | 'mapbox-streets'
  | 'outdoors'
  | 'light'
  | 'dark'
  | 'satellite'
  | 'satellite-streets'
  | 'traffic-day'
  | 'traffic-night'
  | 'navigation-day'
  | 'navigation-night';

export type NativeEventsProps = {
  onLocationChange?: (event: NativeEvent<Location>) => void;
  onRouteProgressChange?: (event: NativeEvent<RouteProgress>) => void;
  onError?: (event: NativeEvent<MapboxEvent>) => void;
  onCancelNavigation?: (event: NativeEvent<MapboxEvent>) => void;
  onArrive?: (event: NativeEvent<WaypointEvent>) => void;
};

export interface MapboxNavigationProps {
  style?: StyleProp<ViewStyle>;
  mute?: boolean;
  showCancelButton?: boolean;
  startOrigin: Coordinate;
  waypoints?: Waypoint[];
  separateLegs?: boolean;
  destination: Coordinate & { title?: string };
  language?: Language;
  distanceUnit?: 'metric' | 'imperial';

  /**
   * Specifies the map style to use for navigation.
   * 
   * - 'standard': Standard Mapbox style
   * - 'mapbox-streets': Streets style (v12)
   * - 'outdoors': Outdoors style (v12)
   * - 'light': Light style (v11)
   * - 'dark': Dark style (v11)
   * - 'satellite': Satellite style (v9)
   * - 'satellite-streets': Satellite streets style (v12)
   * - 'traffic-day': Traffic day style (v2)
   * - 'traffic-night': Traffic night style (v2)
   * - 'navigation-day': Navigation day style (v1)
   * - 'navigation-night': Navigation night style (v1)
   * 
   * @Default "mapbox-streets"
   * @available iOS
   */
  mapStyle?: MapboxStyle;

  /**
   * Specifies the mode of travel for navigation.
   *
   * - 'driving': Standard driving mode that does not take live traffic conditions into account.
   * - 'driving-traffic': Driving mode that considers current traffic conditions to avoid congestion.
   * - 'walking': Navigation for pedestrians.
   * - 'cycling': Navigation optimized for cyclists.
   *
   * @Default "driving-traffic"
   */
  travelMode?: 'driving' | 'driving-traffic' | 'walking' | 'cycling';

  /**
   * [iOS only]
   * @Default false
   */
  showsEndOfRouteFeedback?: boolean;

  /**
   * Hide status of bar on navigation [iOS only]
   * @Default false
   */
  hideStatusView?: boolean;

  /**
   * Location simulation for debug.
   * @Default false
   * @available iOS
   * @android Planned for next release
   */
  shouldSimulateRoute?: boolean;

  onLocationChange?: (location: Location) => void;
  onRouteProgressChange?: (progress: RouteProgress) => void;
  onError?: (error: MapboxEvent) => void;
  onCancelNavigation?: (event: MapboxEvent) => void;
  onArrive?: (point: WaypointEvent) => void;
}
