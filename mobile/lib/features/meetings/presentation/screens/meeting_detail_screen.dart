// lib/features/meetings/presentation/screens/meeting_detail_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/repositories/meeting_repository.dart';
import '../providers/meeting_provider.dart';
import '../providers/transcript_provider.dart';
import '../providers/intelligence_provider.dart';
import '../../data/services/export_service.dart';

final meetingDetailProvider =
    FutureProvider.family<Meeting, String>((ref, id) async {
  final repository = ref.read(meetingRepositoryProvider);
  return repository.getMeeting(id);
});

class MeetingDetailScreen extends ConsumerStatefulWidget {
  final String meetingId;
  const MeetingDetailScreen({super.key, required this.meetingId});

  @override
  ConsumerState<MeetingDetailScreen> createState() =>
      _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends ConsumerState<MeetingDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAll());
    _startPolling();
  }

  void _refreshAll() {
    ref.invalidate(meetingDetailProvider(widget.meetingId));
    ref.invalidate(transcriptProvider(widget.meetingId));
    ref.invalidate(intelligenceProvider(widget.meetingId));
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final meeting = ref.read(meetingDetailProvider(widget.meetingId));
      meeting.whenData((m) {
        if (m.isCompleted || m.isFailed) {
          _pollTimer?.cancel();
          _refreshAll();
        } else {
          ref.invalidate(meetingDetailProvider(widget.meetingId));
        }
      });
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  String _secondsToTime(double sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toStringAsFixed(0).padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete meeting?'),
        content: const Text(
          'This permanently deletes the recording, transcript, and all analysis.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final success = await ref
          .read(meetingsProvider.notifier)
          .deleteMeeting(widget.meetingId);
      if (success && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Meeting deleted')));
        context.go('/home');
      }
    }
  }

  Future<void> _editTitle(BuildContext context, String currentTitle) async {
    final ctrl = TextEditingController(text: currentTitle);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit title'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Meeting title'),
          onSubmitted: (_) => Navigator.pop(ctx, ctrl.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newTitle != null && newTitle.isNotEmpty && mounted) {
      await ref
          .read(meetingsProvider.notifier)
          .updateTitle(widget.meetingId, newTitle);
      ref.invalidate(meetingDetailProvider(widget.meetingId));
    }
  }

  void _exportCurrentTab(Meeting meeting) {
    final index = _tabController.index;
    final meetingId = widget.meetingId;
    if (index == 0) {
      final transcriptAsync = ref.read(transcriptProvider(meetingId));
      transcriptAsync.whenData((transcript) {
        final text = transcript.segments.map((seg) {
          final speaker = seg.speaker != null ? '${seg.speaker}: ' : '';
          return '[${_secondsToTime(seg.startTime)}] $speaker${seg.text}';
        }).join('\n');
        ExportService.shareTranscript(text, title: meeting.title);
      });
    } else if (index == 1) {
      final intelAsync = ref.read(intelligenceProvider(meetingId));
      intelAsync.whenData((intel) {
        final text =
            'Meeting Minutes\n\n${intel.summary ?? ''}\n\nKey Insights:\n'
            '${intel.keyInsights.map((i) => '• $i').join('\n')}';
        ExportService.shareSummary(text, title: meeting.title);
      });
    } else {
      final intelAsync = ref.read(intelligenceProvider(meetingId));
      intelAsync.whenData((intel) {
        ExportService.shareActionPoints(intel.actionPoints,
            title: meeting.title);
      });
    }
  }

  void _handleExport(String type, Meeting meeting) {
    final meetingId = widget.meetingId;
    final transcriptAsync = ref.read(transcriptProvider(meetingId));
    final intelAsync = ref.read(intelligenceProvider(meetingId));

    String fullText = 'MEETING: ${meeting.title}\n';
    fullText +=
        'Date: ${meeting.createdAt}\nDuration: ${meeting.formattedDuration}\n\n';

    transcriptAsync.whenData((transcript) {
      fullText += '─── TRANSCRIPT ───\n\n';
      fullText += transcript.segments.map((seg) {
        final speaker = seg.speaker != null ? '${seg.speaker}: ' : '';
        return '[${_secondsToTime(seg.startTime)}] $speaker${seg.text}';
      }).join('\n');

      intelAsync.whenData((intel) {
        fullText +=
            '\n\n─── MEETING MINUTES ───\n\n${intel.summary ?? ''}';
        fullText += '\n\n─── KEY INSIGHTS ───\n\n';
        fullText += intel.keyInsights.map((i) => '• $i').join('\n');
        fullText += '\n\n─── ACTION POINTS ───\n\n';
        fullText += intel.actionPoints.map((a) => '☐ $a').join('\n');
        switch (type) {
          case 'pdf':
            ExportService.exportAsPdf(fullText, title: meeting.title);
          case 'txt':
            ExportService.exportAsTxt(fullText, title: meeting.title);
          case 'email':
            ExportService.shareViaEmail(fullText, title: meeting.title);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final meetingAsync =
        ref.watch(meetingDetailProvider(widget.meetingId));

    return meetingAsync.when(
      data: (meeting) => Scaffold(
        appBar: AppBar(
          title: GestureDetector(
            onTap: () => _editTitle(context, meeting.title),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(meeting.title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17)),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.edit_outlined,
                    size: 15, color: Color(0xFF94A3B8)),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: _refreshAll,
            ),
            if (meeting.isCompleted)
              IconButton(
                icon: const Icon(Icons.ios_share_rounded, size: 20),
                onPressed: () => _exportCurrentTab(meeting),
              ),
            if (meeting.isCompleted)
              PopupMenuButton<String>(
                icon: const Icon(Icons.download_rounded, size: 20),
                onSelected: (v) => _handleExport(v, meeting),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'pdf',
                    child: Row(children: [
                      Icon(Icons.picture_as_pdf_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Export as PDF'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'txt',
                    child: Row(children: [
                      Icon(Icons.text_snippet_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Export as TXT'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'email',
                    child: Row(children: [
                      Icon(Icons.email_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Send via Email'),
                    ]),
                  ),
                ],
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 20, color: Color(0xFFEF4444)),
              onPressed: () => _confirmDelete(context),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: _StyledTabBar(controller: _tabController),
          ),
        ),
        body: Column(
          children: [
            if (meeting.isProcessing)
              _StatusBanner(
                color: const Color(0xFF2563EB),
                icon: Icons.hourglass_top_rounded,
                message:
                    'Processing your meeting — results will appear shortly',
                showSpinner: true,
              ),
            if (meeting.isFailed)
              _StatusBanner(
                color: const Color(0xFFEF4444),
                icon: Icons.error_outline_rounded,
                message: 'Processing failed. Please try uploading again.',
              ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _TranscriptTab(meetingId: widget.meetingId),
                  _SummaryTab(meetingId: widget.meetingId),
                  _ActionsTab(meetingId: widget.meetingId),
                ],
              ),
            ),
          ],
        ),
      ),
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (err, _) =>
          Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }
}

// ─── Styled Tab Bar ───────────────────────────────────────────────────────────

class _StyledTabBar extends StatelessWidget {
  final TabController controller;
  const _StyledTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 44,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.06)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: isDark ? Colors.white : const Color(0xFF0F172A),
        unselectedLabelColor: const Color(0xFF94A3B8),
        labelStyle: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w400),
        tabs: const [
          Tab(text: 'Transcript'),
          Tab(text: 'Summary'),
          Tab(text: 'Actions'),
        ],
      ),
    );
  }
}

