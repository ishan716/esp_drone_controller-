import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'control_mapper.dart';
import 'drone_wifi_service.dart';
import 'joystick_widget.dart';
import 'udp_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const DroneControllerApp());
}

class DroneControllerApp extends StatelessWidget {
  const DroneControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drone Controller',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0C10),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF27B4F6),
          secondary: Color(0xFF3DD6B4),
        ),
        useMaterial3: true,
      ),
      home: const DroneControllerHome(),
    );
  }
}

class DroneControllerHome extends StatefulWidget {
  const DroneControllerHome({super.key});

  @override
  State<DroneControllerHome> createState() => _DroneControllerHomeState();
}

class _DroneControllerHomeState extends State<DroneControllerHome> {
  static final InternetAddress _targetAddress =
      InternetAddress('192.168.4.1');
  static const int _targetPort = 5005;

  final ControlMapper _mapper = const ControlMapper();
  final DroneWifiService _wifiService = DroneWifiService();
  final JoystickInput _input = JoystickInput();
  late final UdpService _udpService;
  late final ValueNotifier<RcChannels> _channels;
  DroneWifiSnapshot _wifiSnapshot = const DroneWifiSnapshot.initial();
  Timer? _wifiTimer;
  bool _isConnectingWifi = false;

  @override
  void initState() {
    super.initState();
    _udpService = UdpService(address: _targetAddress, port: _targetPort);
    _channels = ValueNotifier<RcChannels>(
      _mapper.mapToRc(_input),
    );
    _refreshWifiStatus();
    _wifiTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refreshWifiStatus(),
    );
    _pushUpdate();
    _udpService.startStreaming();
  }

  @override
  void dispose() {
    _wifiTimer?.cancel();
    _udpService.dispose();
    _channels.dispose();
    super.dispose();
  }

  Future<void> _refreshWifiStatus() async {
    final snapshot = await _wifiService.refresh();
    if (!mounted) {
      return;
    }
    setState(() {
      _wifiSnapshot = snapshot;
    });
  }

  Future<void> _connectToDroneWifi() async {
    setState(() {
      _isConnectingWifi = true;
    });

    final snapshot = await _wifiService.connect();
    if (!mounted) {
      return;
    }

    setState(() {
      _wifiSnapshot = snapshot;
      _isConnectingWifi = false;
    });
  }

  void _pushUpdate() {
    final channels = _mapper.mapToRc(_input);
    _channels.value = channels;
    _udpService.updatePayload(channels.toJsonMap());
  }

  void _updateLeft(Offset value) {
    _input.leftX = value.dx;
    _input.leftY = value.dy;
    _pushUpdate();
  }

  void _updateRight(Offset value) {
    _input.rightX = value.dx;
    _input.rightY = value.dy;
    _pushUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final isCompactLayout = MediaQuery.sizeOf(context).height < 420;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: isCompactLayout ? 28 : 36,
        title: Text(
          'Drone Controller',
          style: TextStyle(fontSize: isCompactLayout ? 14 : 16),
        ),
        centerTitle: true,
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: _udpService.isSending,
            builder: (context, isSending, _) {
              final active = isSending && _udpService.hasRecentSend;
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _StatusPill(
                  isActive: active,
                  isCompact: isCompactLayout,
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final isCompactHeight = height < 420;
            final reservedHeight = isCompactHeight ? 100.0 : 150.0;
            final maxJoystickByHeight =
                (height - reservedHeight).clamp(120.0, height);
            final joystickSize = math.min(
              width < 500 ? 150.0 : 210.0,
              maxJoystickByHeight,
            );
            final centerPanelWidth = width < 700 ? 130.0 : 170.0;
            final topGap = isCompactHeight ? 0.0 : 4.0;
            final sectionGap = isCompactHeight ? 2.0 : 6.0;
            final bottomGap = isCompactHeight ? 0.0 : 6.0;

            return Column(
              children: [
                SizedBox(height: topGap),
                _ControlRow(
                  armEnabled: _input.arm,
                  isCompact: isCompactHeight,
                  onArmToggle: () {
                    setState(() {
                      _input.arm = !_input.arm;
                    });
                    _pushUpdate();
                  },
                ),
                SizedBox(height: sectionGap),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _udpService.isSending,
                    builder: (context, isSending, _) {
                      return _ConnectionPanel(
                        snapshot: _wifiSnapshot,
                        targetIp: _targetAddress.address,
                        targetPort: _targetPort,
                        udpActive: isSending && _udpService.hasRecentSend,
                        isConnecting: _isConnectingWifi,
                        isCompact: isCompactHeight,
                        onConnect: _connectToDroneWifi,
                        onRefresh: _refreshWifiStatus,
                      );
                    },
                  ),
                ),
                SizedBox(height: topGap),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const _JoystickLabel(title: 'Throttle / Yaw'),
                          const SizedBox(height: 4),
                          JoystickWidget(
                            size: joystickSize,
                            onChanged: _updateLeft,
                            returnToCenter: false,
                          ),
                        ],
                      ),
                      SizedBox(
                        width: centerPanelWidth,
                        child: ValueListenableBuilder<RcChannels>(
                          valueListenable: _channels,
                          builder: (context, channels, _) {
                            return _ChannelPanel(channels: channels);
                          },
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const _JoystickLabel(title: 'Roll / Pitch'),
                          const SizedBox(height: 4),
                          JoystickWidget(
                            size: joystickSize,
                            onChanged: _updateRight,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: bottomGap),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ControlRow extends StatelessWidget {
  const _ControlRow({
    required this.armEnabled,
    required this.onArmToggle,
    required this.isCompact,
  });

  final bool armEnabled;
  final VoidCallback onArmToggle;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ActionButton(
            label: armEnabled ? 'DISARM' : 'ARM',
            color: armEnabled ? const Color(0xFFE0565B) : const Color(0xFF3DD6B4),
            isCompact: isCompact,
            onPressed: onArmToggle,
          ),
          _ActionButton(
            label: 'MODE',
            color: Color(0xFF2D3140),
            isCompact: isCompact,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.isCompact,
    this.onPressed,
  });

  final String label;
  final Color color;
  final bool isCompact;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: isCompact ? 110 : 120,
      height: isCompact ? 36 : 44,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: isCompact
              ? const EdgeInsets.symmetric(horizontal: 8)
              : const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isCompact ? 11 : 12,
          ),
        ),
      ),
    );
  }
}

