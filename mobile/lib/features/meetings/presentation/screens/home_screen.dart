// lib/features/meetings/presentation/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/meeting_provider.dart';
import '../../data/repositories/meeting_repository.dart';
import '../../../../main.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(meetingsProvider.notifier).loadMeetings();
      ref.read(meetingsProvider.notifier).startPolling();
    });
  }

  @override
  void dispose() {
    ref.read(meetingsProvider.notifier).stopPolling();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  Future<void> _confirmDelete(String id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete meeting?'),
        content: Text('"$title" will be permanently deleted.',
            style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(meetingsProvider.notifier).deleteMeeting(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(meetingsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen<MeetingsState>(meetingsProvider, (prev, next) {
      if (next.completedMeetingId != null) {
        final meeting = next.meetings
            .where((m) => m.id == next.completedMeetingId)
            .firstOrNull;
        if (meeting != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${meeting.title}" is ready'),
              action: SnackBarAction(
                label: 'View',
                onPressed: () {
                  context.push('/meeting/${meeting.id}');
                  ref
                      .read(meetingsProvider.notifier)
                      .clearCompletedNotification();
                },
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
        ref.read(meetingsProvider.notifier).clearCompletedNotification();
      }
    });

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(meetingsProvider.notifier).loadMeetings(),
        child: CustomScrollView(
          slivers: [
            // ── Cinematic SliverAppBar ─────────────────────────────────
            SliverAppBar(
              expandedHeight: 120,
              floating: true,
              pinned: true,
              elevation: 0,
              scrolledUnderElevation: 0.5,
              backgroundColor:
                  isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                title: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.mic,
                          color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Clareon',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF2563EB)
                            .withOpacity(isDark ? 0.12 : 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    themeMode == ThemeMode.dark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    size: 20,
                  ),
                  onPressed: () {
                    ref.read(themeModeProvider.notifier).state =
                        themeMode == ThemeMode.light
                            ? ThemeMode.dark
                            : ThemeMode.light;
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  onPressed: () => context.go('/login'),
                ),
                const SizedBox(width: 4),
              ],
            ),

            // ── Stats Strip ────────────────────────────────────────────
            if (state.meetings.isNotEmpty)
              SliverToBoxAdapter(
                child: _StatsStrip(meetings: state.meetings),
              ),

            // ── Meeting List ───────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: _buildSliver(state, isDark),
            ),
          ],
        ),
      ),
      floatingActionButton: _RecordFAB(
        onPressed: () => context.push('/record'),
      ),
    );
  }

  Widget _buildSliver(MeetingsState state, bool isDark) {
    if (state.status == MeetingsStatus.loading && state.meetings.isEmpty) {
      return const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()));
    }
    if (state.status == MeetingsStatus.error && state.meetings.isEmpty) {
      return SliverFillRemaining(
        child: _EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Connection issue',
          subtitle: state.errorMessage ?? 'Could not load meetings',
          actionLabel: 'Retry',
          onAction: () => ref.read(meetingsProvider.notifier).loadMeetings(),
        ),
      );
    }
    if (state.meetings.isEmpty) {
      return const SliverFillRemaining(
        child: _EmptyState(
          icon: Icons.mic_none_rounded,
          title: 'No meetings yet',
          subtitle: 'Tap the button below to start recording',
        ),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final meeting = state.meetings[index];
          final isViewable =
              meeting.status == 'completed' || meeting.status == 'ready';
          return _MeetingCard(
            meeting: meeting,
            formatDate: _formatDate,
            formatDuration: _formatDuration,
            onDelete: () => _confirmDelete(meeting.id, meeting.title),
            onTap: isViewable
                ? () => context.push('/meeting/${meeting.id}')
                : null,
          );
        },
        childCount: state.meetings.length,
      ),
    );
  }
}

// ─── Stats Strip ──────────────────────────────────────────────────────────────

class _StatsStrip extends StatelessWidget {
  final List<Meeting> meetings;
  const _StatsStrip({required this.meetings});

