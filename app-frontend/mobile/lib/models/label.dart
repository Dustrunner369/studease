/// One entry in the standardized, global tag vocabulary — what the add-spot tag
/// picker offers and what "request a new tag" creates. [status] is always
/// `"approved"` when this comes from `GET /labels` (the only status that endpoint
/// returns); it's read after a request to decide the confirmation message.
class Label {
  final String id;
  final String slug;
  final String displayName;
  final String status;

  const Label({
    required this.id,
    required this.slug,
    required this.displayName,
    required this.status,
  });

  factory Label.fromJson(Map<String, dynamic> json) => Label(
        id: json['id'] as String,
        slug: json['slug'] as String,
        displayName: json['displayName'] as String,
        status: json['status'] as String,
      );
}