class _JoystickLabel extends StatelessWidget {
  const _JoystickLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        letterSpacing: 0.5,
        color: Color(0xFF9FA4B4),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isActive, required this.isCompact});

  final bool isActive;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFF3DD6B4) : const Color(0xFFE0565B);
    final label = isActive ? 'UDP Active' : 'UDP Idle';

    return Container(
      padding: isCompact
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1E24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.4),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: isCompact ? 11 : 12,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionPanel extends StatelessWidget {
  const _ConnectionPanel({
    required this.snapshot,
    required this.targetIp,
    required this.targetPort,
    required this.udpActive,
    required this.isConnecting,
    required this.isCompact,
    required this.onConnect,
    required this.onRefresh,
  });

  final DroneWifiSnapshot snapshot;
  final String targetIp;
  final int targetPort;
  final bool udpActive;
  final bool isConnecting;
  final bool isCompact;
  final VoidCallback onConnect;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final connected = snapshot.connectedToDrone;
    final statusColor =
        connected && udpActive ? const Color(0xFF3DD6B4) : const Color(0xFFE0A856);
    final statusLabel = connected
        ? (udpActive ? 'Drone link active' : 'Drone WiFi connected')
        : 'Drone WiFi not connected';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: isCompact ? 6 : 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF11141A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A303B)),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi, color: statusColor, size: isCompact ? 18 : 20),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 14,
              runSpacing: isCompact ? 2 : 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _ConnectionText(
                  label: 'Status',
                  value: statusLabel,
                  color: statusColor,
                  isCompact: isCompact,
                ),
                _ConnectionText(
                  label: 'SSID',
                  value: snapshot.ssid ?? 'unknown',
                  isCompact: isCompact,
                ),
                _ConnectionText(
                  label: 'Phone IP',
                  value: snapshot.ipAddress ?? 'none',
                  isCompact: isCompact,
                ),
                _ConnectionText(
                  label: 'Target',
                  value: '$targetIp:$targetPort',
                  isCompact: isCompact,
                ),
                _ConnectionText(
                  label: 'UDP',
                  value: udpActive ? 'sending' : 'idle',
                  isCompact: isCompact,
                ),
                if (snapshot.message != null && !connected)
                  _ConnectionText(
                    label: 'Note',
                    value: snapshot.message!,
                    color: const Color(0xFFE0A856),
                    isCompact: isCompact,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Refresh WiFi status',
            onPressed: onRefresh,
            icon: Icon(Icons.refresh, size: isCompact ? 18 : 20),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed:
                snapshot.supported && !isConnecting ? onConnect : null,
            icon: isConnecting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.link),
            label: Text(isConnecting ? 'Connecting' : 'Connect'),
            style: isCompact
                ? FilledButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    textStyle: const TextStyle(fontSize: 12),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _ConnectionText extends StatelessWidget {
  const _ConnectionText({
    required this.label,
    required this.value,
    required this.isCompact,
    this.color,
  });

  final String label;
  final String value;
  final bool isCompact;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: isCompact ? 10 : 11,
          color: const Color(0xFFB9C0D3),
        ),
        children: [
          TextSpan(
            text: '$label ',
            style: const TextStyle(color: Color(0xFF737B8F)),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              color: color ?? const Color(0xFFE7ECF7),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelPanel extends StatelessWidget {
  const _ChannelPanel({required this.channels});

  final RcChannels channels;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF11141A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2A303B)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'RC Values',
            style: TextStyle(
              color: Color(0xFF9FA4B4),
              fontSize: 11,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          _ChannelRow(label: 'Roll', value: channels.roll),
          _ChannelRow(label: 'Pitch', value: channels.pitch),
          _ChannelRow(label: 'Yaw', value: channels.yaw),
          _ChannelRow(label: 'Throttle', value: channels.throttle),
          _ChannelRow(label: 'Arm', value: channels.arm),
        ],
      ),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFFB9C0D3), fontSize: 12),
          ),
          Text(
            value.toString(),
            style: const TextStyle(
              color: Color(0xFF27B4F6),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
