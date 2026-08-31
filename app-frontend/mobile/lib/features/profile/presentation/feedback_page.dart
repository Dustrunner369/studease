import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/design/theme.dart';
import 'package:mobile/services/api_service.dart';

const _messageMaxLength = 2000;

const _feedbackTypes = [
  (value: 'bug', label: 'Bug'),
  (value: 'feature_request', label: 'Feature Request'),
  (value: 'other', label: 'Other'),
];

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _messageController = TextEditingController();
  String _type = _feedbackTypes.first.value;

  bool _submitting = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      setState(() => _error = 'Say something before submitting.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await submitFeedback(type: _type, message: message);
      if (!mounted) return;
      setState(() {
        _sent = true;
        _submitting = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tone.bg,
      appBar: AppBar(
        backgroundColor: Tone.bg,
        elevation: 0,
        foregroundColor: Tone.ink,
        title: Text(
          'Leave Feedback',
          style: GoogleFonts.fraunces(fontSize: 17, fontWeight: FontWeight.w800, color: Tone.ink),
        ),
      ),
      body: SafeArea(child: _sent ? _buildSent() : _buildForm()),
    );
  }

  Widget _buildSent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, size: 40, color: Tone.sage),
            const SizedBox(height: 16),
            Text(
              'Thanks!',
              style: GoogleFonts.fraunces(fontSize: 19, fontWeight: FontWeight.w800, color: Tone.ink),
            ),
            const SizedBox(height: 8),
            Text(
              'Your feedback was sent.',
              textAlign: TextAlign.center,
              style: GoogleFonts.fraunces(fontSize: 13.5, fontWeight: FontWeight.w500, color: Tone.muted),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(color: Tone.ink, borderRadius: BorderRadius.circular(14)),
                  child: Center(
                    child: Text(
                      'Done',
                      style: GoogleFonts.fraunces(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('TYPE'),
          const SizedBox(height: 8),
          _typeDropdown(),
          const SizedBox(height: 18),
          _sectionLabel("WHAT'S ON YOUR MIND?"),
          const SizedBox(height: 8),
          _messageField(),
          if (_error != null) ...[
            const SizedBox(height: 16),
            _errorBox(_error!),
          ],
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _submitting ? null : _submit,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(color: Tone.ink, borderRadius: BorderRadius.circular(14)),
                child: Center(
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Submit',
                          style: GoogleFonts.fraunces(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                ),
              ),
            ),
          ),
        ],
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

  Widget _typeDropdown() {
    return Container(
      decoration: BoxDecoration(color: Tone.field, borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          initialValue: _type,
          isExpanded: true,
          icon: const Icon(Icons.expand_more, color: Tone.muted),
          decoration: const InputDecoration(border: InputBorder.none, isDense: true),
          items: [
            for (final type in _feedbackTypes)
              DropdownMenuItem(
                value: type.value,
                child: Text(
                  type.label,
                  style: GoogleFonts.fraunces(fontSize: 15, fontWeight: FontWeight.w600, color: Tone.ink),
                ),
              ),
          ],
          onChanged: (value) => setState(() => _type = value ?? _type),
        ),
      ),
    );
  }

  Widget _messageField() {
    return Container(
      decoration: BoxDecoration(color: Tone.field, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: TextField(
        controller: _messageController,
        minLines: 8,
        maxLines: 14,
        maxLength: _messageMaxLength,
        decoration: InputDecoration(
          border: InputBorder.none,
          counterText: '',
          hintText: 'Bugs, ideas, anything at all...',
          hintStyle: GoogleFonts.fraunces(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Tone.muted,
            height: 1.4,
          ),
        ),
        style: GoogleFonts.fraunces(fontSize: 15, fontWeight: FontWeight.w600, color: Tone.ink, height: 1.4),
      ),
    );
  }

  Widget _errorBox(String message) {
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
              message,
              style: GoogleFonts.fraunces(fontSize: 13, fontWeight: FontWeight.w600, color: Tone.error),
            ),
          ),
        ],
      ),
    );
  }
}
