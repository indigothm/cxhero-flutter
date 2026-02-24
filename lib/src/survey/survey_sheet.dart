import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/survey_config.dart';

/// Modal sheet for displaying surveys
class SurveySheet extends StatefulWidget {
  final SurveyRule rule;
  final ValueChanged<String> onSubmitOption;
  final ValueChanged<String> onSubmitText;
  final VoidCallback onClose;

  const SurveySheet({
    super.key,
    required this.rule,
    required this.onSubmitOption,
    required this.onSubmitText,
    required this.onClose,
  });

  @override
  State<SurveySheet> createState() => _SurveySheetState();
}

class _SurveySheetState extends State<SurveySheet> {
  String _textResponse = '';
  String? _selectedOption;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF7F7F7);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Close button at top
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () {
                    _dismissKeyboard();
                    widget.onClose();
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.onSurface.withOpacity(0.1),
                    ),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  _buildHeader(colorScheme),
                  const SizedBox(height: 24),
                  // Response content
                  _buildResponseContent(isDark, colorScheme),
                ],
              ),
            ),
          ),

          // Submit button (if applicable)
          if (_hasSubmitButton) _buildSubmitButton(isDark, colorScheme),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Column(
      children: [
        Text(
          widget.rule.title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          widget.rule.message,
          style: TextStyle(
            fontSize: 16,
            color: colorScheme.onSurface.withOpacity(0.7),
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildResponseContent(bool isDark, ColorScheme colorScheme) {
    return switch (widget.rule.response) {
      SurveyResponseOptions(:final options) => _buildOptionsContent(options, isDark, colorScheme),
      SurveyResponseText(:final config) => _buildTextContent(config, isDark, colorScheme),
      SurveyResponseCombined(:final config) => _buildCombinedContent(config, isDark, colorScheme),
    };
  }

  Widget _buildOptionsContent(List<String> options, bool isDark, ColorScheme colorScheme) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: options.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        return RatingButton(
          label: option,
          isDark: isDark,
          isFirst: index == 0,
          isLast: index == options.length - 1,
          onTap: () {
            _dismissKeyboard();
            widget.onSubmitOption(option);
          },
        );
      }).toList(),
    );
  }

  Widget _buildTextContent(TextResponseConfig config, bool isDark, ColorScheme colorScheme) {
    return _buildTextField(
      isDark: isDark,
      colorScheme: colorScheme,
      placeholder: config.placeholder,
      maxLength: config.maxLength,
    );
  }

  Widget _buildCombinedContent(CombinedResponseConfig config, bool isDark, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rating buttons
        if (config.optionsLabel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              config.optionsLabel!,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: config.options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            return SelectableRatingButton(
              label: option,
              isDark: isDark,
              isSelected: _selectedOption == option,
              onTap: () {
                _dismissKeyboard();
                setState(() => _selectedOption = option);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        // Text field
        if (config.textField != null)
          _buildTextField(
            isDark: isDark,
            colorScheme: colorScheme,
            label: config.textField!.label,
            placeholder: config.textField!.placeholder,
            maxLength: config.textField!.maxLength,
          ),
      ],
    );
  }

  Widget _buildTextField({
    required bool isDark,
    required ColorScheme colorScheme,
    String? label,
    String? placeholder,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2E2E2E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.onSurface.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: TextField(
            onChanged: (value) => setState(() => _textResponse = value),
            maxLines: 4,
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.4),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
        if (maxLength != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_textResponse.length}/$maxLength',
                style: TextStyle(
                  fontSize: 12,
                  color: _textResponse.length > maxLength
                      ? Colors.red
                      : colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSubmitButton(bool isDark, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF7F7F7),
        border: Border(
          top: BorderSide(
            color: colorScheme.onSurface.withOpacity(0.1),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: SafeArea(
        top: false,
        child: ElevatedButton(
          onPressed: _canSubmit ? () => _submit() : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            disabledBackgroundColor: colorScheme.onSurface.withOpacity(0.3),
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            _submitLabel,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    _dismissKeyboard();
    final response = switch (widget.rule.response) {
      SurveyResponseCombined(:final config) => _buildCombinedResponse(config),
      SurveyResponseText() => _trimmedText,
      _ => '',
    };
    widget.onSubmitText(response);
  }

  String _buildCombinedResponse(CombinedResponseConfig config) {
    if (_selectedOption == null) return '';
    if (_textResponse.trim().isEmpty) return _selectedOption!;
    return '${_selectedOption!}||${_textResponse.trim()}';
  }

  void _dismissKeyboard() {
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  bool get _hasSubmitButton {
    return switch (widget.rule.response) {
      SurveyResponseOptions() => false,
      SurveyResponseText() || SurveyResponseCombined() => true,
    };
  }

  String get _submitLabel {
    return switch (widget.rule.response) {
      SurveyResponseText(:final config) => config.submitLabel ?? 'Submit Feedback',
      SurveyResponseCombined(:final config) => config.submitLabel ?? 'Submit Feedback',
      _ => 'Submit',
    };
  }

  bool get _canSubmit {
    return switch (widget.rule.response) {
      SurveyResponseText(:final config) => _canSubmitText(config),
      SurveyResponseCombined(:final config) => _canSubmitCombined(config),
      _ => false,
    };
  }

  bool _canSubmitText(TextResponseConfig config) {
    final trimmed = _trimmedText;
    if (config.maxLength != null && trimmed.length > config.maxLength!) return false;
    if (config.minLength != null && trimmed.length < config.minLength!) return false;
    if (!config.allowEmpty && trimmed.isEmpty) return false;
    return true;
  }

  bool _canSubmitCombined(CombinedResponseConfig config) {
    if (_selectedOption == null) return false;
    if (config.textField?.required == true) {
      final trimmed = _textResponse.trim();
      if (trimmed.isEmpty) return false;
      if (config.textField!.minLength != null &&
          trimmed.length < config.textField!.minLength!) {
        return false;
      }
    }
    if (config.textField != null && _textResponse.isNotEmpty) {
      final trimmed = _textResponse.trim();
      if (config.textField!.maxLength != null &&
          trimmed.length > config.textField!.maxLength!) {
        return false;
      }
      if (config.textField!.minLength != null &&
          trimmed.length < config.textField!.minLength!) {
        return false;
      }
    }
    return true;
  }

  String get _trimmedText {
    final config = switch (widget.rule.response) {
      SurveyResponseText(:final config) => config,
      _ => null,
    };
    var trimmed = _textResponse.trim();
    if (config?.maxLength != null && trimmed.length > config!.maxLength!) {
      trimmed = trimmed.substring(0, config.maxLength);
    }
    return trimmed;
  }
}

/// Rating button for option responses
class RatingButton extends StatelessWidget {
  final String label;
  final bool isDark;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const RatingButton({
    super.key,
    required this.label,
    required this.isDark,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 80,
          height: 90,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2E2E2E) : Colors.white,
            borderRadius: BorderRadius.horizontal(
              left: isFirst ? const Radius.circular(12) : Radius.zero,
              right: isLast ? const Radius.circular(12) : Radius.zero,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _emojiFor(label),
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Selectable rating button for combined responses
class SelectableRatingButton extends StatelessWidget {
  final String label;
  final bool isDark;
  final bool isSelected;
  final VoidCallback onTap;

  const SelectableRatingButton({
    super.key,
    required this.label,
    required this.isDark,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 70,
        height: 90,
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : (isDark ? const Color(0xFF2E2E2E) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
              blurRadius: isSelected ? 12 : 8,
              offset: Offset(0, isSelected ? 4 : 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _emojiFor(label),
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

String _emojiFor(String label) {
  final lower = label.toLowerCase();

  // Common rating words to emoji mapping
  if (lower.contains('poor') || lower.contains('bad') || label == '1') {
    return '😞';
  } else if (lower.contains('fair') || lower.contains('okay') || label == '2') {
    return '😐';
  } else if (lower.contains('good') || label == '3') {
    return '🙂';
  } else if (lower.contains('great') || lower.contains('very good') || label == '4') {
    return '😊';
  } else if (lower.contains('excellent') || lower.contains('amazing') ||
      lower.contains('outstanding') || label == '5') {
    return '🤩';
  }

  // Numeric ratings 1-10
  if (int.tryParse(label) case final number?) {
    return switch (number) {
      1 || 2 => '😞',
      3 || 4 => '😐',
      5 || 6 => '🙂',
      7 || 8 => '😊',
      9 || 10 => '🤩',
      _ => '⭐',
    };
  }

  return '⭐';
}
