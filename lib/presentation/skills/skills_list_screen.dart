import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';
import 'package:mobx/mobx.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/states/states.dart';
import '../../data/models/skill.dart';
import '../../data/repositories/skills_repository_impl.dart';
import '../../di/service_locator.dart';
import '../../domain/entities/agent.dart';
import '../../domain/entities/connection_state.dart' as claw;
import '../../domain/repositories/chat_repository.dart';
import '../../utils/locale/app_localization.dart';
import '../../utils/routes/app_router.dart';
import 'skill_detail_screen.dart';
import 'skills_store.dart';
import 'widgets/skill_card.dart';

/// Premium skills management screen with sectioned list.
/// Features enabled, disabled, and unavailable skill sections.
class SkillsListScreen extends StatefulWidget {
  final String connectionId;

  const SkillsListScreen({super.key, required this.connectionId});

  @override
  State<SkillsListScreen> createState() => _SkillsListScreenState();
}

class _SkillsListScreenState extends State<SkillsListScreen> {
  late final SkillsStore _skillsStore;
  late final SkillsRepositoryImpl _skillsRepository;
  late final ChatRepository _chatRepository;

  final _connectionStateObs = Observable<claw.ConnectionState>(claw.ConnectionState.disconnected);
  StreamSubscription<claw.ConnectionStatus>? _connectionSubscription;

  final _agentsObs = ObservableList<Agent>();
  final _isLoadingAgentsObs = Observable<bool>(false);
  final _selectedAgentObs = Observable<Agent?>(null);

  @override
  void initState() {
    super.initState();

    _chatRepository = getIt<ChatRepository>();
    _skillsRepository = SkillsRepositoryImpl(
      _chatRepository,
      widget.connectionId,
    );
    _skillsStore = SkillsStore(_skillsRepository);

    // Seed initial state synchronously so the UI shows the correct status on first build
    final ws = _chatRepository.getWebSocketConnection(widget.connectionId);
    if (ws != null) {
      _connectionStateObs.value = ws.state;
    }

    _connectionSubscription = _chatRepository
        .connectionStatus(widget.connectionId)
        .listen((status) {
      if (mounted) runInAction(() => _connectionStateObs.value = status.state);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAgentsAndSkills();
    });
  }

  Future<void> _fetchAgentsAndSkills() async {
    runInAction(() => _isLoadingAgentsObs.value = true);
    try {
      final agents = await _chatRepository.fetchAgents(widget.connectionId);
      if (mounted) {
        runInAction(() {
          _agentsObs
            ..clear()
            ..addAll(agents);
          _isLoadingAgentsObs.value = false;
        });
      }
      if (agents.isNotEmpty) {
        if (_selectedAgentObs.value == null || !agents.any((a) => a.id == _selectedAgentObs.value!.id)) {
          runInAction(() => _selectedAgentObs.value = agents.first);
        }
        await _skillsStore.fetchSkills(agentId: _selectedAgentObs.value!.id);
      } else {
        await _skillsStore.fetchSkills();
      }
    } catch (e) {
      if (mounted) runInAction(() => _isLoadingAgentsObs.value = false);
      await _skillsStore.fetchSkills();
    }
  }

  void _onAgentSelected(Agent agent) {
    runInAction(() => _selectedAgentObs.value = agent);
    _skillsStore.fetchSkills(agentId: agent.id);
  }

