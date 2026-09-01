import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:mobile/models/label.dart';
import 'package:mobile/models/me.dart';
import 'package:mobile/models/spot.dart';
import 'package:mobile/models/visit.dart';

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

const _registrationRequiredType = 'https://studease.app/problems/registration-required';
const _entryLimitReachedType = 'https://studease.app/problems/entry-limit-reached';

/// A failed request, carrying a message worth showing the user.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  /// RFC 9457 `type`, when the server sent one — a status code alone can't tell two
  /// different 403s apart.
  final String? problemType;

  const ApiException(this.message, {this.statusCode, this.problemType});

  /// The server has no Google Places key configured, so search is switched off.
  /// The add-spot sheet uses this to fall back to typing a spot in by hand.
  bool get isPlacesUnavailable => statusCode == 503;

  /// A valid token, but no users row yet. Shouldn't happen in this app's own flow —
  /// every client is anonymous-then-linked — but a stray direct sign-up would land here.
  bool get needsRegistration => problemType == _registrationRequiredType;

  /// A guest tried to add a fourth spot. The caller should offer account creation.
  bool get isGuestLimitReached => problemType == _entryLimitReachedType;

  @override
  String toString() => message;
}

/// Every call is authenticated: a guest's Firebase anonymous session carries a real ID
/// token same as a registered user's, so the token attaches the same way either way.
Future<Map<String, String>> _headers({bool forceRefresh = false}) async {
  final token = await FirebaseAuth.instance.currentUser?.getIdToken(forceRefresh);

  return {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
}

/// The client's boot call, and the source of truth for isGuest/entryCount.
Future<Me> fetchMe() async {
  final data = await _send((headers) => http.get(Uri.parse('$baseUrl/me'), headers: headers));

  return Me.fromJson(data as Map<String, dynamic>);
}

/// Completes registration: a fresh identity, or a guest upgrading in place.
Future<Me> registerMe({required String handle, required String displayName}) async {
  final data = await _send((headers) => http.post(
        Uri.parse('$baseUrl/me'),
        headers: headers,
        body: json.encode({'handle': handle, 'displayName': displayName}),
      ));

  return Me.fromJson(data as Map<String, dynamic>);
}

/// Sets my preset profile icon, accent color, and whether the background is tinted
/// to match. [avatarId] must be one of design/illustrations.dart's avatarIconIds, or
/// null to revert to the display-name-initial fallback; [colorSlug] must be one of
/// design/theme.dart's avatarColorPalette slugs or null — the server 400s otherwise
/// either way.
Future<Me> setAvatar(String? avatarId, {String? colorSlug, bool backgroundTint = false}) async {
  final data = await _send((headers) => http.put(
        Uri.parse('$baseUrl/me/avatar'),
        headers: headers,
        body: json.encode({
          'avatarId': avatarId,
          'avatarColor': colorSlug,
          'avatarBackgroundTint': backgroundTint,
        }),
      ));

  return Me.fromJson(data as Map<String, dynamic>);
}

/// The ranked Spots tab: my entries, best first.
Future<List<MySpotListItem>> fetchMySpots() async {
  final data =
      await _send((headers) => http.get(Uri.parse('$baseUrl/me/spots'), headers: headers));

  return (data as List<dynamic>)
      .map((item) => MySpotListItem.fromJson(item as Map<String, dynamic>))
      .toList();
}

/// Everything about one place, including hours fetched live from Google.
Future<SpotDetail> fetchSpot(String spotId) async {
  final data =
      await _send((headers) => http.get(Uri.parse('$baseUrl/spots/$spotId'), headers: headers));

  return SpotDetail.fromJson(data as Map<String, dynamic>);
}

/// Google Places autocomplete, proxied so the API key stays on the server.
Future<List<PlaceSuggestion>> searchPlaces(String query) async {
  final uri = Uri.parse('$baseUrl/places/search').replace(queryParameters: {'q': query});
  final data = await _send((headers) => http.get(uri, headers: headers));

  return (data as List<dynamic>)
      .map((item) => PlaceSuggestion.fromJson(item as Map<String, dynamic>))
      .toList();
}

/// Creates a spot, or returns the existing one if this place is already known.
///
/// Pass [googlePlaceId] for a real place; pass [name] to enter one by hand when
/// Google doesn't know about it (campus study rooms usually don't exist in Places).
/// No category — spots aren't typed anymore, see the tag/label system below.
Future<SpotDetail> createSpot({
  String? googlePlaceId,
  String? name,
  String? address,
}) async {
  final data = await _send((headers) => http.post(
        Uri.parse('$baseUrl/spots'),
        headers: headers,
        body: json.encode({
          'googlePlaceId': googlePlaceId,
          'name': name,
          'address': address,
        }),
      ));

  return SpotDetail.fromJson(data as Map<String, dynamic>);
}

/// Corrects a spot's own name/address — the shared record, not any one entry. Used
/// by the edit-spot flow, most often to add an address a manually-entered spot never
/// had. Doesn't touch googlePlaceId or coordinates; only a fresh Places lookup can.
Future<SpotDetail> updateSpot({
  required String spotId,
  required String name,
  String? address,
}) async {
  final data = await _send((headers) => http.put(
        Uri.parse('$baseUrl/spots/$spotId'),
        headers: headers,
        body: json.encode({'name': name, 'address': address}),
      ));

  return SpotDetail.fromJson(data as Map<String, dynamic>);
}

/// Saves my rating of a spot. Rating a place twice updates the same entry rather
/// than adding a second one, so this doubles as the edit call.
///
/// Guests get a 403 (ApiException.isGuestLimitReached) past their third *new* spot —
/// re-rating a spot already rated never counts against the cap. Every slug in
/// [tagSlugs] must resolve to an approved label or the whole write 400s.
Future<SpotEntry> saveEntry({
  required String spotId,
  required Ratings ratings,
  bool groupStudy = false,
  List<String> tagSlugs = const [],
  String? coffeeOrder,
  String? notes,
}) async {
  final data = await _send((headers) => http.put(
        Uri.parse('$baseUrl/spots/$spotId/entry'),
        headers: headers,
        body: json.encode({
          'ratings': ratings.toJson(),
          'groupStudy': groupStudy,
          'tagSlugs': tagSlugs,
          'coffeeOrder': coffeeOrder,
          'notes': notes,
        }),
      ));

  return SpotEntry.fromJson(data as Map<String, dynamic>);
}

/// Removes my rating. The spot survives — someone else may have rated it too.
Future<void> deleteEntry(String spotId) async {
  await _send((headers) => http.delete(Uri.parse('$baseUrl/spots/$spotId/entry'), headers: headers));
}

/// Logs "I'm studying here today". Requires an existing rating on [spotId] — the
/// server 403s otherwise, though the UI never offers this call without one already
/// in hand (the detail sheet that triggers it only opens for spots you've rated).
Future<Visit> logVisit({required String spotId, String? studied, String? drinkOrder}) async {
  final data = await _send((headers) => http.post(
        Uri.parse('$baseUrl/spots/$spotId/visits'),
        headers: headers,
        body: json.encode({'studied': studied, 'drinkOrder': drinkOrder}),
      ));

  return Visit.fromJson(data as Map<String, dynamic>);
}

/// Undoes a mislogged visit — the one mutation visits allow (see Visit's doc comment).
/// Doesn't touch the rating at [spotId], only this one log entry.
Future<void> deleteVisit({required String spotId, required String visitId}) async {
  await _send(
      (headers) => http.delete(Uri.parse('$baseUrl/spots/$spotId/visits/$visitId'), headers: headers));
}

/// My past visits to one spot, newest first. Backs the detail sheet's "Past visits".
Future<List<Visit>> fetchSpotVisits(String spotId) async {
  final data = await _send(
      (headers) => http.get(Uri.parse('$baseUrl/spots/$spotId/visits'), headers: headers));

  return (data as List<dynamic>)
      .map((item) => Visit.fromJson(item as Map<String, dynamic>))
      .toList();
}

/// Every spot I've logged a visit at, newest first. Backs the Profile tab's study
/// history.
Future<List<Visit>> fetchMyVisits() async {
  final data =
      await _send((headers) => http.get(Uri.parse('$baseUrl/me/visits'), headers: headers));

  return (data as List<dynamic>)
      .map((item) => Visit.fromJson(item as Map<String, dynamic>))
      .toList();
}

/// The tag picker's data source: only the standardized, moderated vocabulary.
Future<List<Label>> fetchLabels() async {
  final data = await _send((headers) => http.get(Uri.parse('$baseUrl/labels'), headers: headers));

  return (data as List<dynamic>)
      .map((item) => Label.fromJson(item as Map<String, dynamic>))
      .toList();
}

/// Proposes a new tag. Returns immediately usable if it dedupes to an
/// already-approved label; otherwise it's pending until an admin reviews it.
Future<Label> requestLabel(String name) async {
  final data = await _send((headers) => http.post(
        Uri.parse('$baseUrl/labels'),
        headers: headers,
        body: json.encode({'name': name}),
      ));

  return Label.fromJson(data as Map<String, dynamic>);
}

/// Emails the submission straight to the developer - see backend FeedbackMailer.
/// [type] must be one of FeedbackPage's feedback type slugs ('bug', 'feature_request',
/// 'other').
Future<void> submitFeedback({required String type, required String message}) async {
  await _send((headers) => http.post(
        Uri.parse('$baseUrl/feedback'),
        headers: headers,
        body: json.encode({'type': type, 'message': message}),
      ));
}

/// Permanently deletes the caller's account and all their data server-side. Must be
/// called while still signed in (needs a valid token) - AuthController.deleteAccount
/// calls this before deleting the underlying Firebase user, since currentUser goes null
/// (and with it, any way to get a fresh token) the moment that happens. Named distinctly
/// from AuthController.deleteAccount (not just `deleteAccount`) since that method calls
/// this one - same name would resolve to itself instead, as an unqualified call favors
/// the instance method over the top-level function.
Future<void> deleteAccountData() async {
  await _send((headers) => http.delete(Uri.parse('$baseUrl/me'), headers: headers));
}

Future<dynamic> _send(Future<http.Response> Function(Map<String, String> headers) request) async {
  var response = await _attempt(request, forceRefresh: false);

  // The cached ID token can expire between requests; refresh once and retry before
  // giving up. A second 401 after a forced refresh is a real auth failure.
  if (response.statusCode == 401 && FirebaseAuth.instance.currentUser != null) {
    response = await _attempt(request, forceRefresh: true);
  }

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw ApiException(
      _messageFrom(response),
      statusCode: response.statusCode,
      problemType: _typeFrom(response),
    );
  }

  if (response.body.isEmpty) return null;

  return json.decode(response.body);
}

Future<http.Response> _attempt(
  Future<http.Response> Function(Map<String, String> headers) request, {
  required bool forceRefresh,
}) async {
  try {
    return await request(await _headers(forceRefresh: forceRefresh));
  } catch (_) {
    throw ApiException('Could not reach the server. Is the API running at $baseUrl?');
  }
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

String? _typeFrom(http.Response response) {
  try {
    final body = json.decode(response.body);
    if (body is Map<String, dynamic> && body['type'] is String) return body['type'] as String;
  } catch (_) {
    // Not JSON, or not the shape we expected.
  }

  return null;
}
