import 'dart:io';

import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_iot/wifi_iot.dart';

class DroneWifiConfig {
  const DroneWifiConfig({
    this.ssid = 'DroneController',
    this.password = '12345678',
    this.targetIp = '192.168.4.1',
    this.targetPort = 5005,
  });

  final String ssid;
  final String password;
  final String targetIp;
  final int targetPort;
}

class DroneWifiSnapshot {
  const DroneWifiSnapshot({
    required this.supported,
    required this.ssid,
    required this.ipAddress,
    required this.connectedToDrone,
    required this.wifiEnabled,
    this.message,
  });

  const DroneWifiSnapshot.initial()
      : supported = true,
        ssid = null,
        ipAddress = null,
        connectedToDrone = false,
        wifiEnabled = null,
        message = null;

  final bool supported;
  final String? ssid;
  final String? ipAddress;
  final bool connectedToDrone;
  final bool? wifiEnabled;
  final String? message;
}

class DroneWifiService {
  DroneWifiService({this.config = const DroneWifiConfig()});

  final DroneWifiConfig config;

  Future<DroneWifiSnapshot> refresh() async {
    if (!Platform.isAndroid) {
      return const DroneWifiSnapshot(
        supported: false,
        ssid: null,
        ipAddress: null,
        connectedToDrone: false,
        wifiEnabled: null,
        message: 'WiFi connect is available on Android in this app.',
      );
    }

    try {
      final permissionGranted = await _hasWifiPermission();
      final wifiEnabled = await WiFiForIoTPlugin.isEnabled();
      if (!permissionGranted) {
        return DroneWifiSnapshot(
          supported: true,
          ssid: null,
          ipAddress: null,
          connectedToDrone: false,
          wifiEnabled: wifiEnabled,
          message: 'Tap Connect and allow location to read WiFi details.',
        );
      }

      final rawSsid = await WiFiForIoTPlugin.getSSID();
      final ipAddress = await WiFiForIoTPlugin.getIP();
      final ssid = _cleanSsid(rawSsid);
      final connectedToDrone = ssid == config.ssid;

      if (connectedToDrone) {
        try {
          await WiFiForIoTPlugin.forceWifiUsage(true);
        } catch (_) {
          // forceWifiUsage can throw on some Android versions; ignore.
        }
      }

      return DroneWifiSnapshot(
        supported: true,
        ssid: ssid,
        ipAddress: ipAddress,
        connectedToDrone: connectedToDrone,
        wifiEnabled: wifiEnabled,
        message: connectedToDrone ? 'Drone WiFi connected' : null,
      );
    } catch (error) {
      return DroneWifiSnapshot(
        supported: true,
        ssid: null,
        ipAddress: null,
        connectedToDrone: false,
        wifiEnabled: null,
        message: 'WiFi status unavailable: $error',
      );
    }
  }

  Future<DroneWifiSnapshot> connect() async {
    if (!Platform.isAndroid) {
      return refresh();
    }

    try {
      final permissionGranted = await _ensureWifiPermission();
      if (!permissionGranted) {
        return const DroneWifiSnapshot(
          supported: true,
          ssid: null,
          ipAddress: null,
          connectedToDrone: false,
          wifiEnabled: null,
          message: 'Allow location permission, then tap Connect again.',
        );
      }

      final enabled = await WiFiForIoTPlugin.isEnabled();
      if (!enabled) {
        await WiFiForIoTPlugin.setEnabled(true);
      }

      final connected = await WiFiForIoTPlugin.connect(
        config.ssid,
        password: config.password,
        security: NetworkSecurity.WPA,
        joinOnce: false,
        withInternet: false,
      );

      await WiFiForIoTPlugin.forceWifiUsage(true);
      final snapshot = await refresh();

      if (!connected && !snapshot.connectedToDrone) {
        return DroneWifiSnapshot(
          supported: true,
          ssid: snapshot.ssid,
          ipAddress: snapshot.ipAddress,
          connectedToDrone: false,
          wifiEnabled: snapshot.wifiEnabled,
          message: 'Could not connect to ${config.ssid}',
        );
      }

      return snapshot;
    } catch (error) {
      return DroneWifiSnapshot(
        supported: true,
        ssid: null,
        ipAddress: null,
        connectedToDrone: false,
        wifiEnabled: null,
        message: 'Connect failed: $error',
      );
    }
  }

  Future<bool> _ensureWifiPermission() async {
    final results = await [
      Permission.locationWhenInUse,
      Permission.nearbyWifiDevices,
    ].request();
    return _anyGranted(results.values);
  }

  Future<bool> _hasWifiPermission() async {
    final statuses = await Future.wait([
      Permission.locationWhenInUse.status,
      Permission.nearbyWifiDevices.status,
    ]);
    return _anyGranted(statuses);
  }

  bool _anyGranted(Iterable<PermissionStatus> statuses) {
    for (final status in statuses) {
      if (status.isGranted || status.isLimited) {
        return true;
      }
    }
    return false;
  }

  String? _cleanSsid(String? value) {
    if (value == null || value.isEmpty || value == '<unknown ssid>') {
      return null;
    }
    return value.replaceAll('"', '');
  }
}
