import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/design/illustrations.dart';
import 'package:mobile/design/theme.dart';

/// The result of the sheet — a preset icon or null for the display-name-initial
/// fallback, an optional accent color, and whether the background is tinted to
/// match. Returned only on explicit Save; null means "no change" (closed via the X
/// or a swipe-down).
typedef AvatarSelection = ({String? avatarId, String? colorSlug, bool backgroundTint});

/// Opens the avatar picker as a bottom sheet anchored to the profile picture,
/// rather than a full-screen page.
Future<AvatarSelection?> showAvatarPickerSheet(
  BuildContext context, {
  required String displayName,
  String? selectedAvatarId,
  String? selectedColorSlug,
  bool selectedBackgroundTint = false,
}) {
  return showModalBottomSheet<AvatarSelection>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => AvatarPickerSheet(
      displayName: displayName,
      selectedAvatarId: selectedAvatarId,
      selectedColorSlug: selectedColorSlug,
      selectedBackgroundTint: selectedBackgroundTint,
    ),
  );
}

class AvatarPickerSheet extends StatefulWidget {
  final String displayName;
  final String? selectedAvatarId;
  final String? selectedColorSlug;
  final bool selectedBackgroundTint;

  const AvatarPickerSheet({
    super.key,
    required this.displayName,
    this.selectedAvatarId,
    this.selectedColorSlug,
    this.selectedBackgroundTint = false,
  });

  @override
  State<AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<AvatarPickerSheet> {
  String? _avatarId;
  String? _colorSlug;
  bool _backgroundTint = false;

  @override
  void initState() {
    super.initState();
    _avatarId = widget.selectedAvatarId;
    _colorSlug = widget.selectedColorSlug;
    _backgroundTint = widget.selectedBackgroundTint;
  }

  String get _initial => widget.displayName.isNotEmpty ? widget.displayName[0].toUpperCase() : '?';

  void _save() {
    Navigator.of(context)
        .pop((avatarId: _avatarId, colorSlug: _colorSlug, backgroundTint: _backgroundTint));
  }

  @override
  Widget build(BuildContext context) {
    final tone = resolveAvatarTone(colorSlug: _colorSlug, backgroundTint: _backgroundTint);

    return Padding(
      // Lifts the sheet clear of the keyboard, though nothing here opens one today.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Tone.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHandle(),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTitle(),
                        const SizedBox(height: 18),
                        Center(child: _buildPreview(tone)),
                        const SizedBox(height: 22),
                        _buildSectionLabel('ICON'),
                        const SizedBox(height: 10),
                        _buildIconGrid(),
                        const SizedBox(height: 22),
                        _buildSectionLabel('COLOR'),
                        const SizedBox(height: 10),
                        _buildColorSwatches(),
                        const SizedBox(height: 22),
                        _buildSectionLabel('BACKGROUND'),
                        const SizedBox(height: 4),
                        _buildBackgroundTintRow(),
                      ],
                    ),
                  ),
                ),
                _buildSaveBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(color: Tone.line, borderRadius: BorderRadius.circular(4)),
        ),
      );

  Widget _buildTitle() => Row(
        children: [
          Expanded(
            child: Text(
              'Edit avatar',
              style: GoogleFonts.fraunces(fontSize: 21, fontWeight: FontWeight.w800, color: Tone.ink),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(null),
            icon: const Icon(Icons.close, color: Tone.muted),
            splashRadius: 20,
          ),
        ],
      );

  Widget _buildSectionLabel(String text) => Text(
        text,
        style: GoogleFonts.fraunces(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Tone.muted,
        ),
      );

  Widget _buildPreview(({Color icon, Color background}) tone) {
    return CircleAvatar(
      radius: 44,
      backgroundColor: tone.background,
      child: _avatarId != null
          ? AvatarIconSketch(
              avatarId: _avatarId!,
              size: _avatarId == 'cafe_01' ? 88 : 70,
              color: tone.icon,
            )
          : Text(
              _initial,
              style: GoogleFonts.fraunces(fontSize: 30, fontWeight: FontWeight.w800, color: tone.icon),
            ),
    );
  }

  Widget _buildIconGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 5,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _AvatarOption(
          avatarId: null,
          selected: _avatarId == null,
          onTap: () => setState(() => _avatarId = null),
        ),
        for (final avatarId in avatarIconIds)
          _AvatarOption(
            avatarId: avatarId,
            selected: avatarId == _avatarId,
            onTap: () => setState(() => _avatarId = avatarId),
          ),
      ],
    );
  }

  Widget _buildColorSwatches() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _ColorSwatchOption(
          color: Tone.field,
          selected: _colorSlug == null,
          icon: Icons.close,
          iconColor: Tone.muted,
          onTap: () => setState(() => _colorSlug = null),
        ),
        for (final avatarColor in avatarColorPalette)
          _ColorSwatchOption(
            color: avatarColor.value,
            selected: _colorSlug == avatarColor.slug,
            onTap: () => setState(() => _colorSlug = avatarColor.slug),
          ),
      ],
    );
  }

  Widget _buildBackgroundTintRow() {
    final enabled = _colorSlug != null;

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: GestureDetector(
          onTap: () => setState(() => _backgroundTint = !_backgroundTint),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                _ToneCheckbox(value: _backgroundTint),
                const SizedBox(width: 10),
                Text(
                  'Tint background to match',
                  style: GoogleFonts.fraunces(fontSize: 14.5, fontWeight: FontWeight.w600, color: Tone.ink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Tone.line))),
      child: SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onTap: _save,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(color: Tone.ink, borderRadius: BorderRadius.circular(14)),
            child: Center(
              child: Text(
                'Save',
                style: GoogleFonts.fraunces(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A tile in the ICON grid. [avatarId] null is the "revert to default" option — an
/// X, same treatment as the color grid's "None" swatch — rather than one of the
/// preset icons.
class _AvatarOption extends StatelessWidget {
  final String? avatarId;
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
          child: avatarId != null
              ? AvatarIconSketch(avatarId: avatarId!, size: isCafe01 ? 72 : 54)
              : const Icon(Icons.close, size: 22, color: Tone.muted),
        ),
      ),
    );
  }
}

class _ColorSwatchOption extends StatelessWidget {
  final Color color;
  final bool selected;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback onTap;

  const _ColorSwatchOption({
    required this.color,
    required this.selected,
    required this.onTap,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: selected ? Tone.ink : Colors.transparent, width: 3),
        ),
        child: icon != null
            ? Icon(icon, size: 18, color: iconColor ?? Colors.white)
            : (selected ? const Icon(Icons.check, size: 18, color: Colors.white) : null),
      ),
    );
  }
}

class _ToneCheckbox extends StatelessWidget {
  final bool value;

  const _ToneCheckbox({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: value ? Tone.ink : Tone.field,
        borderRadius: BorderRadius.circular(6),
        border: value ? null : Border.all(color: Tone.line, width: 1.5),
      ),
      child: value ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
    );
  }
}
