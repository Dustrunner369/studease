import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/design/theme.dart';
import 'package:mobile/models/spot.dart';

void main() {
  group('MySpotListItem.fromJson', () {
    final json = {
      'spotId': '018f0000-0000-7000-8000-000000000001',
      'entryId': '018f0000-0000-7000-8000-000000000002',
      'name': 'Brew & Books',
      'address': '123 Library Lane, Booktown',
      'type': 'cafe',
      'score': 8.4,
      'ratings': {'wifi': 4, 'noise': 5, 'outlets': 4, 'seating': 4, 'coffee': 4},
      'priceLevel': 2,
      'coffeeOrder': 'Vanilla latte',
      'notes': 'Quiet back room',
      'updatedAt': '2026-07-25T18:03:11Z',
    };

    test('parses a full row', () {
      final item = MySpotListItem.fromJson(json);

      expect(item.name, 'Brew & Books');
      expect(item.type, SpotType.cafe);
      expect(item.score, 8.4);
      expect(item.ratings.noise, 5);
      expect(item.priceLevel, 2);
    });

    test('tolerates missing optional fields', () {
      final sparse = Map<String, dynamic>.from(json)
        ..['address'] = null
        ..['priceLevel'] = null
        ..['coffeeOrder'] = null
        ..['notes'] = null;

      final item = MySpotListItem.fromJson(sparse);

      expect(item.address, isNull);
      expect(item.priceLevel, isNull);
      expect(item.coffeeOrder, isNull);
      expect(item.notes, isNull);
    });
  });

  group('SpotDetail.fromJson', () {
    Map<String, dynamic> detail({Object? openUntil, Object? isOpenNow}) => {
          'id': '018f0000-0000-7000-8000-000000000001',
          'googlePlaceId': 'ChIJN1t_tDeuEmsRUsoyG83frY4',
          'name': 'Brew & Books',
          'address': '123 Library Lane',
          'type': 'library',
          'priceLevel': null,
          'websiteUrl': null,
          'phone': null,
          'openUntil': openUntil,
          'isOpenNow': isOpenNow,
          'hoursUnavailable': openUntil == null,
          'entryCount': 1,
          'avgScore': 8.4,
          'myEntry': null,
        };

    // Hours come from Google at request time, so they're absent whenever Google has
    // none or the lookup failed. Parsing must not throw on that — the old model
    // required openUntil to be a String and blew up with a FormatException.
    test('parses a spot with no opening hours', () {
      final spot = SpotDetail.fromJson(detail());

      expect(spot.openUntil, isNull);
      expect(spot.isOpenNow, isNull);
      expect(spot.hoursUnavailable, isTrue);
      expect(spot.type, SpotType.library);
    });

    test('parses a spot with opening hours', () {
      final spot = SpotDetail.fromJson(detail(openUntil: '22:00', isOpenNow: true));

      expect(spot.openUntil, '22:00');
      expect(spot.isOpenNow, isTrue);
      expect(spot.hoursUnavailable, isFalse);
    });
  });

  group('spotTypeFromApi', () {
    test('maps every type the API can send', () {
      expect(spotTypeFromApi('cafe'), SpotType.cafe);
      expect(spotTypeFromApi('library'), SpotType.library);
      expect(spotTypeFromApi('campus'), SpotType.campus);
      expect(spotTypeFromApi('other'), SpotType.other);
    });

    test('falls back to cafe rather than throwing on an unknown type', () {
      expect(spotTypeFromApi('spaceship'), SpotType.cafe);
      expect(spotTypeFromApi(null), SpotType.cafe);
    });
  });

  group('levelFor', () {
    test('buckets a 1-5 rating', () {
      expect(levelFor(5), Level.good);
      expect(levelFor(4), Level.good);
      expect(levelFor(3), Level.ok);
      expect(levelFor(2), Level.rough);
      expect(levelFor(1), Level.rough);
    });
  });
}
