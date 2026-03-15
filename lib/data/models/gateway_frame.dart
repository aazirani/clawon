/// Frame types for OpenClaw Gateway Protocol v3
enum FrameType { req, res, event }

/// Base frame with type discriminator
class GatewayFrame {
  final FrameType type;
  final String? id; // For req/res
  final String? method; // For req
  final Map<String, dynamic>? params; // For req
  final bool? ok; // For res
  final Map<String, dynamic>? payload; // For res
  final Map<String, dynamic>? error; // For res
  final String? event; // For event
  final int? seq; // For event
  final Map<String, dynamic>? stateVersion; // For event

  GatewayFrame({
    required this.type,
    this.id,
    this.method,
    this.params,
    this.ok,
    this.payload,
    this.error,
    this.event,
    this.seq,
    this.stateVersion,
  });

  factory GatewayFrame.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String;
    final type = FrameType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => throw ArgumentError('Unknown frame type: $typeStr'),
    );

    return GatewayFrame(
      type: type,
      id: json['id'] as String?,
      method: json['method'] as String?,
      params: json['params'] as Map<String, dynamic>?,
      ok: json['ok'] as bool?,
      payload: json['payload'] as Map<String, dynamic>?,
      error: json['error'] as Map<String, dynamic>?,
      event: json['event'] as String?,
      seq: json['seq'] as int?,
      stateVersion: json['stateVersion'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      if (id != null) 'id': id,
      if (method != null) 'method': method,
      if (params != null) 'params': params,
      if (ok != null) 'ok': ok,
      if (payload != null) 'payload': payload,
      if (error != null) 'error': error,
      if (event != null) 'event': event,
      if (seq != null) 'seq': seq,
      if (stateVersion != null) 'stateVersion': stateVersion,
    };
  }

  // Helper to create request frame
  static GatewayFrame request({
    required String id,
    required String method,
    Map<String, dynamic>? params,
  }) {
    return GatewayFrame(
      type: FrameType.req,
      id: id,
      method: method,
      params: params,
    );
  }
}
