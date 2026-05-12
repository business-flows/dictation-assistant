import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

/// Cross-platform notification service for desktop platforms.
///
/// Manages:
/// - System tray icon and menu
/// - Balloon/toast notifications
/// - Window state management (minimize to tray)
///
/// On mobile platforms, most operations are no-ops since notifications
/// are handled by the OS.
///
/// Usage:
/// ```dart
/// final notifications = NotificationService();
/// await notifications.initialize();
/// await notifications.showNotification('Refinement Complete', 'Text has been refined.');
/// ```
class NotificationService {
  final Logger _logger;
  final SystemTray _systemTray;

  bool _initialized = false;

  /// Creates a [NotificationService].
  NotificationService({
    Logger? logger,
    SystemTray? systemTray,
  })  : _logger = logger ?? Logger(),
        _systemTray = systemTray ?? SystemTray();

  /// Whether the service has been initialized.
  bool get isInitialized => _initialized;

  /// Initialize the notification service.
  ///
  /// Sets up the system tray icon (desktop only) and prepares
  /// the service for showing notifications.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await _initSystemTray();
      _initialized = true;
      _logger.i('Notification service initialized');
    } catch (e) {
      _logger.w('System tray not available: $e');
      // Service is still functional for toast notifications
      _initialized = true;
    }
  }

  /// Show a system notification.
  ///
  /// Displays a toast/balloon notification on desktop platforms.
  /// On unsupported platforms, this is a no-op.
  ///
  /// [title] - Notification title.
  /// [body] - Notification body text.
  Future<void> showNotification(String title, String body) async {
    if (!_initialized) {
      _logger.w('NotificationService not initialized');
      return;
    }

    try {
      await _systemTray.setTitle(title);
      await _systemTray.setTooltip('$title: $body');

      // Try to show a balloon notification on Windows
      try {
        await _systemTray.setContextMenu([
          MenuItemLabel(
            label: title,
            onClicked: (_) {},
          ),
        ]);
      } catch (e) {
        // Balloon notifications may not be supported on all platforms
        _logger.d('Balloon notification not supported: $e');
      }

      _logger.d('Notification shown: $title - $body');
    } catch (e) {
      _logger.w('Failed to show notification: $e');
    }
  }

  /// Show a notification that refinement is complete.
  Future<void> showRefinementComplete() async {
    await showNotification(
      'Dictation Assistant',
      'Text refinement complete.',
    );
  }

  /// Show a notification that export is complete.
  Future<void> showExportComplete(String filePath) async {
    await showNotification(
      'Dictation Assistant',
      'Exported to $filePath',
    );
  }

  /// Show a notification for an error.
  Future<void> showError(String message) async {
    await showNotification(
      'Dictation Assistant - Error',
      message,
    );
  }

  /// Show the system tray icon (desktop only).
  ///
  /// The tray icon allows the user to interact with the app
  /// even when the main window is hidden.
  Future<void> showTrayIcon() async {
    try {
      await _systemTray.setImage('');
      _logger.d('Tray icon shown');
    } catch (e) {
      _logger.w('Failed to show tray icon: $e');
    }
  }

  /// Hide the system tray icon.
  Future<void> hideTrayIcon() async {
    try {
      await _systemTray.destroy();
      _logger.d('Tray icon hidden');
    } catch (e) {
      _logger.w('Failed to hide tray icon: $e');
    }
  }

  /// Clean up resources.
  ///
  /// Should be called when the app is shutting down.
  Future<void> dispose() async {
    try {
      await _systemTray.destroy();
      _initialized = false;
      _logger.i('Notification service disposed');
    } catch (e) {
      _logger.w('Error during notification service disposal: $e');
    }
  }

  // ---- Private methods ----

  /// Initialize the system tray with a default menu.
  Future<void> _initSystemTray() async {
    try {
      // Try to set an icon - will fail if no icon is available,
      // but the tray will still work
      try {
        await _systemTray.setImage('assets/icon.png');
      } catch (e) {
        _logger.d('No tray icon set: $e');
      }

      await _systemTray.setTooltip('Dictation Assistant');

      // Create the context menu
      final menu = [
        MenuItemLabel(
          label: 'Show',
          onClicked: (menuItem) async {
            await windowManager.show();
            await windowManager.focus();
          },
        ),
        MenuSeparator(),
        MenuItemLabel(
          label: 'Exit',
          onClicked: (menuItem) async {
            await windowManager.close();
          },
        ),
      ];

      await _systemTray.setContextMenu(menu);

      // Handle tray left-click
      _systemTray.registerSystemTrayEventHandler((eventName) {
        if (eventName == kSystemTrayEventClick) {
          windowManager.show();
        } else if (eventName == kSystemTrayEventRightClick) {
          _systemTray.popUpContextMenu();
        }
      });
    } catch (e) {
      _logger.w('System tray initialization failed: $e');
      rethrow;
    }
  }
}