// ─── Status Banner ────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String message;
  final bool showSpinner;

  const _StatusBanner({
    required this.color,
    required this.icon,
    required this.message,
    this.showSpinner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: color.withOpacity(0.08),
      child: Row(
        children: [
          if (showSpinner)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: color),
            )
          else
            Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(fontSize: 13, color: color)),
          ),
        ],
      ),
    );
  }
}

// ─── Transcript Tab ───────────────────────────────────────────────────────────

class _TranscriptTab extends ConsumerWidget {
  final String meetingId;
  const _TranscriptTab({required this.meetingId});

  String _formatTime(double seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toStringAsFixed(0).padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transcriptAsync = ref.watch(transcriptProvider(meetingId));
    return transcriptAsync.when(
      data: (transcript) {
        if (transcript.segments.isEmpty) {
          return const _TabEmpty(
              icon: Icons.transcribe_outlined,
              message: 'No transcript available yet.');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: transcript.segments.length,
          itemBuilder: (_, i) {
            final seg = transcript.segments[i];
            final colorIndex =
                (seg.speaker ?? 'Speaker 0').hashCode.abs() %
                    Colors.primaries.length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      _formatTime(seg.startTime),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (seg.speaker != null) ...[
                          Text(
                            seg.speaker!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.primaries[colorIndex],
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(seg.text,
                            style: const TextStyle(
                                fontSize: 14, height: 1.5)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (_, __) => const _TabEmpty(
        icon: Icons.transcribe_outlined,
        message:
            'Transcript not available yet.\nCheck back after processing completes.',
      ),
    );
  }
}

// ─── Summary Tab ──────────────────────────────────────────────────────────────

class _SummaryTab extends ConsumerWidget {
  final String meetingId;
  const _SummaryTab({required this.meetingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intelAsync = ref.watch(intelligenceProvider(meetingId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return intelAsync.when(
      data: (intel) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel(label: 'MEETING MINUTES'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.04)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                intel.summary ?? 'No summary generated yet.',
                style:
                    const TextStyle(fontSize: 14, height: 1.6),
              ),
            ),
            const SizedBox(height: 28),
            const _SectionLabel(label: 'KEY INSIGHTS'),
            const SizedBox(height: 12),
            if (intel.keyInsights.isEmpty)
              const Text('No insights extracted yet.',
                  style: TextStyle(color: Color(0xFF94A3B8)))
            else
              ...intel.keyInsights.map(
                (insight) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(
                            top: 1, right: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B)
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                            Icons.lightbulb_outline_rounded,
                            size: 14,
                            color: Color(0xFFF59E0B)),
                      ),
                      Expanded(
                        child: Text(insight,
                            style: const TextStyle(
                                fontSize: 14, height: 1.5)),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (_, __) => const _TabEmpty(
        icon: Icons.summarize_outlined,
        message:
            'Summary not available yet.\nCheck back after processing completes.',
      ),
    );
  }
}

// ─── Actions Tab ──────────────────────────────────────────────────────────────

class _ActionsTab extends ConsumerWidget {
  final String meetingId;
  const _ActionsTab({required this.meetingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intelAsync = ref.watch(intelligenceProvider(meetingId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return intelAsync.when(
      data: (intel) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel(label: 'ACTION POINTS'),
            const SizedBox(height: 12),
            if (intel.actionPoints.isEmpty)
              const Text('No action points extracted yet.',
                  style: TextStyle(color: Color(0xFF94A3B8)))
            else
              ...intel.actionPoints.map(
                (action) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.04)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF2563EB)
                                .withOpacity(0.4),
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      Expanded(
                        child: Text(action,
                            style: const TextStyle(
                                fontSize: 14, height: 1.4)),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (_, __) => const _TabEmpty(
        icon: Icons.task_outlined,
        message:
            'Actions not available yet.\nCheck back after processing completes.',
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _TabEmpty extends StatelessWidget {
  final IconData icon;
  final String message;
  const _TabEmpty({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: const Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF94A3B8), fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        color: Color(0xFF94A3B8),
      ),
    );
  }
}