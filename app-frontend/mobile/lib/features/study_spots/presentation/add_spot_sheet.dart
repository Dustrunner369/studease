import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/design/celebrations.dart';
import 'package:mobile/design/theme.dart';
import 'package:mobile/features/authentication/presentation/login_page.dart';
import 'package:mobile/features/study_spots/presentation/tag_picker_page.dart';
import 'package:mobile/models/label.dart';
import 'package:mobile/models/me.dart';
import 'package:mobile/models/spot.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_controller.dart';

/// Pass [existing] to open in edit mode: every field pre-filled from that entry,
/// including name/address (editable — see [AddSpotSheet._save], which corrects the
/// shared place record rather than re-linking to a different one), saving updates the
/// same entry instead of creating one.
Future<bool?> showAddSpotSheet(
  BuildContext context,
  AuthController auth, {
  MySpotListItem? existing,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => AddSpotSheet(auth: auth, existing: existing),
  );
}

class AddSpotSheet extends StatefulWidget {
  final AuthController auth;
  final MySpotListItem? existing;

  const AddSpotSheet({super.key, required this.auth, this.existing});

  @override
  State<AddSpotSheet> createState() => _AddSpotSheetState();
}

class _AddSpotSheetState extends State<AddSpotSheet> {
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _orderController = TextEditingController();
  final _notesController = TextEditingController();

  PlaceSuggestion? _selectedPlace;
  List<PlaceSuggestion> _suggestions = [];
  Timer? _debounce;
  bool _searching = false;

  // Set to true when user wants to manually enter a study spot
  bool _manualEntry = false;
  String? _searchNotice;

  // The standardized vocabulary (approved labels only), and which of them this
  // entry carries. Optional — unlike the ratings below, an untagged spot still saves.
  List<Label> _availableLabels = [];
  final Set<String> _selectedTagSlugs = {};

  int? _wifi;
  int? _quiet;
  int? _outlets;
  int? _seating;
  int? _tableSize;
  int? _coffee;

  // A yes/no, so it starts answered rather than null — unlike the six ratings, leaving
  // it alone is a valid "no" and shouldn't block saving.
  bool _groupStudy = false;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // The save button enables as soon as a name exists, so it has to track typing.
    _nameController.addListener(_onFormChanged);
    _loadLabels();

    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _addressController.text = existing.address ?? '';
      _orderController.text = existing.coffeeOrder ?? '';
      _notesController.text = existing.notes ?? '';
      _selectedTagSlugs.addAll(existing.tags);
      _groupStudy = existing.groupStudy;
      _wifi = existing.ratings.wifi;
      _quiet = existing.ratings.noise;
      _outlets = existing.ratings.outlets;
      _seating = existing.ratings.seating;
      _tableSize = existing.ratings.tableSize;
      _coffee = existing.ratings.coffee;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.removeListener(_onFormChanged);
    _searchController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _orderController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadLabels() async {
    try {
      final labels = await fetchLabels();
      if (!mounted) return;
      setState(() => _availableLabels = labels);
    } catch (_) {
      // Tags are optional — a failed lookup just leaves the picker empty. The
      // request field below still works independently of this.
    }
  }

  void _onFormChanged() => setState(() {});

  bool get _hasPlace =>
      _selectedPlace != null || _nameController.text.trim().isNotEmpty;

  bool get _hasAllRatings =>
      _wifi != null &&
      _quiet != null &&
      _outlets != null &&
      _seating != null &&
      _tableSize != null &&
      _coffee != null;

  bool get _canSave => _hasPlace && _hasAllRatings && !_saving;

