import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/recording_provider.dart';
import '../widgets/recording_timer.dart';

class RecordingScreen extends ConsumerStatefulWidget {
  const RecordingScreen({super.key});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  final _titleCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Auto-start recording when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recordingProvider.notifier).startRecording();
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _stopAndUpload() async {
    // Show title dialog before stopping
    final title = await _showTitleDialog();
    if (title == null) return; // User cancelled

    final meetingId = await ref
        .read(recordingProvider.notifier)
        .stopAndUpload(title);

    if (meetingId != null && mounted) {
      context.go('/home');
    }
  }

  Future<String?> _showTitleDialog() async {
    _titleCtrl.text = '';
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Name this meeting'),
        content: TextField(
          controller: _titleCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Weekly Standup',
          ),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) => Navigator.pop(ctx, _titleCtrl.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, _titleCtrl.text),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordingProvider);

    // Navigate away after upload
    ref.listen(recordingProvider, (_, next) {
      if (next.status == RecordingStatus.uploaded && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meeting uploaded! Processing will begin shortly.'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
        context.go('/home');
      }
    });

    return PopScope(
      canPop: !state.isActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Stop the recording before leaving.'),
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Recording'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: _buildBody(state),
        ),
      ),
    );
  }

  Widget _buildBody(RecordingState state) {
    // Permission error or general error
    if (state.status == RecordingStatus.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mic_off, size: 64, color: Color(0xFFEF4444)),
              const SizedBox(height: 16),
              Text(
                state.errorMessage ?? 'An error occurred',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400]),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  ref.read(recordingProvider.notifier).reset();
                  context.pop();
                },
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    // Uploading
    if (state.status == RecordingStatus.uploading ||
        state.status == RecordingStatus.stopping) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF2563EB)),
            const SizedBox(height: 24),
            Text(
              state.status == RecordingStatus.stopping
                  ? 'Finalizing recording...'
                  : 'Uploading meeting...',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    // Requesting permission
    if (state.status == RecordingStatus.requestingPermission) {
      return const Center(child: CircularProgressIndicator());
    }

    // Active recording / paused
    final session = state.session;
    final isPaused = state.status == RecordingStatus.paused;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Spacer(),

          // Timer display
          RecordingTimer(
            duration: session?.formattedDuration ?? '00:00',
            isPaused: isPaused,
          ),

          const Spacer(),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pause / Resume
              _ControlButton(
                icon: isPaused ? Icons.play_arrow : Icons.pause,
                label: isPaused ? 'Resume' : 'Pause',
                color: const Color(0xFF2D2D3F),
                size: 64,
                onTap: isPaused
                    ? () => ref.read(recordingProvider.notifier).resumeRecording()
                    : () => ref.read(recordingProvider.notifier).pauseRecording(),
              ),

              const SizedBox(width: 32),

              // Stop
              _ControlButton(
                icon: Icons.stop,
                label: 'Stop',
                color: const Color(0xFFEF4444),
                size: 80,
                onTap: _stopAndUpload,
              ),
            ],
          ),

          const SizedBox(height: 48),

          Text(
            'Recording will continue if you lock your screen.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double size;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.45),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
      ],
    );
  }
}
