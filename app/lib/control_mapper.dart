class JoystickInput {
  JoystickInput({
    this.leftX = 0,
    this.leftY = 0,
    this.rightX = 0,
    this.rightY = 0,
    this.arm = false,
  });

  double leftX;
  double leftY;
  double rightX;
  double rightY;
  bool arm;
}

class RcChannels {
  RcChannels({
    required this.roll,
    required this.pitch,
    required this.yaw,
    required this.throttle,
    required this.arm,
  });

  final int roll;
  final int pitch;
  final int yaw;
  final int throttle;
  final int arm;

  Map<String, int> toJsonMap() {
    return {
      'roll': roll,
      'pitch': pitch,
      'yaw': yaw,
      'throttle': throttle,
      'arm': arm,
    };
  }
}

class ControlMapper {
  const ControlMapper({this.invertPitch = true});

  final bool invertPitch;

  RcChannels mapToRc(JoystickInput input) {
    final roll = _mapAxis(input.rightX);
    final pitch = _mapAxis(invertPitch ? -input.rightY : input.rightY);
    final yaw = _mapAxis(input.leftX);
    final throttle = _mapThrottle(input.leftY);

    return RcChannels(
      roll: roll,
      pitch: pitch,
      yaw: yaw,
      throttle: throttle,
      arm: input.arm ? 1 : 0,
    );
  }

  int _mapAxis(double value) {
    final clamped = value.clamp(-1.0, 1.0);
    return (1500 + (clamped * 500)).round();
  }

  int _mapThrottle(double value) {
    final clamped = value.clamp(-1.0, 1.0);
    final normalized = ((-clamped + 1) / 2).clamp(0.0, 1.0);
    return (1000 + (normalized * 1000)).round();
  }
}
