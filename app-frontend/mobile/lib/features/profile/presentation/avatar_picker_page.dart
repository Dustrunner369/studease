import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/design/illustrations.dart';
import 'package:mobile/design/theme.dart';

/// Pushes the full-page avatar picker. Returns the newly picked avatarId on tap, or
/// null if the page was left via the back button/swipe — callers should treat null as
/// "no change".
Future<String?> showAvatarPickerPage(BuildContext context, {String? selectedAvatarId}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => AvatarPickerPage(selectedAvatarId: selectedAvatarId),
    ),
  );
}

/// A grid of the preset profile icons. Unlike TagPickerPage this is single-select and
/// commits immediately on tap — a profile picture isn't a multi-step decision worth a
/// separate "Done" button for.
class AvatarPickerPage extends StatelessWidget {
  final String? selectedAvatarId;

  const AvatarPickerPage({super.key, this.selectedAvatarId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tone.bg,
      appBar: AppBar(
        backgroundColor: Tone.bg,
        elevation: 0,
        foregroundColor: Tone.ink,
        title: Text(
          'Choose an icon',
          style: GoogleFonts.fraunces(fontSize: 17, fontWeight: FontWeight.w800, color: Tone.ink),
        ),
      ),
      body: SafeArea(
        child: GridView.count(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            for (final avatarId in avatarIconIds)
              _AvatarOption(
                avatarId: avatarId,
                selected: avatarId == selectedAvatarId,
                onTap: () => Navigator.of(context).pop(avatarId),
              ),
          ],
        ),
      ),
    );
  }
}

class _AvatarOption extends StatelessWidget {
  final String avatarId;
  final bool selected;
  final VoidCallback onTap;

  const _AvatarOption({required this.avatarId, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // cafe_01 draws its own circular frame, so it fills the tile edge-to-edge; the
    // others get a small margin so they don't crowd it.
    final isCafe01 = avatarId == 'cafe_01';

    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          padding: EdgeInsets.all(isCafe01 ? 4 : 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Tone.field,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? Tone.terracotta : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: AvatarIconSketch(avatarId: avatarId, size: isCafe01 ? 72 : 54),
        ),
      ),
    );
  }
}
