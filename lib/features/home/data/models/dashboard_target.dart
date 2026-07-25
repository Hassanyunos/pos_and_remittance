class DashboardTarget {
  const DashboardTarget({
    this.id,
    required this.name,
    required this.dailyTarget,
  });

  final int? id;
  final String name;
  final double dailyTarget;

  factory DashboardTarget.fromMap(Map<String, Object?> map) => DashboardTarget(
        id: map['id'] as int?,
        name: map['name'] as String,
        dailyTarget: (map['daily_target'] as num).toDouble(),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'daily_target': dailyTarget,
      };

  DashboardTarget copyWith({int? id, String? name, double? dailyTarget}) => DashboardTarget(
        id: id ?? this.id,
        name: name ?? this.name,
        dailyTarget: dailyTarget ?? this.dailyTarget,
      );
}
