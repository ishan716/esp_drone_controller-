class JoystickInput {
  JoystickInput({
    this.leftX = 0,
    this.leftY = 1,
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
    required this.sequence,
  });

  final int roll;
  final int pitch;
  final int yaw;
  final int throttle;
  final int arm;
  final int sequence;

  Map<String, int> toJsonMap() {
    return {
      'seq': sequence,
      'roll': roll,
      'pitch': pitch,
      'yaw': yaw,
      'throttle': throttle,
      'arm': arm,
    };
  }
}

class ControlMapper {
  const ControlMapper({
    this.invertPitch = true,
    this.deadband = 0.06,
    this.axisExpo = 0.45,
    this.rollPitchSensitivity = 0.65,
    this.yawSensitivity = 0.55,
    this.throttleExpo = 0.25,
  });

  final bool invertPitch;
  final double deadband;
  final double axisExpo;
  final double rollPitchSensitivity;
  final double yawSensitivity;
  final double throttleExpo;

  RcChannels mapToRc(JoystickInput input, {required int sequence}) {
    final roll = _mapAxis(input.rightX, rollPitchSensitivity);
    final pitch = _mapAxis(
      invertPitch ? -input.rightY : input.rightY,
      rollPitchSensitivity,
    );
    final yaw = _mapAxis(input.leftX, yawSensitivity);
    final throttle = _mapThrottle(input.leftY);

    return RcChannels(
      roll: roll,
      pitch: pitch,
      yaw: yaw,
      throttle: throttle,
      arm: input.arm ? 1 : 0,
      sequence: sequence,
    );
  }

  int _mapAxis(double value, double sensitivity) {
    final shaped = _shapeAxis(value) * sensitivity.clamp(0.0, 1.0).toDouble();
    return (1500 + (shaped * 500)).round();
  }

  int _mapThrottle(double value) {
    final clamped = value.clamp(-1.0, 1.0).toDouble();
    final shaped = _shapeAxis(clamped);
    final softened = shaped * (1 - throttleExpo) +
        shaped * shaped * shaped * throttleExpo;
    final normalized = ((-softened + 1) / 2).clamp(0.0, 1.0);
    return (1000 + (normalized * 1000)).round();
  }

  double _shapeAxis(double value) {
    final clamped = value.clamp(-1.0, 1.0).toDouble();
    final magnitude = clamped.abs();
    if (magnitude <= deadband) {
      return 0;
    }

    final normalized = ((magnitude - deadband) / (1 - deadband))
        .clamp(0.0, 1.0)
        .toDouble();
    final curved = normalized * (1 - axisExpo) +
        normalized * normalized * normalized * axisExpo;
    return clamped.sign * curved;
  }
}
