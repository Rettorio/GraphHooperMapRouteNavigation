import 'package:flutter/cupertino.dart';
import 'package:graphhooper_route_navigation/graphhooper_route_navigation.dart';
import 'package:graphhooper_route_navigation/src/map/navigation/controllers/is_simulate_routing_notifier_controller.dart';
import 'package:graphhooper_route_navigation/src/map/navigation/providers/instruction_controller_provider.dart';
import 'package:graphhooper_route_navigation/src/map/navigation/providers/map_controller_provider.dart';
import 'package:graphhooper_route_navigation/src/map/navigation/providers/user_speed_notifier_provider.dart';
import 'package:flutter/services.dart';

/// This is Map Screen which will show up after we start navigation.
///
class MapWidget extends StatefulWidget {
  /// [DirectionRouteResponse]instance
  ///
  final DirectionRouteResponse directionRouteResponse;

  /// Creates [MapWidget] insstance
  ///
  const MapWidget({super.key, required this.directionRouteResponse});

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  static const String MARKER_IMAGE_ID = 'marker_icon';
  static const String MARKER_SOURCE_ID = 'destinations-source';
  static const String MARKER_LAYER_ID = 'destinations-layer';

  static const String ROUTE_SOURCE_ID = 'route-source';
  static const String ROUTE_LAYER_ID = 'route-layer';

  Future<void> _addDestinationsAndRoute(MapLibreMapController mapController) async {
    if (mapController == null) return;

    // 1. Add a custom image for the markers
    final ByteData bytes = await rootBundle.load(
      'assets/destination_marker.png',
    ); // Ensure you have this asset
    final Uint8List list = bytes.buffer.asUint8List();
    await mapController!.addImage(MARKER_IMAGE_ID, list);
    var destinations = widget.directionRouteResponse.paths?.map((item) => item.points!).toList() ?? [];

    // 2. Create GeoJSON sources for markers and the route
    final markerFeatures = destinations
        .map(
          (latLng) => {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': latLng.coordinates ?? [],
            },
            'properties': {},
          },
        )
        .toList();

    final routeCoordinates = destinations
        .map((latLng) => latLng.coordinates ?? [])
        .toList();

    // 3. Add the sources to the map
    await mapController.addSource(
      MARKER_SOURCE_ID,
      GeojsonSourceProperties(data: {
        'type': 'FeatureCollection',
        'features': markerFeatures,
      }) 
    );

    await mapController!.addSource(ROUTE_SOURCE_ID, GeojsonSourceProperties(data: {
        'type': 'Feature',
        'properties': {},
        'geometry': {'type': 'LineString', 'coordinates': routeCoordinates}
    }));

    // 4. Add the layers to display markers and the route
    await mapController.addSymbolLayer(
      MARKER_SOURCE_ID,
      MARKER_LAYER_ID,
      const SymbolLayerProperties(
        iconImage: MARKER_IMAGE_ID,
        iconSize: 0.5,
        iconAllowOverlap: true,
      ),
    );

    await mapController.addLineLayer(
      ROUTE_SOURCE_ID,
      ROUTE_LAYER_ID,
      const LineLayerProperties(
        lineColor: '#FF0000', // Red color
        lineWidth: 3.0,
        lineOpacity: 0.8,
      ),
    );

    // 5. Adjust the camera to fit all destinations
    // _zoomToFitDestinations();
  }

  @override
  Widget build(BuildContext context) {
    // map controller
    final mapController = MapControllerProvider.of(context);
    //
    return MapLibreMap(
      styleString:
          'https://tiles.basemaps.cartocdn.com/gl/voyager-gl-style/style.json',
      onMapCreated: (mapLibreController) {
        // method which gets executed after the map has been initialized
        mapController.onMapCreated(mapLibreMapController: mapLibreController);
        mapController.addDestinationCircle();
      },
      onStyleLoadedCallback: () {
        // function to be called after the style has been loadded
        _onStyleLoadedCallback(
          mapController.mapController!,
          widget.directionRouteResponse,
          mapController.mapZoomLevel,
        );
      },
      // initialCameraPosition means initial location it didn't depends on the user current physical location itself
      initialCameraPosition: CameraPosition(
        target: LatLng(
          widget
              .directionRouteResponse
              .paths![0]
              .snappedWaypoints!
              .coordinates!
              .first[1],
          widget
              .directionRouteResponse
              .paths![0]
              .snappedWaypoints!
              .coordinates!
              .first[0],
        ),
        zoom: mapController.mapZoomLevel,
      ),
      minMaxZoomPreference: const MinMaxZoomPreference(6, 19),
      myLocationEnabled: true,
      trackCameraPosition: true,
      compassEnabled: false,
      compassViewPosition: CompassViewPosition.topRight,
      myLocationTrackingMode: MyLocationTrackingMode.trackingGps,
      myLocationRenderMode: MyLocationRenderMode.gps,

      onUserLocationUpdated: (userLocation) {
        // navigation instruction controller
        final navigationInstructionController =
            NavigationInstructionProvider.of(context);

        // speed controller
        final speedNotifierController = UserSpeedProvider.of(context);

        if (!IsSimulateRoutingNotifierController.isSimulateRouting) {
          // update user's physical real location
          mapController.updateUserLocation(userLocation: userLocation);

          // checks if the coordinate is inside the circle
          navigationInstructionController.checkIsCoordinateInsideCircle(
            directionRouteResponse: widget.directionRouteResponse,
            usersLatLng: userLocation.position,
          );

          // update user's speed
          speedNotifierController.setUserSpeed(speed: userLocation.speed);

          // update the bearing value
          mapController.updateBearingBtnTwoCoords(
            bearingValue: userLocation.bearing,
          );
        }
      },
      // cameraTargetBounds: CameraTargetBounds(LatLngBounds( southwest: const LatLng(26.3978980576, 80.0884245137), northeast: const LatLng(26.3978980576, 80.0884245137))),
    );
  }

  void _onStyleLoadedCallback(
    MapLibreMapController mapLibreMapController,
    DirectionRouteResponse directionRouteResponse,
    double zoomLevel,
  ) async {
    await _addDestinationsAndRoute(mapLibreMapController);
    mapLibreMapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(
            directionRouteResponse
                .paths![0]
                .snappedWaypoints!
                .coordinates!
                .first[1],
            directionRouteResponse
                .paths![0]
                .snappedWaypoints!
                .coordinates!
                .first[0],
          ),
          zoom: zoomLevel,
        ),
      ),
    );
  }
}
