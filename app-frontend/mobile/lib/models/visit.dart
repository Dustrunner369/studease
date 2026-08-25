/// One "I'm studying here today" log entry — separate from [SpotEntry]: unlimited per
/// spot, never edited once created, carries no rating. Deletable (via api_service's
/// deleteVisit) to undo a mislog. See context/data-model.md D12.
class Visit {
  final String id;
  final String spotId;
  final String spotName;
  final String? studied;
  final String? drinkOrder;
  final DateTime visitedAt;

  const Visit({
    required this.id,
    required this.spotId,
    required this.spotName,
    required this.studied,
    required this.drinkOrder,
    required this.visitedAt,
  });

  factory Visit.fromJson(Map<String, dynamic> json) => Visit(
        id: json['id'] as String,
        spotId: json['spotId'] as String,
        spotName: json['spotName'] as String,
        studied: json['studied'] as String?,
        drinkOrder: json['drinkOrder'] as String?,
        visitedAt: DateTime.parse(json['visitedAt'] as String),
      );
}
