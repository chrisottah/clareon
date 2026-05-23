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
    // Load meetings and start polling for status updates
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
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'processing':
        return Icons.hourglass_top;
      case 'completed':
      case 'ready':
        return Icons.check_circle;
      case 'error':
      case 'failed':
        return Icons.error;
      default:
        return Icons.help;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'processing':
        return Colors.orange;
      case 'completed':
      case 'ready':
        return Colors.green;
      case 'error':
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _confirmDelete(String id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Meeting'),
        content: Text('Delete "$title"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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

    // Show SnackBar when a meeting just completed processing
    ref.listen<MeetingsState>(meetingsProvider, (prev, next) {
      if (next.completedMeetingId != null) {
        final meeting = next.meetings
            .where((m) => m.id == next.completedMeetingId)
            .firstOrNull;
        if (meeting != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Meeting "${meeting.title}" is ready!'),
              action: SnackBarAction(
                label: 'View',
                onPressed: () {
                  context.push('/meeting/${meeting.id}');
                  ref.read(meetingsProvider.notifier).clearCompletedNotification();
                },
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
        // Clear the notification flag so it doesn't fire again
        ref.read(meetingsProvider.notifier).clearCompletedNotification();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clareon'),
        actions: [
          // Theme toggle
          IconButton(
            icon: Icon(
              themeMode == ThemeMode.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
            tooltip: 'Toggle theme',
            onPressed: () {
              ref.read(themeModeProvider.notifier).state =
                  themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.go('/login'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(meetingsProvider.notifier).loadMeetings(),
        child: _buildBody(state),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/record'),
        icon: const Icon(Icons.fiber_manual_record),
        label: const Text('New Meeting'),
        backgroundColor: const Color(0xFF2563EB),
      ),
    );
  }

  Widget _buildBody(MeetingsState state) {
    // Loading
    if (state.status == MeetingsStatus.loading && state.meetings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error
    if (state.status == MeetingsStatus.error && state.meetings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                state.errorMessage ?? 'Failed to load meetings',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(meetingsProvider.notifier).loadMeetings(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Empty
    if (state.meetings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.mic, size: 48, color: Color(0xFF2563EB)),
            ),
            const SizedBox(height: 24),
            Text(
              'Your meetings will appear here',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to start recording',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    // List
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: state.meetings.length,
      itemBuilder: (context, index) {
        final meeting = state.meetings[index];
        // Allow tapping on completed or ready meetings
        final isViewable = meeting.status == 'completed' || meeting.status == 'ready';
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _statusColor(meeting.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _statusIcon(meeting.status),
                color: _statusColor(meeting.status),
                size: 22,
              ),
            ),
            title: Text(
              meeting.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              '${_formatDate(meeting.createdAt)} • ${_formatDuration(meeting.durationSeconds)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isViewable)
                  Icon(Icons.chevron_right, color: Theme.of(context).textTheme.bodySmall?.color),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _confirmDelete(meeting.id, meeting.title),
                ),
              ],
            ),
            onTap: () {
              if (isViewable) {
                context.push('/meeting/${meeting.id}');
              }
            },
          ),
        );
      },
    );
  }
}