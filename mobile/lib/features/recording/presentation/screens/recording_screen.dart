// lib/features/recording/presentation/screens/recording_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/recording_provider.dart';

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
    final title = await _showTitleDialog();
    if (title == null) return;
    final meetingId =
        await ref.read(recordingProvider.notifier).stopAndUpload(title);
    if (meetingId != null && mounted) context.go('/home');
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
          decoration:
              const InputDecoration(hintText: 'e.g. Weekly Standup'),
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

    ref.listen(recordingProvider, (_, next) {
      if (next.status == RecordingStatus.uploaded && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Meeting uploaded — processing will begin shortly'),
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
                content:
                    Text('Stop the recording before leaving.')),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Recording',
              style: TextStyle(color: Colors.white)),
          automaticallyImplyLeading: false,
          elevation: 0,
        ),
        body: SafeArea(child: _buildBody(state)),
      ),
    );
  }

  Widget _buildBody(RecordingState state) {
    if (state.status == RecordingStatus.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mic_off,
                  size: 64, color: Color(0xFFEF4444)),
              const SizedBox(height: 16),
              Text(
                state.errorMessage ?? 'An error occurred',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54),
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
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    if (state.status == RecordingStatus.requestingPermission) {
      return const Center(
          child:
              CircularProgressIndicator(color: Color(0xFF2563EB)));
    }

    final session = state.session;
    final isPaused = state.status == RecordingStatus.paused;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),

          // Live waveform or flat line when paused
          SizedBox(
            height: 80,
            child: isPaused
                ? Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        24,
                        (_) => Container(
                          width: 3,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  )
                : const _LiveWaveform(),
          ),

          const SizedBox(height: 28),

          // Status pill
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isPaused
                  ? const Color(0xFFF59E0B).withOpacity(0.12)
                  : const Color(0xFFEF4444).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isPaused
                    ? const Color(0xFFF59E0B).withOpacity(0.35)
                    : const Color(0xFFEF4444).withOpacity(0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isPaused) ...[
                  _PulsingDot(color: const Color(0xFFEF4444)),
                  const SizedBox(width: 8),
                ] else ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: Color(0xFFF59E0B),
                        shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  isPaused ? 'PAUSED' : 'RECORDING',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: isPaused
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Timer
          Text(
            session?.formattedDuration ?? '00:00',
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w200,
              color: Colors.white,
              letterSpacing: 4,
            ),
          ),

          const Spacer(flex: 2),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CircleControl(
                icon: isPaused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
                size: 64,
                color: Colors.white.withOpacity(0.1),
                iconColor: Colors.white,
                onTap: isPaused
                    ? () => ref
                        .read(recordingProvider.notifier)
                        .resumeRecording()
                    : () => ref
                        .read(recordingProvider.notifier)
                        .pauseRecording(),
              ),
              const SizedBox(width: 28),
              _CircleControl(
                icon: Icons.stop_rounded,
                size: 80,
                color: const Color(0xFFEF4444),
                iconColor: Colors.white,
                onTap: _stopAndUpload,
                glow: true,
              ),
            ],
          ),

          const SizedBox(height: 36),
          Text(
            'Recording continues when screen locks',
            style: TextStyle(
                fontSize: 12, color: Colors.white.withOpacity(0.25)),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Live Waveform ────────────────────────────────────────────────────────────

class _LiveWaveform extends StatefulWidget {
  const _LiveWaveform();

  @override
  State<_LiveWaveform> createState() => _LiveWaveformState();
}

class _LiveWaveformState extends State<_LiveWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _WaveformPainter(progress: _ctrl.value),
        size: const Size(double.infinity, 80),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double progress;
  _WaveformPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;

    const barCount = 36;
    final barWidth = size.width / (barCount * 2);

    for (int i = 0; i < barCount; i++) {
      final x = i * barWidth * 2 + barWidth;
      final phase = (i / barCount) + progress;
      final h = (math.sin(phase * math.pi * 2) * 0.4 + 0.6) *
          (math.sin(i * 0.4 + progress * 3) * 0.3 + 0.7) *
          size.height *
          0.85;
      final opacity = 0.3 + (h / (size.height * 0.85)) * 0.7;
      paint.color = const Color(0xFF2563EB).withOpacity(opacity);
      canvas.drawLine(
        Offset(x, size.height / 2 - h / 2),
        Offset(x, size.height / 2 + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => old.progress != progress;
}

// ─── Circle Control ───────────────────────────────────────────────────────────

class _CircleControl extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;
  final bool glow;

  const _CircleControl({
    required this.icon,
    required this.size,
    required this.color,
    required this.iconColor,
    required this.onTap,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: glow
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: Icon(icon, color: iconColor, size: size * 0.45),
      ),
    );
  }
}

// ─── Pulsing Dot ──────────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
            color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}