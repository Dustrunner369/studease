import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/design/theme.dart';
import 'package:mobile/models/label.dart';
import 'package:mobile/services/api_service.dart';

/// Pushes the full-page tag picker. Returns the new selection on "Done", or null
/// if the page was left via the back button/swipe — callers should treat null as
/// "no change" and keep whatever selection they already had.
Future<Set<String>?> showTagPickerPage(
  BuildContext context, {
  required List<Label> availableLabels,
  required Set<String> selectedSlugs,
}) {
  return Navigator.of(context).push<Set<String>>(
    MaterialPageRoute(
      builder: (_) => TagPickerPage(
        availableLabels: availableLabels,
        selectedSlugs: selectedSlugs,
      ),
    ),
  );
}

/// Positive tags on top, negative below, multi-select, "Done" commits. "Suggest a
/// New Tag" sits at the very bottom of the scroll, below both sections.
class TagPickerPage extends StatefulWidget {
  final List<Label> availableLabels;
  final Set<String> selectedSlugs;

  const TagPickerPage({
    super.key,
    required this.availableLabels,
    required this.selectedSlugs,
  });

  @override
  State<TagPickerPage> createState() => _TagPickerPageState();
}

class _TagPickerPageState extends State<TagPickerPage> {
  late List<Label> _labels;
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _labels = List.of(widget.availableLabels);
    _selected = Set.of(widget.selectedSlugs);
  }

  void _toggle(String slug) => setState(() {
        if (!_selected.remove(slug)) _selected.add(slug);
      });

  Future<void> _suggestTag() async {
    final result = await showRequestTagDialog(context);
    if (result == null || !mounted) return;

    setState(() {
      // Dedupe hit on an already-approved label: it has a real polarity and slots
      // straight into its section. A freshly-created pending one has neither yet —
      // it just won't render in either section until an admin approves it.
      if (!_labels.any((l) => l.id == result.id)) {
        _labels = [..._labels, result]..sort((a, b) => a.slug.compareTo(b.slug));
      }
      if (result.status == 'approved') _selected.add(result.slug);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Tone.ink,
        content: Text(
          result.status == 'approved'
              ? '#${result.slug} already exists — added it.'
              : '#${result.slug} submitted for review — usable once approved.',
          style: GoogleFonts.fraunces(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final positive = _labels.where((l) => !l.isNegative).toList();
    final negative = _labels.where((l) => l.isNegative).toList();

    return Scaffold(
      backgroundColor: Tone.bg,
      appBar: AppBar(
        backgroundColor: Tone.bg,
        elevation: 0,
        foregroundColor: Tone.ink,
        title: Text(
          'Tags',
          style: GoogleFonts.fraunces(fontSize: 17, fontWeight: FontWeight.w800, color: Tone.ink),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_selected),
            child: Text(
              'Done',
              style: GoogleFonts.fraunces(fontSize: 15, fontWeight: FontWeight.w700, color: Tone.terracotta),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
          children: [
            if (positive.isNotEmpty) ...[
              _sectionLabel('POSITIVE'),
              const SizedBox(height: 10),
              _pillWrap(positive, negative: false),
              const SizedBox(height: 22),
            ],
            if (negative.isNotEmpty) ...[
              _sectionLabel('NEGATIVE'),
              const SizedBox(height: 10),
              _pillWrap(negative, negative: true),
              const SizedBox(height: 22),
            ],
            GestureDetector(
              onTap: _suggestTag,
              child: Text(
                'Suggest a New Tag',
                style: GoogleFonts.fraunces(fontSize: 13.5, fontWeight: FontWeight.w700, color: Tone.terracotta),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: GoogleFonts.fraunces(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Tone.muted,
        ),
      );

  Widget _pillWrap(List<Label> labels, {required bool negative}) {
    // Negative selections read in the same rust tone the rest of the app already
    // uses for "bad" (Level.rough, form errors) rather than a fresh, undisciplined
    // color — see Tone.error.
    final selectedColor = negative ? Tone.error : Tone.ink;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in labels)
          GestureDetector(
            onTap: () => _toggle(label.slug),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: _selected.contains(label.slug) ? selectedColor : Tone.field,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '#${label.slug}',
                style: GoogleFonts.fraunces(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _selected.contains(label.slug) ? Colors.white : Tone.muted,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// "Request a tag" — a text field, then Submit and Cancel stacked below it. No
/// polarity picker here on purpose: the requester never chooses positive/negative
/// (see LabelPolarities on the backend) — that call belongs to whoever approves it.
Future<Label?> showRequestTagDialog(BuildContext context) {
  return showDialog<Label>(
    context: context,
    builder: (_) => const _RequestTagDialog(),
  );
}

class _RequestTagDialog extends StatefulWidget {
  const _RequestTagDialog();

  @override
  State<_RequestTagDialog> createState() => _RequestTagDialogState();
}

class _RequestTagDialogState extends State<_RequestTagDialog> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final label = await requestLabel(name);
      if (!mounted) return;
      Navigator.of(context).pop(label);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Tone.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        'Request a tag',
        style: GoogleFonts.fraunces(fontSize: 17, fontWeight: FontWeight.w800, color: Tone.ink),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(color: Tone.field, borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'e.g. Too loud',
                hintStyle: GoogleFonts.fraunces(fontSize: 14.5, fontWeight: FontWeight.w500, color: Tone.muted),
              ),
              style: GoogleFonts.fraunces(fontSize: 14.5, fontWeight: FontWeight.w600, color: Tone.ink),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: GoogleFonts.fraunces(fontSize: 12.5, fontWeight: FontWeight.w500, color: Tone.error),
            ),
          ],
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _submitting ? null : _submit,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: Tone.ink,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            'Submit',
                            style: GoogleFonts.fraunces(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _submitting ? null : () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.fraunces(fontSize: 14, fontWeight: FontWeight.w700, color: Tone.muted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
