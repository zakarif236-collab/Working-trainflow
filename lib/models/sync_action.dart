class SyncAction {
  final String type;
  final Map<String, dynamic> params;
  final DateTime createdAt;

  SyncAction({
    required this.type,
    required this.params,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'type': type,
    'params': params,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory SyncAction.fromJson(Map<String, dynamic> json) => SyncAction(
    type: json['type'] as String,
    params: Map<String, dynamic>.from(json['params'] as Map),
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (json['createdAt'] as num).toInt(),
    ),
  );
}
