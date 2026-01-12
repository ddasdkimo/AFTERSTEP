import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/config/constants.dart';
import '../../data/models/red_dot.dart';
import '../widgets/fog_layer.dart';
import '../widgets/micro_event_overlay.dart';
import '../widgets/red_dot_layer.dart';

/// 地圖畫面
///
/// 主要的地圖介面，整合 Fog、紅點、微事件等圖層。
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  Timer? _viewportUpdateTimer;
  double _currentZoom = MapConfig.defaultZoom;
  LatLng _currentCenter = const LatLng(
    MapConfig.defaultCenterLat,
    MapConfig.defaultCenterLng,
  );

  @override
  void initState() {
    super.initState();

    // 初始化後開始追蹤
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndStartTracking();
    });
  }

  Future<void> _initializeAndStartTracking() async {
    final appState = context.read<AppState>();

    if (!appState.isInitialized) {
      await appState.initialize();
    }

    final success = await appState.startTracking();
    if (!success) {
      // 顯示位置權限錯誤
      if (mounted) {
        _showLocationPermissionDialog();
      }
    }
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1F),
        title: const Text(
          '需要位置權限',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          '此應用程式需要存取您的位置才能運作。請在設定中開啟位置權限。',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _initializeAndStartTracking();
            },
            child: const Text('重試'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _viewportUpdateTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _onMapEvent(MapEvent event) {
    if (event is MapEventMove || event is MapEventMoveEnd) {
      _currentCenter = event.camera.center;
      _currentZoom = event.camera.zoom;

      // 防抖更新視窗
      _viewportUpdateTimer?.cancel();
      _viewportUpdateTimer = Timer(
        const Duration(milliseconds: 100),
        _updateViewport,
      );
    }
  }

  void _updateViewport() {
    final bounds = _mapController.camera.visibleBounds;
    final appState = context.read<AppState>();

    appState.updateViewport(ViewportBounds(
      north: bounds.north,
      south: bounds.south,
      east: bounds.east,
      west: bounds.west,
      zoom: _currentZoom,
    ));
  }

  void _centerOnCurrentLocation() {
    final appState = context.read<AppState>();
    final location = appState.currentLocation;

    if (location != null) {
      _mapController.move(
        LatLng(location.point.latitude, location.point.longitude),
        _currentZoom,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          return Stack(
            children: [
              // 底層地圖
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentCenter,
                  initialZoom: _currentZoom,
                  minZoom: MapConfig.minZoom,
                  maxZoom: MapConfig.maxZoom,
                  onMapEvent: _onMapEvent,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  // 暗色地圖圖層
                  TileLayer(
                    urlTemplate: MapConfig.tileUrl,
                    userAgentPackageName: 'com.afterstep.fog',
                    tileProvider: NetworkTileProvider(),
                  ),

                  // Fog 圖層
                  _buildFogLayer(appState),

                  // 紅點圖層
                  _buildRedDotLayer(appState),

                  // 當前位置標記
                  if (appState.currentLocation != null)
                    _buildCurrentLocationMarker(appState),
                ],
              ),

              // 微事件覆蓋層
              MicroEventOverlay(
                eventStream: appState.microEventStream,
              ),

              // 定位按鈕
              Positioned(
                right: 16,
                bottom: 32 + MediaQuery.of(context).padding.bottom,
                child: _buildLocationButton(appState),
              ),

              // 載入指示器
              if (!appState.isInitialized)
                const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white24,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFogLayer(AppState appState) {
    return FogLayer(
      points: appState.fogState.points,
      paths: appState.fogState.paths,
      centerLat: _currentCenter.latitude,
      centerLng: _currentCenter.longitude,
      zoom: _currentZoom,
    );
  }

  Widget _buildRedDotLayer(AppState appState) {
    return RedDotLayer(
      dots: appState.visibleRedDots,
      centerLat: _currentCenter.latitude,
      centerLng: _currentCenter.longitude,
      zoom: _currentZoom,
    );
  }

  Widget _buildCurrentLocationMarker(AppState appState) {
    final location = appState.currentLocation!;

    return MarkerLayer(
      markers: [
        Marker(
          point: LatLng(location.point.latitude, location.point.longitude),
          width: 24,
          height: 24,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Color(0xFF4A90D9),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationButton(AppState appState) {
    final hasLocation = appState.currentLocation != null;

    return GestureDetector(
      onTap: hasLocation ? _centerOnCurrentLocation : null,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1F),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.my_location,
          color: hasLocation ? Colors.white : Colors.white38,
          size: 24,
        ),
      ),
    );
  }
}
