import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'control_mapper.dart';
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
  final JoystickInput _input = JoystickInput();
  late final UdpService _udpService;
  late final ValueNotifier<RcChannels> _channels;
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    _udpService = UdpService(address: _targetAddress, port: _targetPort);
    _channels = ValueNotifier<RcChannels>(
      _mapper.mapToRc(_input),
    );
    _pushUpdate();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _udpService.dispose();
    _channels.dispose();
    super.dispose();
  }

  void _pushUpdate() {
    final channels = _mapper.mapToRc(_input);
    _channels.value = channels;
    _udpService.updatePayload(channels.toJsonMap());
    _udpService.startStreaming();

    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(milliseconds: 300), () {
      _udpService.stopStreaming();
    });
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
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 44,
        title: const Text(
          'Drone Controller',
          style: TextStyle(fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: _udpService.isSending,
            builder: (context, isSending, _) {
              final active = isSending && _udpService.hasRecentSend;
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _StatusPill(isActive: active),
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
            final joystickSize = math.min(
              width < 500 ? 160.0 : 210.0,
              height * 0.68,
            );
            final centerPanelWidth = width < 700 ? 130.0 : 170.0;

            return Column(
              children: [
                const SizedBox(height: 4),
                _ControlRow(
                  armEnabled: _input.arm,
                  onArmToggle: () {
                    setState(() {
                      _input.arm = !_input.arm;
                    });
                    _pushUpdate();
                  },
                ),
                const SizedBox(height: 4),
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
                const SizedBox(height: 6),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ControlRow extends StatelessWidget {
  const _ControlRow({required this.armEnabled, required this.onArmToggle});

  final bool armEnabled;
  final VoidCallback onArmToggle;

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
            onPressed: onArmToggle,
          ),
          const _ActionButton(
            label: 'MODE',
            color: Color(0xFF2D3140),
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
    this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 44,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
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
  const _StatusPill({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFF3DD6B4) : const Color(0xFFE0565B);
    final label = isActive ? 'Connected' : 'Disconnected';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            style: const TextStyle(fontSize: 12, letterSpacing: 0.4),
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
