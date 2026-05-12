import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';

/// Reusable dropdown for selecting a supported language.
///
/// Displays language names with flag emojis.
class LanguageDropdown extends StatelessWidget {
  /// Currently selected language code.
  final String value;

  /// Called when the selection changes.
  final ValueChanged<String>? onChanged;

  /// Optional label text for the dropdown.
  final String? labelText;

  /// Optional prefix icon.
  final IconData? prefixIcon;

  /// Creates a [LanguageDropdown].
  const LanguageDropdown({
    super.key,
    required this.value,
    this.onChanged,
    this.labelText,
    this.prefixIcon,
  });

  static const Map<String, String> _languageFlags = {
    'en': '\u{1F1EC}\u{1F1E7}',
    'fr': '\u{1F1EB}\u{1F1F7}',
    'ar': '\u{1F1E6}\u{1F1EA}',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: labelText ?? 'Language',
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        border: const OutlineInputBorder(),
      ),
      items: AppConstants.supportedLanguages.entries.map((entry) {
        final flag = _languageFlags[entry.key] ?? '\u{1F310}';
        return DropdownMenuItem(
          value: entry.key,
          child: Text(
            '$flag ${entry.value}',
            style: theme.textTheme.bodyMedium,
          ),
        );
      }).toList(),
      onChanged: onChanged != null
          ? (String? newValue) {
              if (newValue != null) {
                onChanged!(newValue);
              }
            }
          : null,
    );
  }
}
