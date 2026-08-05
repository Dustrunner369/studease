import 'package:mobile/design/theme.dart';

/// The five 1-5 ratings that make up a spot entry.
///
/// All of them read "higher is better" — including [noise], where 5 means *quiet*.
/// See context/data-model.md if that ever looks like a bug.
class Ratings {
  final int wifi;
  final int noise;
  final int outlets;
  final int seating;
  final int coffee;

  const Ratings({
    required this.wifi,
    required this.noise,
    required this.outlets,
    required this.seating,
    required this.coffee,
  });

  factory Ratings.fromJson(Map<String, dynamic> json) => Ratings(
        wifi: (json['wifi'] as num).toInt(),
        noise: (json['noise'] as num).toInt(),
        outlets: (json['outlets'] as num).toInt(),
        seating: (json['seating'] as num).toInt(),
        coffee: (json['coffee'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'wifi': wifi,
        'noise': noise,
        'outlets': outlets,
        'seating': seating,
        'coffee': coffee,
      };
}

/// One row of the ranked Spots tab: a place joined to my rating of it.
class MySpotListItem {
  final String spotId;
  final String entryId;
  final String name;
  final String? address;
  final SpotType type;
  final double score;
  final Ratings ratings;
  final int? priceLevel;
  final String? coffeeOrder;
  final String? notes;
  final DateTime updatedAt;

  const MySpotListItem({
    required this.spotId,
    required this.entryId,
    required this.name,
    required this.address,
    required this.type,
    required this.score,
    required this.ratings,
    required this.priceLevel,
    required this.coffeeOrder,
    required this.notes,
    required this.updatedAt,
  });

  factory MySpotListItem.fromJson(Map<String, dynamic> json) => MySpotListItem(
        spotId: json['spotId'] as String,
        entryId: json['entryId'] as String,
        name: json['name'] as String,
        address: json['address'] as String?,
        type: spotTypeFromApi(json['type'] as String?),
        score: (json['score'] as num).toDouble(),
        ratings: Ratings.fromJson(json['ratings'] as Map<String, dynamic>),
        priceLevel: (json['priceLevel'] as num?)?.toInt(),
        coffeeOrder: json['coffeeOrder'] as String?,
        notes: json['notes'] as String?,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

/// My rating of one spot.
class SpotEntry {
  final String id;
  final String spotId;
  final Ratings ratings;
  final double score;
  final String? coffeeOrder;
  final String? notes;

  const SpotEntry({
    required this.id,
    required this.spotId,
    required this.ratings,
    required this.score,
    required this.coffeeOrder,
    required this.notes,
  });

  factory SpotEntry.fromJson(Map<String, dynamic> json) => SpotEntry(
        id: json['id'] as String,
        spotId: json['spotId'] as String,
        ratings: Ratings.fromJson(json['ratings'] as Map<String, dynamic>),
        score: (json['score'] as num).toDouble(),
        coffeeOrder: json['coffeeOrder'] as String?,
        notes: json['notes'] as String?,
      );
}

/// Everything known about a place.
///
/// [openUntil] and [isOpenNow] are fetched live from Google Places while the request
/// is handled — they are never stored — so both are null whenever Google has no hours
/// or the lookup failed. [hoursUnavailable] tells those apart from "closed right now".
class SpotDetail {
  final String id;
  final String? googlePlaceId;
  final String name;
  final String? address;
  final SpotType type;
  final int? priceLevel;
  final String? websiteUrl;
  final String? phone;
  final String? openUntil;
  final bool? isOpenNow;
  final bool hoursUnavailable;
  final int entryCount;
  final double? avgScore;
  final SpotEntry? myEntry;

  const SpotDetail({
    required this.id,
    required this.googlePlaceId,
    required this.name,
    required this.address,
    required this.type,
    required this.priceLevel,
    required this.websiteUrl,
    required this.phone,
    required this.openUntil,
    required this.isOpenNow,
    required this.hoursUnavailable,
    required this.entryCount,
    required this.avgScore,
    required this.myEntry,
  });

  factory SpotDetail.fromJson(Map<String, dynamic> json) => SpotDetail(
        id: json['id'] as String,
        googlePlaceId: json['googlePlaceId'] as String?,
        name: json['name'] as String,
        address: json['address'] as String?,
        type: spotTypeFromApi(json['type'] as String?),
        priceLevel: (json['priceLevel'] as num?)?.toInt(),
        websiteUrl: json['websiteUrl'] as String?,
        phone: json['phone'] as String?,
        openUntil: json['openUntil'] as String?,
        isOpenNow: json['isOpenNow'] as bool?,
        hoursUnavailable: json['hoursUnavailable'] as bool? ?? true,
        entryCount: (json['entryCount'] as num?)?.toInt() ?? 0,
        avgScore: (json['avgScore'] as num?)?.toDouble(),
        myEntry: json['myEntry'] == null
            ? null
            : SpotEntry.fromJson(json['myEntry'] as Map<String, dynamic>),
      );
}

/// A Google Places autocomplete result, shown while searching for a spot to add.
class PlaceSuggestion {
  final String googlePlaceId;
  final String name;
  final String address;

  const PlaceSuggestion({
    required this.googlePlaceId,
    required this.name,
    required this.address,
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) => PlaceSuggestion(
        googlePlaceId: json['googlePlaceId'] as String,
        name: json['name'] as String,
        address: json['address'] as String? ?? '',
      );
}
