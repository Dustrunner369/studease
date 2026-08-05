import 'dart:convert';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:mobile/design/theme.dart';
import 'package:mobile/models/spot.dart';

/// Where the API lives.
///
/// The Android emulator can't see the host's `localhost` — 10.0.2.2 is how it refers
/// to the machine running it. Override either with `--dart-define=API_BASE_URL=...`
/// when pointing at a deployed backend.
String get baseUrl {
  const override = String.fromEnvironment('API_BASE_URL');
  if (override.isNotEmpty) return override;

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:5001';
  }

  return 'http://localhost:5001';
}

const Map<String, String> _jsonHeaders = {
  'Accept': 'application/json',
  'Content-Type': 'application/json',
};

/// A failed request, carrying a message worth showing the user.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  /// The server has no Google Places key configured, so search is switched off.
  /// The add-spot sheet uses this to fall back to typing a spot in by hand.
  bool get isPlacesUnavailable => statusCode == 503;

  @override
  String toString() => message;
}

/// The ranked Spots tab: my entries, best first.
Future<List<MySpotListItem>> fetchMySpots() async {
  final data = await _send(() => http.get(Uri.parse('$baseUrl/me/spots'), headers: _jsonHeaders));

  return (data as List<dynamic>)
      .map((item) => MySpotListItem.fromJson(item as Map<String, dynamic>))
      .toList();
}

/// Everything about one place, including hours fetched live from Google.
Future<SpotDetail> fetchSpot(String spotId) async {
  final data = await _send(() => http.get(Uri.parse('$baseUrl/spots/$spotId'), headers: _jsonHeaders));

  return SpotDetail.fromJson(data as Map<String, dynamic>);
}

/// Google Places autocomplete, proxied so the API key stays on the server.
Future<List<PlaceSuggestion>> searchPlaces(String query) async {
  final uri = Uri.parse('$baseUrl/places/search').replace(queryParameters: {'q': query});
  final data = await _send(() => http.get(uri, headers: _jsonHeaders));

  return (data as List<dynamic>)
      .map((item) => PlaceSuggestion.fromJson(item as Map<String, dynamic>))
      .toList();
}

/// Creates a spot, or returns the existing one if this place is already known.
///
/// Pass [googlePlaceId] for a real place; pass [name] to enter one by hand when
/// Google doesn't know about it (campus study rooms usually don't exist in Places).
Future<SpotDetail> createSpot({
  String? googlePlaceId,
  String? name,
  String? address,
  required SpotType type,
}) async {
  final data = await _send(() => http.post(
        Uri.parse('$baseUrl/spots'),
        headers: _jsonHeaders,
        body: json.encode({
          'googlePlaceId': googlePlaceId,
          'name': name,
          'address': address,
          'type': type.api,
        }),
      ));

  return SpotDetail.fromJson(data as Map<String, dynamic>);
}

/// Saves my rating of a spot. Rating a place twice updates the same entry rather
/// than adding a second one, so this doubles as the edit call.
Future<SpotEntry> saveEntry({
  required String spotId,
  required Ratings ratings,
  bool groupStudy = false,
  String? coffeeOrder,
  String? notes,
}) async {
  final data = await _send(() => http.put(
        Uri.parse('$baseUrl/spots/$spotId/entry'),
        headers: _jsonHeaders,
        body: json.encode({
          'ratings': ratings.toJson(),
          'groupStudy': groupStudy,
          'coffeeOrder': coffeeOrder,
          'notes': notes,
        }),
      ));

  return SpotEntry.fromJson(data as Map<String, dynamic>);
}

/// Removes my rating. The spot survives — someone else may have rated it too.
Future<void> deleteEntry(String spotId) async {
  await _send(() => http.delete(Uri.parse('$baseUrl/spots/$spotId/entry'), headers: _jsonHeaders));
}

Future<dynamic> _send(Future<http.Response> Function() request) async {
  final http.Response response;

  try {
    response = await request();
  } catch (_) {
    throw ApiException('Could not reach the server. Is the API running at $baseUrl?');
  }

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw ApiException(_messageFrom(response), statusCode: response.statusCode);
  }

  if (response.body.isEmpty) return null;

  return json.decode(response.body);
}

/// The API returns RFC 9457 problem+json, so pull the useful sentence out of it
/// rather than showing the user a status code.
String _messageFrom(http.Response response) {
  try {
    final body = json.decode(response.body);

    if (body is Map<String, dynamic>) {
      final errors = body['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
      }

      for (final key in ['detail', 'title']) {
        final value = body[key];
        if (value is String && value.isNotEmpty) return value;
      }
    }
  } catch (_) {
    // Not JSON, or not the shape we expected — fall through to the generic message.
  }

  return 'Request failed (${response.statusCode}).';
}
