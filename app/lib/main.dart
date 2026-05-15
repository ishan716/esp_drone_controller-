import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'control_mapper.dart';
import 'joystick_widget.dart';
import 'udp_service.dart';

void main() {
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
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    _udpService = UdpService(address: _targetAddress, port: _targetPort);
    _pushUpdate();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _udpService.dispose();
    super.dispose();
  }

  void _pushUpdate() {
    final channels = _mapper.mapToRc(_input);
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
    final width = MediaQuery.of(context).size.width;
    final joystickSize = width < 500 ? 150.0 : 190.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Drone Controller'),
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
        child: Column(
          children: [
            const SizedBox(height: 12),
            _ControlRow(
              armEnabled: _input.arm,
              onArmToggle: () {
                setState(() {
                  _input.arm = !_input.arm;
                });
                _pushUpdate();
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const _JoystickLabel(title: 'Throttle / Yaw'),
                      const SizedBox(height: 12),
                      JoystickWidget(
                        size: joystickSize,
                        onChanged: _updateLeft,
                        returnToCenter: false,
                      ),
                    ],
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const _JoystickLabel(title: 'Roll / Pitch'),
                      const SizedBox(height: 12),
                      JoystickWidget(
                        size: joystickSize,
                        onChanged: _updateRight,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
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
      width: 140,
      height: 52,
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
          style: const TextStyle(fontWeight: FontWeight.w600),
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
        fontSize: 14,
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
