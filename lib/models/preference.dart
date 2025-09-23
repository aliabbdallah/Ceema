class Preference {
  final String id;
  final String type; // 'genre', 'actor', 'director'
  final String name;
  final double weight;

  Preference({
    required this.id,
    required this.type,
    required this.name,
    required this.weight,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'name': name,
    'weight': weight,
  };

  factory Preference.fromJson(Map<String, dynamic> json) => Preference(
    id: json['id'] as String,
    type: json['type'] as String,
    name: json['name'] as String,
    weight:
        (json['weight'] is int)
            ? (json['weight'] as int).toDouble()
            : (json['weight'] as num).toDouble(),
  );
}
