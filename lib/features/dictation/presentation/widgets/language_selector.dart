import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';

/// A dropdown button for selecting the dictation language.
///
/// Shows "Select language..." as hint when no language is selected.
/// Displays options from [AppConstants.supportedLanguages].
/// Disabled when recording is active with a tooltip explaining why.
class LanguageSelector extends StatelessWidget {
  /// Currently selected language code (e.g., 'en', 'fr', 'ar') or null.
  final String? selectedLanguage;

  /// Called when the user selects a different language.
  final ValueChanged<String?> onChanged;

  /// Whether the dropdown is interactive.
  final bool enabled;

  const LanguageSelector({
    super.key,
    required this.selectedLanguage,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget dropdown = DropdownButtonFormField<String?>(
      value: selectedLanguage,
      isExpanded: true,
      decoration: InputDecoration(
        filled: true,
        fillColor: enabled
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.surfaceContainerHighest.withAlpha(128),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      hint: Text(
        'Select language...',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      icon: Icon(
        Icons.keyboard_arrow_down,
        color: enabled
            ? theme.colorScheme.onSurfaceVariant
            : theme.colorScheme.onSurfaceVariant.withAlpha(128),
      ),
      items: [
        // Hint item (select none)
        DropdownMenuItem<String?>(
          value: null,
          child: Text(
            'Select language...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        // Language options
        ...AppConstants.supportedLanguages.entries.map((entry) {
          return DropdownMenuItem<String?>(
            value: entry.key,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LanguageFlag(languageCode: entry.key),
                const SizedBox(width: 12),
                Text(entry.value),
              ],
            ),
          );
        }),
      ],
      onChanged: enabled
          ? (value) => onChanged(value)
          : null,
      style: theme.textTheme.bodyMedium,
      dropdownColor: theme.colorScheme.surfaceContainerHighest,
    );

    if (!enabled) {
      dropdown = Tooltip(
        message: 'Language locked during recording',
        child: IgnorePointer(child: dropdown),
      );
    }

    return SizedBox(
      width: 220,
      child: dropdown,
    );
  }
}

/// Small circular flag/indicator for a language.
class _LanguageFlag extends StatelessWidget {
  final String languageCode;

  const _LanguageFlag({required this.languageCode});

  @override
  Widget build(BuildContext context) {
    final (String emoji, String label) = switch (languageCode) {
      'en' => ('🇬🇧', 'English'),
      'fr' => ('🇫🇷', 'French'),
      'ar' => ('🇸🇦', 'Arabic'),
      _ => ('🌐', 'Unknown'),
    };

    return Tooltip(
      message: label,
      child: Text(
        emoji,
        style: const TextStyle(fontSize: 18),
      ),
    );
  }
}
