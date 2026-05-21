import 'package:mongo_dart/mongo_dart.dart' as mongo;

/// Lifecycle of a report:
///   open                  — newly filed, no one assigned yet.
///   inProgress            — a volunteer (or admin acting as one) has picked
///                           it up and the work is happening.
///   pendingVerification   — the volunteer uploaded a proof image and now
///                           waits for an admin to inspect + sign off.
///   resolved              — admin verified the proof and closed the ticket.
enum ReportStatus { open, inProgress, pendingVerification, resolved }

extension ReportStatusX on ReportStatus {
  String get label {
    switch (this) {
      case ReportStatus.open:
        return 'Open';
      case ReportStatus.inProgress:
        return 'In Progress';
      case ReportStatus.pendingVerification:
        return 'Pending Verification';
      case ReportStatus.resolved:
        return 'Resolved';
    }
  }

  /// Mongo wire string. Exact values required by the verification pipeline
  /// spec: "open" / "in_progress" / "pending_verification" / "resolved".
  String get wire {
    switch (this) {
      case ReportStatus.open:
        return 'open';
      case ReportStatus.inProgress:
        return 'in_progress';
      case ReportStatus.pendingVerification:
        return 'pending_verification';
      case ReportStatus.resolved:
        return 'resolved';
    }
  }

  /// Parses the spec'd wire strings plus the older legacy values
  /// ("pending" / "inProgress" / "fixed") so reports written before the
  /// schema migration still deserialize cleanly.
  static ReportStatus fromWire(String? s) {
    switch (s) {
      case 'open':
      case 'pending':
        return ReportStatus.open;
      case 'in_progress':
      case 'inProgress':
        return ReportStatus.inProgress;
      case 'pending_verification':
        return ReportStatus.pendingVerification;
      case 'resolved':
      case 'fixed':
        return ReportStatus.resolved;
      default:
        return ReportStatus.open;
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

  /// Identifier of the user who volunteered for this task. Null until
  /// someone is assigned. Stored as a plain string (username) for parity
  /// with the existing auth layer; the schema also tolerates an ObjectId
  /// via [fromMap].
  final String? assignedVolunteerId;

  /// Volunteer's proof-of-work image, stored as a data URI (or raw base64)
  /// matching the imageBase64 convention. Null until the volunteer submits
  /// completion proof.
  final String? proofOfWorkImageUrl;

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
    this.status = ReportStatus.open,
    required this.createdAt,
    this.fixedAt,
    this.assignedVolunteerId,
    this.proofOfWorkImageUrl,
  });

  ReportModel copyWith({
    mongo.ObjectId? id,
    ReportPriority? priority,
    ReportStatus? status,
    DateTime? fixedAt,
    String? assignedVolunteerId,
    String? proofOfWorkImageUrl,
    bool clearAssignedVolunteer = false,
    bool clearProofOfWork = false,
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
        assignedVolunteerId: clearAssignedVolunteer
            ? null
            : (assignedVolunteerId ?? this.assignedVolunteerId),
        proofOfWorkImageUrl: clearProofOfWork
            ? null
            : (proofOfWorkImageUrl ?? this.proofOfWorkImageUrl),
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
        'assignedVolunteerId': assignedVolunteerId,
        'proofOfWorkImageUrl': proofOfWorkImageUrl,
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

    final rawAssignee = m['assignedVolunteerId'];
    final String? assignee = rawAssignee == null
        ? null
        : (rawAssignee is mongo.ObjectId
            ? rawAssignee.oid
            : rawAssignee.toString());

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
      assignedVolunteerId: assignee,
      proofOfWorkImageUrl: m['proofOfWorkImageUrl'] as String?,
    );
  }
}
