class StudySpot {
  final int spotId;
  final String? name;
  final String? address;
  final bool hasCharging;
  final int seating;
  final int coffeeQuality;
  final String? generalPrice;
  final String openUntil;
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
    
    return switch (json) {
      {
        'id': int spotId,              
        'hasCharging': bool hasCharging,
        'seating': int seating,
        'coffeeQuality': int coffeeQuality,        
        'openUntil': String openUntil,
      } => StudySpot(        
        spotId: spotId,
        name: json["name"],
        address: json["address"],
        hasCharging: hasCharging,
        seating: seating,
        coffeeQuality: coffeeQuality,
        generalPrice: json["generalPrice"],
        openUntil: openUntil,
        drinkOrder: json["drinkOrder"],
        extraNotes: json["extraNotes"],
      ),
      _ => throw const FormatException('Failed to load study spot.'), 
    };
  }
  @override
  String toString() {    
    return "Name: $name \nAddress: $address \nhasCharging: $hasCharging \nopenUntil: $openUntil";
  }
}