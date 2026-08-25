// Limits the amount of entries a guest can create before needing to create an account.
// The server side version of this is found in Program.cs
const int guestEntryLimit = 3;

// Me is a user of the app. isGuest distinguishes between someone that is signed in or not.
class Me {
  final String id;
  final String handle;
  final String displayName;
  final bool isGuest;
  final int entryCount;
  // One of design/illustrations.dart's avatarIconIds, or null before the user has
  // picked one — the profile page falls back to displayName's first letter then.
  final String? avatarId;

  const Me({
    required this.id,
    required this.handle,
    required this.displayName,
    required this.isGuest,
    required this.entryCount,
    this.avatarId,
  });

  factory Me.fromJson(Map<String, dynamic> json) => Me(
        id: json['id'] as String,
        handle: json['handle'] as String,
        displayName: json['displayName'] as String,
        isGuest: json['isGuest'] as bool,
        entryCount: (json['entryCount'] as num).toInt(),
        avatarId: json['avatarId'] as String?,
      );
}