  void _onSearchChanged(String query) {
    _debounce?.cancel();

    if (query.trim().length < 3) {
      setState(() {
        _suggestions = [];
        _searching = false;
      });
      return;
    }

    // Autocomplete is billed per request, so wait for a pause in typing.
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _runSearch(query.trim()),
    );
  }

  Future<void> _runSearch(String query) async {
    setState(() {
      _searching = true;
      _searchNotice = null;
    });

    try {
      final results = await searchPlaces(query);
      if (!mounted) return;

      setState(() {
        _suggestions = results;
        _searching = false;
        if (results.isEmpty)
          _searchNotice = 'No matches. You can add it by hand instead.';
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _searching = false;
        _suggestions = [];
        // No API key server-side: drop straight into manual entry rather than
        // leaving the user staring at a search box that can never work.
        if (e.isPlacesUnavailable) {
          _manualEntry = true;
          _nameController.text = query;
        }
        _searchNotice = e.message;
      });
    }
  }

  Future<void> _openTagPicker() async {
    final result = await showTagPickerPage(
      context,
      availableLabels: _availableLabels,
      selectedSlugs: _selectedTagSlugs,
    );
    if (result == null || !mounted) return;

    setState(() {
      _selectedTagSlugs
        ..clear()
        ..addAll(result);
    });

    // A "Suggest a New Tag" dedupe hit inside the picker may have added a label
    // this sheet doesn't know about yet — refetch so its chip can render.
    unawaited(_loadLabels());
  }

  void _selectPlace(PlaceSuggestion place) {
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedPlace = place;
      _suggestions = [];
      _searchNotice = null;
      _searchController.clear();
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // Two calls on purpose: the place is shared by everyone, the rating is mine.
      // Editing an existing entry still touches the place — updateSpot corrects its
      // Name/Address in place — but never re-links it to a different Google place;
      // only a fresh Places search (createSpot) can do that.
      final spotId = widget.existing != null
          ? (await updateSpot(
              spotId: widget.existing!.spotId,
              name: _nameController.text.trim(),
              address: _trimmedOrNull(_addressController),
            )).id
          : (await createSpot(
              googlePlaceId: _selectedPlace?.googlePlaceId,
              name: _selectedPlace == null ? _nameController.text.trim() : null,
              address: _selectedPlace == null
                  ? _trimmedOrNull(_addressController)
                  : null,
            )).id;

      await saveEntry(
        spotId: spotId,
        ratings: Ratings(
          wifi: _wifi!,
          noise: _quiet!,
          outlets: _outlets!,
          seating: _seating!,
          tableSize: _tableSize!,
          coffee: _coffee!,
        ),
        groupStudy: _groupStudy,
        tagSlugs: _selectedTagSlugs.toList(),
        coffeeOrder: _trimmedOrNull(_orderController),
        notes: _trimmedOrNull(_notesController),
      );

      // Best-effort: keeps the Profile tab's entry count current without blocking
      // this sheet on it, and without failing the save if it hiccups.
      unawaited(widget.auth.refreshMe());

      if (!mounted) return;

      // A brand-new spot gets a floating celebration card stacked on top of this
      // still-open sheet — the sheet itself stays a plain bottom sheet; only the
      // moment of delight floats. An edit just pops immediately like before.
      if (widget.existing == null) {
        await _showCelebrationDialog();
        if (!mounted) return;
      }
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;

      if (e.isGuestLimitReached) {
        setState(() => _saving = false);
        await _showGuestLimitDialog();
        return;
      }

      setState(() {
        _error = e.message;
        _saving = false;
      });
    }
  }

  // Floats a centered celebration card on top of this still-open bottom sheet —
  // fade + scale in, matching showLogVisitDialog's treatment — rather than
  // swapping the sheet's own content in place.
  Future<void> _showCelebrationDialog() {
    final spotName = _selectedPlace?.name ?? _nameController.text.trim();
    final tagCount = _selectedTagSlugs.length;

    return showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Spot saved',
      barrierColor: Colors.black54,
      barrierDismissible: false,
      transitionDuration: Motion.short,
      pageBuilder: (context, animation, secondaryAnimation) =>
          _CelebrationDialog(spotName: spotName, tagCount: tagCount),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Motion.easeOut,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _showGuestLimitDialog() async {
    final createAccount = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Tone.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          "You've hit the guest limit",
          style: GoogleFonts.fraunces(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Tone.ink,
          ),
        ),
        content: Text(
          'Guests can add up to $guestEntryLimit spots. Create an account to keep adding — '
          "and to keep the ones you've already added for good.",
          style: GoogleFonts.fraunces(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: Tone.muted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Not now',
              style: GoogleFonts.fraunces(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Tone.muted,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Create account',
              style: GoogleFonts.fraunces(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Tone.terracotta,
              ),
            ),
          ),
        ],
      ),
    );

    if (createAccount != true || !mounted) return;

    // Captured before popping the sheet: once its own route is gone, `context` is no
    // longer safe to resolve a Navigator from, but the NavigatorState itself — the
    // app's single, long-lived Navigator — is fine to keep using.
    final navigator = Navigator.of(context);

    // Close the sheet first: signing up navigates to a full page, and stacking that
    // on top of a modal sheet reads as broken even though it technically works.
    navigator.pop(false);
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => LoginPage(auth: widget.auth, startInSignUp: true),
      ),
    );
  }

  static String? _trimmedOrNull(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      // Tapping anywhere that isn't itself a control (a field, a button, a rating
      // dot…) dismisses the keyboard instead of leaving it up until Enter/Done.
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        // Lifts the sheet clear of the keyboard.
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: Container(
          decoration: const BoxDecoration(
            color: Tone.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              // Shrink the cap by the keyboard inset too — otherwise the sheet keeps
              // claiming 90% of the *full* screen while also being lifted clear of the
              // keyboard, so the two together push its top (handle, title, search
              // field) off the top of the screen instead of just scrolling the body.
              maxHeight:
                  MediaQuery.of(context).size.height * 0.9 - keyboardInset,
            ),
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
                          if (widget.existing != null)
                            _buildManualFields()
                          else if (_selectedPlace != null)
                            _buildSelectedPlace()
                          else if (_manualEntry)
                            _buildManualFields()
                          else
                            _buildSearch(),
                          const SizedBox(height: 22),
                          _buildSectionLabel('TAGS'),
                          const SizedBox(height: 10),
                          _buildTagSection(),
                          const SizedBox(height: 22),
                          _buildSectionLabel('RATE IT'),
                          const SizedBox(height: 4),
                          _RatingRow(
                            icon: Icons.wifi,
                            label: 'WiFi',
                            value: _wifi,
                            onChanged: (v) => setState(() => _wifi = v),
                          ),
                          _RatingRow(
                            icon: Icons.volume_off,
                            label: 'Quiet',
                            value: _quiet,
                            onChanged: (v) => setState(() => _quiet = v),
                          ),
                          _RatingRow(
                            icon: Icons.bolt,
                            label: 'Outlets',
                            value: _outlets,
                            onChanged: (v) => setState(() => _outlets = v),
                          ),
                          _RatingRow(
                            icon: Icons.event_seat,
                            label: 'Seating',
                            value: _seating,
                            onChanged: (v) => setState(() => _seating = v),
                          ),
                          _RatingRow(
                            icon: Icons.table_restaurant,
                            label: 'Table size',
                            value: _tableSize,
                            onChanged: (v) => setState(() => _tableSize = v),
                          ),
                          _RatingRow(
                            icon: Icons.local_cafe,
                            label: 'Coffee',
                            value: _coffee,
                            onChanged: (v) => setState(() => _coffee = v),
                          ),
                          const SizedBox(height: 22),
                          _buildSectionLabel('GROUP STUDY'),
                          const SizedBox(height: 4),
                          _GroupStudyToggle(
                            value: _groupStudy,
                            onChanged: (v) => setState(() => _groupStudy = v),
                          ),
                          const SizedBox(height: 22),
                          _buildSectionLabel('USUAL ORDER'),
                          const SizedBox(height: 8),
                          _TextField(
                            controller: _orderController,
                            hint: 'Vanilla latte',
                          ),
                          const SizedBox(height: 16),
                          _buildSectionLabel('NOTES'),
                          const SizedBox(height: 8),
                          _TextField(
                            controller: _notesController,
                            hint: 'Quiet back room with good lighting',
                            maxLines: 3,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            _buildError(),
                          ],
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
      ),
    );
  }

  Widget _buildHandle() => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 8),
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Tone.line,
        borderRadius: BorderRadius.circular(4),
      ),
    ),
  );

  Widget _buildTitle() => Row(
    children: [
      Expanded(
        child: Text(
          widget.existing != null ? 'Edit spot' : 'Add a spot',
          style: GoogleFonts.fraunces(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: Tone.ink,
          ),
        ),
      ),
      IconButton(
        onPressed: () => Navigator.of(context).pop(false),
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

  Widget _buildSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('WHERE'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Tone.field,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              const Icon(Icons.search, size: 20, color: Tone.muted),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  autofocus: true,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Search cafés, libraries…',
                    hintStyle: GoogleFonts.fraunces(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: Tone.muted,
                    ),
                  ),
                  style: GoogleFonts.fraunces(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: Tone.ink,
                  ),
                ),
              ),
              if (_searching)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Tone.muted,
                  ),
                ),
            ],
          ),
        ),
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Tone.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                for (var i = 0; i < _suggestions.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, thickness: 1, color: Tone.line),
                  _SuggestionRow(
                    suggestion: _suggestions[i],
                    onTap: () => _selectPlace(_suggestions[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (_searchNotice != null) ...[
          const SizedBox(height: 8),
          Text(
            _searchNotice!,
            style: GoogleFonts.fraunces(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Tone.muted,
            ),
          ),
        ],
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => setState(() {
            _manualEntry = true;
            _nameController.text = _searchController.text.trim();
          }),
          child: Text(
            "Can't find it? Add it by hand",
            style: GoogleFonts.fraunces(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Tone.terracotta,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedPlace() {
    final place = _selectedPlace!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('WHERE'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Tone.field,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: GoogleFonts.fraunces(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Tone.ink,
                      ),
                    ),
                    if (place.address.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        place.address,
                        style: GoogleFonts.fraunces(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Tone.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedPlace = null),
                child: Text(
                  'Change',
                  style: GoogleFonts.fraunces(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Tone.terracotta,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManualFields() {
    final editing = widget.existing != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('NAME'),
        const SizedBox(height: 8),
        _TextField(
          controller: _nameController,
          hint: 'Brew & Books',
          autofocus: !editing,
        ),
        const SizedBox(height: 16),
        _buildSectionLabel('ADDRESS'),
        const SizedBox(height: 8),
        _TextField(controller: _addressController, hint: '123 Library Lane'),
        if (!editing) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => setState(() {
              _manualEntry = false;
              _searchNotice = null;
            }),
            child: Text(
              'Search Google instead',
              style: GoogleFonts.fraunces(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Tone.terracotta,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// An "Add Tag" pill that opens the full-page picker, plus a removable chip for
  /// each tag already applied — ink for positive, the same rust as everything else
  /// in the app that means "bad" for negative (see Tone.error). Tapping a chip's ×
  /// drops it without reopening the picker.
  Widget _buildTagSection() {
    final selected = _availableLabels
        .where((l) => _selectedTagSlugs.contains(l.slug))
        .toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        GestureDetector(
          onTap: _openTagPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: Tone.field,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, size: 15, color: Tone.terracotta),
                const SizedBox(width: 4),
                Text(
                  'Add Tag',
                  style: GoogleFonts.fraunces(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Tone.terracotta,
                  ),
                ),
              ],
            ),
          ),
        ),
        for (final label in selected)
          Container(
            padding: const EdgeInsets.only(
              left: 14,
              right: 8,
              top: 9,
              bottom: 9,
            ),
            decoration: BoxDecoration(
              color: label.isNegative ? Tone.error : Tone.ink,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '#${label.slug}',
                  style: GoogleFonts.fraunces(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () =>
                      setState(() => _selectedTagSlugs.remove(label.slug)),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Tone.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: Tone.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: GoogleFonts.fraunces(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Tone.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Tone.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_hasAllRatings && _hasPlace)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Rate all six to save',
                style: GoogleFonts.fraunces(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: Tone.muted,
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _canSave ? _save : null,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: _canSave ? Tone.ink : Tone.line,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.existing != null
                              ? 'Save changes'
                              : 'Save spot',
                          style: GoogleFonts.fraunces(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _canSave ? Colors.white : Tone.muted,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The floating "spot saved" moment shown on top of [AddSpotSheet] once a
/// brand-new spot is saved — see [_AddSpotSheetState._showCelebrationDialog].
class _CelebrationDialog extends StatelessWidget {
  final String spotName;
  final int tagCount;

  const _CelebrationDialog({required this.spotName, required this.tagCount});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Tone.bg,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
            child: JournalSavedCard(
              spotName: spotName,
              tagCount: tagCount,
              onDone: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Whether the spot works for studying with other people.
///
/// A two-option segmented control rather than a Switch: a switch reads as a setting you
/// flip, and defaults to "off" ambiguously, where this is an answer with two sides.
class _GroupStudyToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _GroupStudyToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          const Icon(Icons.groups, size: 19, color: Tone.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Good with a group',
              style: GoogleFonts.fraunces(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: Tone.ink,
              ),
            ),
          ),
          for (final (label, isYes) in const [('No', false), ('Yes', true)])
            GestureDetector(
              onTap: () => onChanged(isYes),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: value == isYes ? Tone.ink : Tone.field,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    label,
                    style: GoogleFonts.fraunces(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: value == isYes ? Colors.white : Tone.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One 1-5 rating: a labelled row of five dots that fill in as you tap.
class _RatingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? value;
  final ValueChanged<int> onChanged;

  const _RatingRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Unrated rows stay grey so it's obvious which ones still need an answer.
    final color = value == null ? Tone.line : levelFor(value!).color;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(icon, size: 19, color: Tone.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.fraunces(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: Tone.ink,
              ),
            ),
          ),
          for (var i = 1; i <= 5; i++)
            GestureDetector(
              onTap: () => onChanged(i),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: value != null && i <= value!
                        ? color
                        : Colors.transparent,
                    border: Border.all(
                      color: value != null && i <= value! ? color : Tone.line,
                      width: 2,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  final PlaceSuggestion suggestion;
  final VoidCallback onTap;

  const _SuggestionRow({required this.suggestion, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.place_outlined, size: 18, color: Tone.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.fraunces(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Tone.ink,
                    ),
                  ),
                  if (suggestion.address.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      suggestion.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.fraunces(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: Tone.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final bool autofocus;

  const _TextField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Tone.field,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        autofocus: autofocus,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: GoogleFonts.fraunces(
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            color: Tone.muted,
          ),
        ),
        style: GoogleFonts.fraunces(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: Tone.ink,
        ),
      ),
    );
  }
}
