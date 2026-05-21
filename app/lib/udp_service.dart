import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class UdpService {
  UdpService({
    required this.address,
    required this.port,
    Duration interval = const Duration(milliseconds: 10),
  }) : _interval = interval;

  final InternetAddress address;
  final int port;
  final Duration _interval;
  final ValueNotifier<bool> isSending = ValueNotifier<bool>(false);

  RawDatagramSocket? _socket;
  Timer? _timer;
  List<int>? _encodedPayload;
  DateTime? _lastSendAt;

  Future<void> startStreaming() async {
    if (_timer != null) {
      return;
    }

    _socket ??= await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

    _timer = Timer.periodic(_interval, (_) => _send());
    _send();
  }

  void updatePayload(Map<String, int> payload) {
    _encodedPayload = utf8.encode(jsonEncode(payload));
  }

  void stopStreaming() {
    _timer?.cancel();
    _timer = null;
    _updateSending(false);
  }

  Future<void> restart() async {
    stopStreaming();
    _socket?.close();
    _socket = null;
    _lastSendAt = null;
    await startStreaming();
  }

  void dispose() {
    stopStreaming();
    _socket?.close();
    _socket = null;
    isSending.dispose();
  }

  void _send() {
    final socket = _socket;
    final encodedPayload = _encodedPayload;
    if (socket == null || encodedPayload == null) {
      _updateSending(false);
      return;
    }

    socket.send(encodedPayload, address, port);
    _lastSendAt = DateTime.now();
    _updateSending(true);
  }

  void _updateSending(bool value) {
    if (isSending.value != value) {
      isSending.value = value;
    }
  }

  bool get hasRecentSend {
    final lastSendAt = _lastSendAt;
    if (lastSendAt == null) {
      return false;
    }
    return DateTime.now().difference(lastSendAt).inMilliseconds < 150;
  }
}
