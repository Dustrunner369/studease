/// One entry in the standardized, global tag vocabulary — what the add-spot tag
/// picker offers and what "request a new tag" creates. [status] is always
/// `"approved"` when this comes from `GET /labels` (the only status that endpoint
/// returns); it's read after a request to decide the confirmation message.
///
/// [polarity] is `"positive"` or `"negative"` once approved — set by whoever
/// approves the request, never by the requester — and null while pending/rejected.
class Label {
  final String id;
  final String slug;
  final String displayName;
  final String status;
  final String? polarity;

  const Label({
    required this.id,
    required this.slug,
    required this.displayName,
    required this.status,
    this.polarity,
  });

  bool get isNegative => polarity == 'negative';

  factory Label.fromJson(Map<String, dynamic> json) => Label(
        id: json['id'] as String,
        slug: json['slug'] as String,
        displayName: json['displayName'] as String,
        status: json['status'] as String,
        polarity: json['polarity'] as String?,
      );
}
