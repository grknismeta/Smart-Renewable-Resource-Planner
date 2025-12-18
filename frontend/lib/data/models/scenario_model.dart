import 'dart:convert';

class Scenario {
  final int id;
  final String name;
  final String? description;
  final List<int> pinIds;
  // Geriye dönük uyumluluk
  final int? pinId;
  final int ownerId;
  final DateTime? startDate;
  final DateTime? endDate;
  final Map<String, dynamic>? resultData;
  final DateTime? createdAt;

  Scenario({
    required this.id,
    required this.name,
    this.description,
    this.pinIds = const [],
    this.pinId,
    required this.ownerId,
    this.startDate,
    this.endDate,
    this.resultData,
    this.createdAt,
  });

  factory Scenario.fromJson(Map<String, dynamic> json) {
    // pin_ids güvenli şekilde parse et
    List<int> pinIds = [];
    if (json['pin_ids'] != null) {
      final pinIdsRaw = json['pin_ids'];
      if (pinIdsRaw is List) {
        pinIds = List<int>.from(
          pinIdsRaw.map((e) => e is int ? e : int.parse(e.toString())),
        );
      } else if (pinIdsRaw is String) {
        // JSON string ise parse et
        try {
          final decoded = jsonDecode(pinIdsRaw);
          if (decoded is List) {
            pinIds = List<int>.from(
              decoded.map((e) => e is int ? e : int.parse(e.toString())),
            );
          }
        } catch (e) {
          print('pin_ids parse hatası: $e');
        }
      }
    }

    return Scenario(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      pinIds: pinIds,
      pinId: json['pin_id'] as int?,
      ownerId: json['owner_id'] as int,
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      resultData: json['result_data'] != null
          ? Map<String, dynamic>.from(json['result_data'] as Map)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'pin_ids': pinIds,
      'pin_id': pinId,
      'owner_id': ownerId,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'result_data': resultData,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class ScenarioCreate {
  final String name;
  final String? description;
  final List<int> pinIds;
  final DateTime? startDate;
  final DateTime? endDate;

  ScenarioCreate({
    required this.name,
    this.description,
    this.pinIds = const [],
    this.startDate,
    this.endDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'pin_ids': pinIds,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
    };
  }
}
