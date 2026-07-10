class StudySpot {
  final int spotId;
  final String? name;
  final String? address;
  final bool hasCharging;
  final int seating;
  final int coffeeQuality;
  final String? generalPrice;
  final DateTime openUntil;
  final String? drinkOrder;
  final String? extraNotes;

  const StudySpot({    
    required this.spotId,
    this.name,
    this.address,
    required this.hasCharging,
    required this.seating,
    required this.coffeeQuality,
    this.generalPrice,
    required this.openUntil,
    this.drinkOrder,
    this.extraNotes
  });

  factory StudySpot.fromJson(Map<String, dynamic> json) {    
    List<StudySpot> studySpotList;
    
    // TODO - Loop through every study spot and create the list
    return switch (json) {
      {
        'id': int spotId,
        'name': String name,
        'address': String address,
        'hasCharging': bool hasCharging,
        'seating': int seating,
        'coffeeQuality': int coffeeQuality,
        'generalPrice': String generalPrice,
        'openUntil': DateTime openUntil,
        'drinkOrder': String drinkOrder,
        'extraNotes': String extraNotes
      } => StudySpot(        
        spotId: spotId,
        name: name,
        address: address,
        hasCharging: hasCharging,
        seating: seating,
        coffeeQuality: coffeeQuality,
        generalPrice: generalPrice,
        openUntil: openUntil,
        drinkOrder: drinkOrder,
        extraNotes: extraNotes,
      ),
      _ => throw const FormatException('Failed to load study spot.'), 
    };
  }
}