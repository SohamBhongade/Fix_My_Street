import 'package:mongo_dart/mongo_dart.dart' as mongo;

enum ReportStatus { pending, inProgress, fixed }

extension ReportStatusX on ReportStatus {
  String get label {
    switch (this) {
      case ReportStatus.pending:
        return 'Pending';
      case ReportStatus.inProgress:
        return 'In Progress';
      case ReportStatus.fixed:
        return 'Fixed';
    }
  }

  String get wire => name;

  static ReportStatus fromWire(String? s) {
    switch (s) {
      case 'inProgress':
        return ReportStatus.inProgress;
      case 'fixed':
        return ReportStatus.fixed;
      case 'pending':
      default:
        return ReportStatus.pending;
    }
  }
}

enum ReportPriority {
  low,
  medium,
  high;

  static ReportPriority fromSeverity(int severity) {
    if (severity >= 7) return ReportPriority.high;
    if (severity >= 4) return ReportPriority.medium;
    return ReportPriority.low;
  }
}

extension ReportPriorityX on ReportPriority {
  String get label {
    switch (this) {
      case ReportPriority.low:
        return 'Low';
      case ReportPriority.medium:
        return 'Medium';
      case ReportPriority.high:
        return 'High';
    }
  }

  String get wire => name;

  static ReportPriority fromWire(String? s) {
    switch (s) {
      case 'high':
        return ReportPriority.high;
      case 'medium':
        return ReportPriority.medium;
      case 'low':
      default:
        return ReportPriority.low;
    }
  }
}

class ReportModel {
  /// Mongo `_id` — null until persisted.
  final mongo.ObjectId? id;
  final String category;
  final int severity;
  final ReportPriority priority;
  final String description;
  final double latitude;
  final double longitude;
  final String address;
  final String? imageBase64;
  final ReportStatus status;
  final DateTime createdAt;
  final DateTime? fixedAt;

  const ReportModel({
    this.id,
    required this.category,
    required this.severity,
    required this.priority,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.address,
    this.imageBase64,
    this.status = ReportStatus.pending,
    required this.createdAt,
    this.fixedAt,
  });

  ReportModel copyWith({
    mongo.ObjectId? id,
    ReportPriority? priority,
    ReportStatus? status,
    DateTime? fixedAt,
  }) =>
      ReportModel(
        id: id ?? this.id,
        category: category,
        severity: severity,
        priority: priority ?? this.priority,
        description: description,
        latitude: latitude,
        longitude: longitude,
        address: address,
        imageBase64: imageBase64,
        status: status ?? this.status,
        createdAt: createdAt,
        fixedAt: fixedAt ?? this.fixedAt,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) '_id': id,
        'category': category,
        'severity': severity,
        'priority': priority.wire,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'imageBase64': imageBase64,
        'status': status.wire,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'fixedAt': fixedAt?.toUtc().toIso8601String(),
      };

  factory ReportModel.fromMap(Map<String, dynamic> m) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString()) ?? DateTime.now();
    }

    final severity = (m['severity'] is num)
        ? (m['severity'] as num).toInt()
        : int.tryParse('${m['severity']}') ?? 1;

    return ReportModel(
      id: m['_id'] is mongo.ObjectId ? m['_id'] as mongo.ObjectId : null,
      category: (m['category'] ?? 'Unknown').toString(),
      severity: severity,
      priority: m['priority'] == null
          ? ReportPriority.fromSeverity(severity)
          : ReportPriorityX.fromWire(m['priority'] as String?),
      description: (m['description'] ?? '').toString(),
      latitude: (m['latitude'] is num)
          ? (m['latitude'] as num).toDouble()
          : double.tryParse('${m['latitude']}') ?? 0.0,
      longitude: (m['longitude'] is num)
          ? (m['longitude'] as num).toDouble()
          : double.tryParse('${m['longitude']}') ?? 0.0,
      address: (m['address'] ?? '').toString(),
      imageBase64: m['imageBase64'] as String?,
      status: ReportStatusX.fromWire(m['status'] as String?),
      createdAt: parseDate(m['createdAt']),
      fixedAt: m['fixedAt'] == null ? null : parseDate(m['fixedAt']),
    );
  }
}
