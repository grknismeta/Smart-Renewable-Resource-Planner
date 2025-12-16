class Scenario {
  final int id;
  final String name;
  final String? description;
  final int pinId;
  final int ownerId;
  final DateTime startDate;
  final DateTime endDate;
  final Map<String, dynamic>? resultData;
  final DateTime? createdAt;

  Scenario({
    required this.id,
    required this.name,
    this.description,
    required this.pinId,
    required this.ownerId,
    required this.startDate,
    required this.endDate,
    this.resultData,
    this.createdAt,
  });

  factory Scenario.fromJson(Map<String, dynamic> json) {
    return Scenario(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      pinId: json['pin_id'] as int,
      ownerId: json['owner_id'] as int,
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      resultData: json['result_data'] as Map<String, dynamic>?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'pin_id': pinId,
      'owner_id': ownerId,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'result_data': resultData,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class ScenarioCreate {
  final String name;
  final String? description;
  final int pinId;
  final DateTime startDate;
  final DateTime endDate;

  ScenarioCreate({
    required this.name,
    this.description,
    required this.pinId,
    required this.startDate,
    required this.endDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'pin_id': pinId,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
    };
  }
}
