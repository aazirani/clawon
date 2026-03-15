import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';
import 'package:mobx/mobx.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/states/states.dart';
import '../../data/services/device_identity_service.dart';
import '../../domain/entities/connection.dart';
import '../../domain/entities/connection_state.dart' as domain;
import '../../domain/exceptions/duplicate_connection_exception.dart';
import '../../di/service_locator.dart';
import '../../utils/locale/app_localization.dart';
import '../../utils/routes/app_router.dart';
import '../settings/settings_screen.dart';
import 'store/connections_store.dart';

/// Premium connections list with redesigned cards and loading states.
/// Features connection cards with status indicators and quick actions.
class ConnectionsListScreen extends StatefulWidget {
  const ConnectionsListScreen({super.key});

  @override
  State<ConnectionsListScreen> createState() => _ConnectionsListScreenState();
}

class _ConnectionsListScreenState extends State<ConnectionsListScreen> {
  late final ConnectionsStore _connectionsStore;
  ReactionDisposer? _connectionErrorReaction;
  final Set<String> _shownErrors = {};

  @override
  void initState() {
    super.initState();
    _connectionsStore = getIt<ConnectionsStore>();
    // Load connections on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectionsStore.loadConnections();
      _setupConnectionErrorReaction();
    });
  }

  void _setupConnectionErrorReaction() {
    _connectionErrorReaction = reaction(
      (_) => Map<String, String?>.from(_connectionsStore.connectionErrors),
      (errors) {
        // Clear shown errors for connections that no longer have errors
        _shownErrors.removeWhere((id) => !errors.containsKey(id));

        // Show error notification for new errors
        for (final entry in errors.entries) {
          final connectionId = entry.key;
          final error = entry.value;
          final state = _connectionsStore.connectionStates[connectionId];

          // Show error for failed or pairingRequired states
          if (error != null &&
              error.isNotEmpty &&
              (state == domain.ConnectionState.failed ||
                  state == domain.ConnectionState.pairingRequired) &&
              !_shownErrors.contains(connectionId)) {
            _shownErrors.add(connectionId);

            if (state == domain.ConnectionState.pairingRequired) {
              // Show dialog with detailed pairing instructions
              _showPairingRequiredDialog(error);
            } else {
              // Show SnackBar for other errors
              _showErrorSnackBar(error);
            }
          }
        }
      },
    );
  }

  void _showPairingRequiredDialog(String requestId) {
    if (!mounted) return;
    final localizations = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.key_rounded,
          size: AppSpacing.iconDisplay,
          color: colorScheme.primary,
        ),
        title: Text(
          localizations.translate('pairing_required_title'),
          style: AppTypography.headlineSmall(colorScheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.translate('pairing_required_desc_prefix'),
              style: AppTypography.bodyMedium(colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.space3),
            _buildCodeBlock(
              'openclaw devices approve ${requestId.isNotEmpty ? requestId : 'REQUEST_ID'}',
            ),
            const SizedBox(height: AppSpacing.space3),
            Text(
              localizations.translate('pairing_required_desc_suffix'),
              style: AppTypography.bodyMedium(colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(localizations.translate('dismiss')),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeBlock(String code) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.space3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.space2),
      ),
      child: Text(
        code,
        style: AppTypography.bodySmall(colorScheme.onSurfaceVariant).copyWith(
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  void _showErrorSnackBar(String error) {
    if (!mounted) return;
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error,
          style: AppTypography.bodyMedium(colorScheme.onError),
        ),
        backgroundColor: colorScheme.error,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  void dispose() {
    _connectionErrorReaction?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.translate('connections_title'),
          style: AppTypography.titleLarge(colorScheme.onSurface),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              }
            },
            icon: const Icon(Icons.more_vert_rounded),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    const Icon(Icons.settings_outlined, size: 20),
                    const SizedBox(width: AppSpacing.space3),
                    Text(localizations.translate('settings_title')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Observer(
        builder: (_) {
          final connections = _connectionsStore.connections;
          final isLoading = _connectionsStore.isLoading;

          if (isLoading) {
            return _buildLoadingState();
          }

          if (connections.isEmpty) {
            return _buildEmptyState(context, localizations);
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingMobile,
              vertical: AppSpacing.space4,
            ),
            itemCount: connections.length,
            itemBuilder: (context, index) {
              final connection = connections[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.space3),
                child: _buildConnectionCard(context, connection, localizations),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddConnectionDialog,
        tooltip: localizations.translate('a11y_add_connection'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPaddingMobile,
        vertical: AppSpacing.space4,
      ),
      itemCount: 3,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.space3),
        child: SkeletonConnectionCard(),
      ),
    );
  }

  Widget _buildEmptyState(
      BuildContext context, AppLocalizations localizations) {
    return EmptyState.fromType(
      type: EmptyStateType.connections,
      customTitle: localizations.translate('connections_empty'),
      customDescription: localizations.translate('connections_add_first'),
      actionLabel: localizations.translate('add_connection_title'),
      onAction: _showAddConnectionDialog,
    );
  }

  Widget _buildConnectionCard(
    BuildContext context,
    Connection connection,
    AppLocalizations localizations,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColors = theme.statusColors;

    return Dismissible(
      key: Key(connection.id),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right → Edit (don't dismiss, just show dialog)
          _showEditConnectionDialog(connection);
          return false;
        } else {
          // Swipe left → Delete (show confirmation)
          return await _showDeleteConfirmationDialog(context, localizations);
        }
      },
      onDismissed: (direction) {
        // Only triggered for delete (edit returns false above)
        _connectionsStore.deleteConnection(connection.id);
      },
      // Edit background (swipe right → startToEnd)
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(AppSpacing.space3),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: AppSpacing.space6),
        child: Icon(
          Icons.edit_outlined,
          color: colorScheme.onPrimary,
          size: AppSpacing.iconLarge,
        ),
      ),
      // Delete background (swipe left → endToStart)
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
        decoration: BoxDecoration(
          color: colorScheme.error,
          borderRadius: BorderRadius.circular(AppSpacing.space3),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.space6),
        child: Icon(
          Icons.delete_outline_rounded,
          color: colorScheme.onError,
          size: AppSpacing.iconLarge,
        ),
      ),
      child: Observer(
        builder: (_) {
          // Directly access the observable map for proper MobX tracking
          final connectionState = _connectionsStore.connectionStates[connection.id]
              ?? domain.ConnectionState.disconnected;
          final isPaired = _connectionsStore.pairingStatus[connection.id] ?? false;
          final statusColor = _getStatusColor(connectionState, statusColors);

          return Semantics(
            label: connection.name,
            child: Card(
              margin: EdgeInsets.zero,
              child: InkWell(
                onTap: () => _navigateToSessions(context, connection),
                borderRadius: BorderRadius.circular(AppSpacing.space3),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(AppSpacing.space3),
                        ),
                        child: Center(
                          child: Text(
                            connection.name.isNotEmpty
                                ? connection.name[0].toUpperCase()
                                : '?',
                            style: AppTypography.titleMedium(
                              colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space3),
                      // Name and URL
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              connection.name,
                              style: AppTypography.titleMedium(
                                colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppSpacing.space1),
                            Text(
                              connection.gatewayUrl,
                              style: AppTypography.bodySmall(
                                colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space3),
                      // Status indicators
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Paired badge
                          if (isPaired) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.space2,
                                vertical: AppSpacing.space1,
                              ),
                              decoration: BoxDecoration(
                                color: statusColors.connected.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppSpacing.space1),
                              ),
                              child: Icon(
                                Icons.verified_user_outlined,
                                size: 14,
                                color: statusColors.connected,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.space2),
                          ],
                          // Connection status dot
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(domain.ConnectionState state, StatusColors statusColors) {
    switch (state) {
      case domain.ConnectionState.connected:
        return statusColors.connected;
      case domain.ConnectionState.connecting:
      case domain.ConnectionState.reconnecting:
        return statusColors.connecting;
      case domain.ConnectionState.failed:
      case domain.ConnectionState.pairingRequired:
        return statusColors.failed;
      case domain.ConnectionState.disconnected:
        return statusColors.disconnected;
    }
  }

  Future<bool?> _showDeleteConfirmationDialog(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            size: AppSpacing.iconDisplay,
            color: colorScheme.error,
          ),
          title: Text(
            localizations.translate('connections_delete_confirm'),
            style: AppTypography.headlineSmall(colorScheme.onSurface),
          ),
          content: Text(
            localizations.translate('connections_delete_confirm_message'),
            style: AppTypography.bodyMedium(colorScheme.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(localizations.translate('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              child: Text(localizations.translate('connection_delete')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddConnectionDialog() async {
    final result = await showModalBottomSheet<_AddConnectionResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _AddConnectionDialog(),
    );

    if (result != null && mounted) {
      try {
        await _connectionsStore.addConnection(
          name: result.name,
          gatewayUrl: result.gatewayUrl,
          token: result.token,
        );
      } on DuplicateConnectionException {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).translate('connection_duplicate'),
                style: AppTypography.bodyMedium(Theme.of(context).colorScheme.onError),
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  void _navigateToSessions(BuildContext context, Connection connection) {
    final uri = '${AppRouter.sessions.replaceFirst(':id', connection.id)}'
        '?connectionName=${Uri.encodeComponent(connection.name)}';
    context.push(uri);
  }

  Future<void> _showEditConnectionDialog(Connection connection) async {
    final result = await showModalBottomSheet<_AddConnectionResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _AddConnectionDialog(connection: connection),
    );

    if (result != null && mounted) {
      try {
        final updatedConnection = connection.copyWith(
          name: result.name,
          gatewayUrl: result.gatewayUrl,
          token: result.token,
        );
        await _connectionsStore.updateConnection(updatedConnection);
      } on DuplicateConnectionException {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).translate('connection_duplicate'),
                style: AppTypography.bodyMedium(Theme.of(context).colorScheme.onError),
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }
}

/// Result from the add/edit connection dialog
class _AddConnectionResult {
  final String name;
  final String gatewayUrl;
  final String token;

  _AddConnectionResult({
    required this.name,
    required this.gatewayUrl,
    required this.token,
  });
}

/// Dialog for adding or editing a connection
class _AddConnectionDialog extends StatefulWidget {
  final Connection? connection; // null for add mode, non-null for edit mode

  const _AddConnectionDialog({this.connection});

  @override
  State<_AddConnectionDialog> createState() => _AddConnectionDialogState();
}

class _AddConnectionDialogState extends State<_AddConnectionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _tokenController;
  bool _obscureToken = true;
  bool _isPaired = false;
  String? _deviceId;

  bool get _isEditMode => widget.connection != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.connection?.name ?? '');
    _urlController = TextEditingController(text: widget.connection?.gatewayUrl ?? '');
    _tokenController = TextEditingController(text: widget.connection?.token ?? '');

    // Check pairing status for edit mode
    if (_isEditMode) {
      _loadPairingStatus();
    }
  }

  Future<void> _loadPairingStatus() async {
    if (widget.connection == null) return;

    final deviceIdentityService = getIt<DeviceIdentityService>();
    final deviceToken = await deviceIdentityService.getDeviceToken(widget.connection!.id);
    final deviceIdentity = await deviceIdentityService.getDeviceIdentity();

    if (mounted) {
      setState(() {
        _isPaired = deviceToken != null && deviceToken.isNotEmpty;
        _deviceId = deviceIdentity.deviceId;
      });
    }
  }

  Future<void> _handleUnpair() async {
    final confirmed = await _showUnpairConfirmationDialog();
    if (confirmed && mounted) {
      final connectionsStore = getIt<ConnectionsStore>();
      await connectionsStore.unpairConnection(widget.connection!.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<bool> _showUnpairConfirmationDialog() async {
    final localizations = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.link_off_rounded,
          size: AppSpacing.iconDisplay,
          color: colorScheme.error,
        ),
        title: Text(
          localizations.translate('connection_unpair_confirm_title'),
          style: AppTypography.headlineSmall(colorScheme.onSurface),
        ),
        content: Text(
          localizations.translate('connection_unpair_confirm_message'),
          style: AppTypography.bodyMedium(colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations.translate('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            child: Text(localizations.translate('connection_unpair')),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      _AddConnectionResult(
        name: _nameController.text.trim(),
        gatewayUrl: _urlController.text.trim(),
        token: _tokenController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title row
            Padding(
              padding: const EdgeInsets.all(AppSpacing.space4),
              child: Row(
                children: [
                  Icon(
                    Icons.cable_rounded,
                    size: AppSpacing.iconLarge,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.space3),
                  Expanded(
                    child: Text(
                      localizations.translate(
                        _isEditMode ? 'edit_connection_title' : 'add_connection_title',
                      ),
                      style: AppTypography.headlineSmall(colorScheme.onSurface),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          // Content
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.space4),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name field
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: localizations.translate('connection_name_label'),
                      hintText: localizations.translate('connection_name_hint'),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return localizations.translate('connection_name_required');
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  // URL field
                  TextFormField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      labelText: localizations.translate('connection_url_label'),
                      hintText: localizations.translate('connection_url_hint'),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return localizations.translate('connection_url_required');
                      }
                      final trimmed = value.trim().toLowerCase();
                      if (!trimmed.startsWith('ws://') && !trimmed.startsWith('wss://')) {
                        return localizations.translate('connection_url_invalid');
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  // Token field OR Paired status
                  if (_isEditMode && _isPaired) ...[
                    // Paired status section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.space3),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(AppSpacing.space2),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                size: 20,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: AppSpacing.space2),
                              Text(
                                localizations.translate('connection_paired'),
                                style: AppTypography.titleSmall(colorScheme.primary),
                              ),
                            ],
                          ),
                          if (_deviceId != null) ...[
                            const SizedBox(height: AppSpacing.space2),
                            Text(
                              '${localizations.translate('connection_device_id')}: ${_deviceId!.substring(0, 8)}...',
                              style: AppTypography.bodySmall(colorScheme.onSurfaceVariant),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.space3),
                          OutlinedButton.icon(
                            onPressed: _handleUnpair,
                            icon: const Icon(Icons.link_off_rounded, size: 18),
                            label: Text(localizations.translate('connection_unpair')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Token field (for add mode or unpaired edit mode)
                    TextFormField(
                      controller: _tokenController,
                      decoration: InputDecoration(
                        labelText: localizations.translate('connection_token_label'),
                        hintText: localizations.translate('connection_token_hint'),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureToken ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(() => _obscureToken = !_obscureToken),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return localizations.translate('connection_token_required');
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.done,
                      obscureText: _obscureToken,
                      onFieldSubmitted: (_) => _handleSave(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space4, 0, AppSpacing.space4, AppSpacing.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(localizations.translate('cancel')),
                ),
                const SizedBox(height: AppSpacing.space2),
                if (!(_isEditMode && _isPaired))
                  FilledButton(
                    onPressed: _handleSave,
                    child: Text(localizations.translate('connection_save')),
                  ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
