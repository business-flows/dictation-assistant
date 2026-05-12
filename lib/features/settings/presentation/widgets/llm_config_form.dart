import 'package:flutter/material.dart';

import '../../domain/entities/settings_entity.dart';

/// Form widget for LLM configuration.
///
/// Provides text fields for endpoint URL, API token, model name,
/// and system prompt. Also includes a test connection button.
class LlmConfigForm extends StatefulWidget {
  /// Current settings values.
  final SettingsEntity settings;

  /// Called when any field changes.
  final ValueChanged<SettingsEntity> onChanged;

  /// Called when the test connection button is tapped.
  final VoidCallback? onTestConnection;

  /// Whether a connection test is in progress.
  final bool isTestingConnection;

  /// Creates a [LlmConfigForm].
  const LlmConfigForm({
    super.key,
    required this.settings,
    required this.onChanged,
    this.onTestConnection,
    this.isTestingConnection = false,
  });

  @override
  State<LlmConfigForm> createState() => _LlmConfigFormState();
}

class _LlmConfigFormState extends State<LlmConfigForm> {
  late final TextEditingController _urlController;
  late final TextEditingController _tokenController;
  late final TextEditingController _modelController;
  late final TextEditingController _promptController;
  bool _obscureToken = true;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.settings.llmEndpointUrl ?? '');
    _tokenController = TextEditingController(text: widget.settings.llmApiToken ?? '');
    _modelController = TextEditingController(text: widget.settings.llmModelName ?? '');
    _promptController = TextEditingController(text: widget.settings.llmSystemPrompt ?? '');
    _setupListeners();
  }

  @override
  void didUpdateWidget(LlmConfigForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controllers if settings changed externally
    if (widget.settings.llmEndpointUrl != oldWidget.settings.llmEndpointUrl &&
        widget.settings.llmEndpointUrl != _urlController.text) {
      _urlController.text = widget.settings.llmEndpointUrl ?? '';
    }
    if (widget.settings.llmModelName != oldWidget.settings.llmModelName &&
        widget.settings.llmModelName != _modelController.text) {
      _modelController.text = widget.settings.llmModelName ?? '';
    }
    if (widget.settings.llmSystemPrompt != oldWidget.settings.llmSystemPrompt &&
        widget.settings.llmSystemPrompt != _promptController.text) {
      _promptController.text = widget.settings.llmSystemPrompt ?? '';
    }
  }

  void _setupListeners() {
    _urlController.addListener(_notifyChange);
    _tokenController.addListener(_notifyChange);
    _modelController.addListener(_notifyChange);
    _promptController.addListener(_notifyChange);
  }

  void _notifyChange() {
    widget.onChanged(
      widget.settings.copyWith(
        llmEndpointUrl: _urlController.text.isEmpty ? null : _urlController.text,
        llmApiToken: _tokenController.text.isEmpty ? null : _tokenController.text,
        llmModelName: _modelController.text.isEmpty ? null : _modelController.text,
        llmSystemPrompt: _promptController.text.isEmpty ? null : _promptController.text,
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    _modelController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            labelText: 'LLM Endpoint URL',
            hintText: 'https://api.openai.com/v1/chat/completions',
            prefixIcon: Icon(Icons.link),
            helperText: 'OpenAI-compatible API endpoint',
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _tokenController,
          decoration: InputDecoration(
            labelText: 'API Token',
            hintText: 'sk-...',
            prefixIcon: const Icon(Icons.vpn_key),
            helperText: 'Stored securely in keychain/keystore',
            suffixIcon: IconButton(
              icon: Icon(
                _obscureToken ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () => setState(() => _obscureToken = !_obscureToken),
            ),
          ),
          obscureText: _obscureToken,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _modelController,
          decoration: const InputDecoration(
            labelText: 'Model Name',
            hintText: 'gpt-4o',
            prefixIcon: Icon(Icons.smart_toy),
            helperText: 'Model identifier for the API',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _promptController,
          decoration: const InputDecoration(
            labelText: 'System Prompt',
            hintText: 'Instructions for text refinement...',
            prefixIcon: Icon(Icons.chat_bubble_outline),
            helperText: 'Sent to the LLM with each refinement request',
            alignLabelWithHint: true,
          ),
          maxLines: 4,
          minLines: 2,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: widget.isTestingConnection ? null : widget.onTestConnection,
            icon: widget.isTestingConnection
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.network_check),
            label: Text(
              widget.isTestingConnection ? 'Testing...' : 'Test Connection',
            ),
          ),
        ),
      ],
    );
  }
}
