import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/design/theme.dart';
import 'package:mobile/models/spot.dart';
import 'package:mobile/services/api_service.dart';

/// Slides the add-spot form up from the bottom. Resolves to true when a spot was
/// saved, so the caller knows to reload the list.
Future<bool?> showAddSpotSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const AddSpotSheet(),
  );
}

class AddSpotSheet extends StatefulWidget {
  const AddSpotSheet({super.key});

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

  // Set when the server has no Places key, or when the spot isn't on Google at all
  // — a campus study room usually isn't.
  bool _manualEntry = false;
  String? _searchNotice;

  SpotType _type = SpotType.cafe;

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
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(query.trim()));
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
        if (results.isEmpty) _searchNotice = 'No matches. You can add it by hand instead.';
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
      final spot = await createSpot(
        googlePlaceId: _selectedPlace?.googlePlaceId,
        name: _selectedPlace == null ? _nameController.text.trim() : null,
        address: _selectedPlace == null ? _trimmedOrNull(_addressController) : null,
        type: _type,
      );

      await saveEntry(
        spotId: spot.id,
        ratings: Ratings(
          wifi: _wifi!,
          noise: _quiet!,
          outlets: _outlets!,
          seating: _seating!,
          tableSize: _tableSize!,
          coffee: _coffee!,
        ),
        groupStudy: _groupStudy,
        coffeeOrder: _trimmedOrNull(_orderController),
        notes: _trimmedOrNull(_notesController),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _saving = false;
      });
    }
  }

  static String? _trimmedOrNull(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lifts the sheet clear of the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Tone.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
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
                        if (_selectedPlace != null)
                          _buildSelectedPlace()
                        else if (_manualEntry)
                          _buildManualFields()
                        else
                          _buildSearch(),
                        const SizedBox(height: 22),
                        _buildSectionLabel('TYPE'),
                        const SizedBox(height: 10),
                        _buildTypePicker(),
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
              'Add a spot',
              style: GoogleFonts.plusJakartaSans(
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
        style: GoogleFonts.plusJakartaSans(
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
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: Tone.muted,
                    ),
                  ),
                  style: GoogleFonts.plusJakartaSans(
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
                  child: CircularProgressIndicator(strokeWidth: 2, color: Tone.muted),
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
                  if (i > 0) const Divider(height: 1, thickness: 1, color: Tone.line),
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
            style: GoogleFonts.plusJakartaSans(
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
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Tone.teal,
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
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Tone.ink,
                      ),
                    ),
                    if (place.address.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        place.address,
                        style: GoogleFonts.plusJakartaSans(
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
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Tone.teal,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('NAME'),
        const SizedBox(height: 8),
        _TextField(controller: _nameController, hint: 'Brew & Books', autofocus: true),
        const SizedBox(height: 16),
        _buildSectionLabel('ADDRESS'),
        const SizedBox(height: 8),
        _TextField(controller: _addressController, hint: '123 Library Lane'),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => setState(() {
            _manualEntry = false;
            _searchNotice = null;
          }),
          child: Text(
            'Search Google instead',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Tone.teal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypePicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final type in SpotType.values)
          GestureDetector(
            onTap: () => setState(() => _type = type),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: _type == type ? Tone.ink : Tone.field,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    type.icon,
                    size: 15,
                    color: _type == type ? Colors.white : Tone.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    type.label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _type == type ? Colors.white : Tone.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Tone.coral.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: Tone.coral),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Tone.coral,
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
                style: GoogleFonts.plusJakartaSans(
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
                          'Save spot',
                          style: GoogleFonts.plusJakartaSans(
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
              style: GoogleFonts.plusJakartaSans(
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: value == isYes ? Tone.ink : Tone.field,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
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
              style: GoogleFonts.plusJakartaSans(
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
                    color: value != null && i <= value! ? color : Colors.transparent,
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
                    style: GoogleFonts.plusJakartaSans(
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
                      style: GoogleFonts.plusJakartaSans(
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
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            color: Tone.muted,
          ),
        ),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: Tone.ink,
        ),
      ),
    );
  }
}