  @override
  Widget build(BuildContext context) {
    final completed =
        meetings.where((m) => m.status == 'completed' || m.status == 'ready').length;
    final processing =
        meetings.where((m) => m.status == 'processing').length;
    final totalMinutes =
        meetings.fold<int>(0, (sum, m) => sum + (m.durationSeconds ~/ 60));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 76,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131827) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.07)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          _StatCell(value: '${meetings.length}', label: 'Total'),
          _Vdivider(),
          _StatCell(value: '$completed', label: 'Ready'),
          _Vdivider(),
          _StatCell(value: '${totalMinutes}m', label: 'Recorded'),
          if (processing > 0) ...[
            _Vdivider(),
            _StatCell(
              value: '$processing',
              label: 'Processing',
              valueColor: const Color(0xFFF59E0B),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;
  const _StatCell(
      {required this.value, required this.label, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: valueColor ??
                  Theme.of(context).textTheme.headlineSmall?.color,
            ),
          ),
          const SizedBox(height: 2),
          const Text('',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }
}

class _Vdivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        width: 0.5, height: 36, color: Theme.of(context).dividerColor);
  }
}

// ─── Meeting Card ─────────────────────────────────────────────────────────────

class _StatusConfig {
  final String label;
  final Color color;
  final Color bg;
  final Color darkBg;
  final IconData icon;
  const _StatusConfig({
    required this.label,
    required this.color,
    required this.bg,
    required this.darkBg,
    required this.icon,
  });
}

_StatusConfig _statusConfig(String status) {
  switch (status) {
    case 'processing':
      return const _StatusConfig(
        label: 'Processing',
        color: Color(0xFFF59E0B),
        bg: Color(0xFFFEF3C7),
        darkBg: Color(0xFF3D2E0A),
        icon: Icons.hourglass_top_rounded,
      );
    case 'completed':
    case 'ready':
      return const _StatusConfig(
        label: 'Ready',
        color: Color(0xFF22C55E),
        bg: Color(0xFFDCFCE7),
        darkBg: Color(0xFF0D3320),
        icon: Icons.check_circle_rounded,
      );
    case 'error':
    case 'failed':
      return const _StatusConfig(
        label: 'Failed',
        color: Color(0xFFEF4444),
        bg: Color(0xFFFEE2E2),
        darkBg: Color(0xFF3D0D0D),
        icon: Icons.error_rounded,
      );
    default:
      return const _StatusConfig(
        label: 'Unknown',
        color: Color(0xFF94A3B8),
        bg: Color(0xFFF1F5F9),
        darkBg: Color(0xFF1E293B),
        icon: Icons.circle_outlined,
      );
  }
}

class _MeetingCard extends StatelessWidget {
  final Meeting meeting;
  final String Function(DateTime) formatDate;
  final String Function(int) formatDuration;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  const _MeetingCard({
    required this.meeting,
    required this.formatDate,
    required this.formatDuration,
    required this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cfg = _statusConfig(meeting.status);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isViewable =
        meeting.status == 'completed' || meeting.status == 'ready';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131827) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.07)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark ? cfg.darkBg : cfg.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: meeting.status == 'processing'
                      ? Padding(
                          padding: const EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: cfg.color),
                        )
                      : Icon(cfg.icon, color: cfg.color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meeting.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(formatDate(meeting.createdAt),
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF94A3B8))),
                          const Text(' · ',
                              style:
                                  TextStyle(color: Color(0xFF94A3B8))),
                          Text(formatDuration(meeting.durationSeconds),
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? cfg.darkBg : cfg.bg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        cfg.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cfg.color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (isViewable)
                          const Icon(Icons.chevron_right_rounded,
                              size: 18, color: Color(0xFF94A3B8)),
                        GestureDetector(
                          onTap: onDelete,
                          child: const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.delete_outline_rounded,
                                size: 18, color: Color(0xFFEF4444)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Record FAB ───────────────────────────────────────────────────────────────

class _RecordFAB extends StatefulWidget {
  final VoidCallback onPressed;
  const _RecordFAB({required this.onPressed});

  @override
  State<_RecordFAB> createState() => _RecordFABState();
}

class _RecordFABState extends State<_RecordFAB>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.06).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) =>
          Transform.scale(scale: _pulse.value, child: child),
      child: FloatingActionButton.extended(
        onPressed: widget.onPressed,
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.fiber_manual_record_rounded, size: 18),
        label: const Text('New Meeting',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 36, color: const Color(0xFF2563EB)),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              OutlinedButton(
                  onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}