  Widget _buildAgentFilterRow() {
    if (_isLoadingAgentsObs.value) {
      return const SizedBox(
        height: 48,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_agentsObs.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPaddingMobile,
          vertical: AppSpacing.space2,
        ),
        itemCount: _agentsObs.length,
        separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.space2),
        itemBuilder: (context, index) {
          final agent = _agentsObs[index];
          return FilterChip(
            label: Text(agent.displayLabel),
            selected: _selectedAgentObs.value?.id == agent.id,
            onSelected: (_) => _onAgentSelected(agent),
            showCheckmark: false,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final statusColors = Theme.of(context).statusColors;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.translate('skills_title'),
              style: AppTypography.titleLarge(colorScheme.onSurface),
            ),
            Observer(builder: (_) {
              final connectionState = _connectionStateObs.value;
              String statusText;
              Color statusColor;
              switch (connectionState) {
                case claw.ConnectionState.connected:
                  statusText = localizations.translate('connection_connected');
                  statusColor = statusColors.connected;
                  break;
                case claw.ConnectionState.connecting:
                case claw.ConnectionState.reconnecting:
                  statusText = localizations.translate('connection_connecting');
                  statusColor = statusColors.connecting;
                  break;
                case claw.ConnectionState.failed:
                  statusText = localizations.translate('connection_failed');
                  statusColor = statusColors.failed;
                  break;
                default:
                  statusText = localizations.translate('connection_disconnected');
                  statusColor = statusColors.disconnected;
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  Text(
                    statusText,
                    style: AppTypography.labelSmall(colorScheme.onSurfaceVariant),
                  ),
                ],
              );
            }),
          ],
        ),
        actions: [
          // Connect/Disconnect button
          Observer(builder: (_) {
            final isConnected = _connectionStateObs.value.isConnected;
            final isConnecting = _connectionStateObs.value.isConnecting;
            return IconButton(
              onPressed: isConnecting
                  ? null
                  : isConnected
                      ? () => _chatRepository.disconnect(widget.connectionId)
                      : () => _chatRepository.connect(widget.connectionId),
              tooltip: isConnected
                  ? localizations.translate('settings_disconnect')
                  : localizations.translate('settings_reconnect'),
              icon: isConnecting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onSurface,
                      ),
                    )
                  : Icon(isConnected ? Icons.link_off_rounded : Icons.link_rounded),
            );
          }),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') {
                context.push(AppRouter.settings);
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
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Observer(builder: (_) => _buildAgentFilterRow()),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _fetchAgentsAndSkills(),
                child: Observer(
                  builder: (_) {
                    final isLoading = _skillsStore.isLoading;
                    final errorMessage = _skillsStore.errorMessage;

                    if (isLoading) {
                      return _buildLoadingState();
                    }

                    if (errorMessage != null) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height * 0.7,
                          child: EmptyState.fromType(
                            type: EmptyStateType.error,
                            customDescription: errorMessage,
                            actionLabel: localizations.translate('retry'),
                            onAction: () => _fetchAgentsAndSkills(),
                          ),
                        ),
                      );
                    }

                    if (_skillsStore.skills.isEmpty) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height * 0.7,
                          child: EmptyState.fromType(
                            type: EmptyStateType.skills,
                            customTitle: localizations.translate('skills_empty'),
                            customDescription: localizations.translate('skills_empty_description'),
                          ),
                        ),
                      );
                    }

                    return _buildSectionedList(context, localizations);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Observer(builder: (_) {
        final isConnected = _connectionStateObs.value.isConnected;
        final selectedAgent = _selectedAgentObs.value;
        return FloatingActionButton(
          onPressed: isConnected
              ? () async {
                  final agentParam = selectedAgent != null
                      ? '?agentId=${Uri.encodeComponent(selectedAgent.id)}'
                      : '';
                  await context.push(
                    '/connections/${widget.connectionId}/skills/create$agentParam',
                  );
                  _skillsStore.fetchSkills(agentId: selectedAgent?.id);
                }
              : null,
          tooltip: localizations.translate('skill_create_title'),
          child: Icon(isConnected ? Icons.add : Icons.block),
        );
      }),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPaddingMobile,
        vertical: AppSpacing.space4,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.space3),
        child: SkeletonConnectionCard(),
      ),
    );
  }

  Widget _buildSectionedList(BuildContext context, AppLocalizations localizations) {
    final colorScheme = Theme.of(context).colorScheme;

    return Observer(
      builder: (_) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.space4),
          children: [
            // Enabled Skills
            if (_skillsStore.enabledSkills.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPaddingMobile,
                ),
                child: _SectionHeader(
                  title: localizations.translate('skill_enabled'),
                  count: _skillsStore.enabledSkills.length,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.space2),
              ..._skillsStore.enabledSkills.map((s) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPaddingMobile,
                      vertical: AppSpacing.space1,
                    ),
                    child: SkillCard(
                      skill: s,
                      onTap: () => _showSkillDetails(context, s),
                    ),
                  )),
              const SizedBox(height: AppSpacing.space4),
            ],

            // Disabled Skills
            if (_skillsStore.disabledSkills.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPaddingMobile,
                ),
                child: _SectionHeader(
                  title: localizations.translate('skill_disabled'),
                  count: _skillsStore.disabledSkills.length,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.space2),
              ..._skillsStore.disabledSkills.map((s) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPaddingMobile,
                      vertical: AppSpacing.space1,
                    ),
                    child: SkillCard(
                      skill: s,
                      onTap: () => _showSkillDetails(context, s),
                    ),
                  )),
              const SizedBox(height: AppSpacing.space4),
            ],

            // Unavailable Skills
            if (_skillsStore.unavailableSkills.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPaddingMobile,
                ),
                child: _SectionHeader(
                  title: localizations.translate('skills_unavailable'),
                  count: _skillsStore.unavailableSkills.length,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: AppSpacing.space2),
              ..._skillsStore.unavailableSkills.map((s) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPaddingMobile,
                      vertical: AppSpacing.space1,
                    ),
                    child: SkillCard(
                      skill: s,
                      onTap: () => _showSkillDetails(context, s),
                    ),
                  )),
            ],
          ],
        );
      },
    );
  }

  void _showSkillDetails(BuildContext context, Skill skill) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SkillDetailScreen(
          skill: skill,
          agentId: _selectedAgentObs.value?.id,
          skillsStore: _skillsStore,
          skillsRepository: _skillsRepository,
        ),
      ),
    );
  }
}

/// Premium section header with count badge.
class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: AppTypography.labelLarge(color),
        ),
        const SizedBox(width: AppSpacing.space2),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space2,
            vertical: AppSpacing.space1,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSpacing.space2),
          ),
          child: Text(
            count.toString(),
            style: AppTypography.labelSmall(color),
          ),
        ),
      ],
    );
  }
}
