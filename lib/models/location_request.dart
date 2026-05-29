enum LocationRequestStatus { pending, completed, expired, rejected }

class LocationRequest {
  final String id;
  final String token;
  final String requesterId;
  final double requesterLat;
  final double requesterLng;
  final double? responderLat;
  final double? responderLng;
  final String? responderPhone;
  final String? requesterPhone;
  final LocationRequestStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;

  const LocationRequest({
    required this.id,
    required this.token,
    required this.requesterId,
    required this.requesterLat,
    required this.requesterLng,
    this.responderLat,
    this.responderLng,
    this.responderPhone,
    this.requesterPhone,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get hasResponderLocation =>
      responderLat != null && responderLng != null;

  factory LocationRequest.fromJson(Map<String, dynamic> json) {
    return LocationRequest(
      id: json['id'] as String,
      token: json['token'] as String,
      requesterId: json['requester_id'] as String,
      requesterLat: (json['requester_lat'] as num).toDouble(),
      requesterLng: (json['requester_lng'] as num).toDouble(),
      responderLat: (json['responder_lat'] as num?)?.toDouble(),
      responderLng: (json['responder_lng'] as num?)?.toDouble(),
      responderPhone: json['responder_phone'] as String?,
      requesterPhone: json['requester_phone'] as String?,
      status: _parseStatus(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  static LocationRequestStatus _parseStatus(String s) {
    switch (s) {
      case 'completed':
        return LocationRequestStatus.completed;
      case 'expired':
        return LocationRequestStatus.expired;
      case 'rejected':
        return LocationRequestStatus.rejected;
      default:
        return LocationRequestStatus.pending;
    }
  }
}
