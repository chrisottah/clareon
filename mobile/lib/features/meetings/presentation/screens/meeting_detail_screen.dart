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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
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
        title: const Text('Delete Meeting'),
        content: const Text(
            'This will permanently delete the recording, transcript, and all analysis. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444)),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meeting deleted')),
        );
        context.go('/home');
      }
    }
  }

  Future<void> _editTitle(BuildContext context, String currentTitle) async {
    final ctrl = TextEditingController(text: currentTitle);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Title'),
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
    } else if (index == 2) {
      final intelAsync = ref.read(intelligenceProvider(meetingId));
      intelAsync.whenData((intel) {
        ExportService.shareActionPoints(
          intel.actionPoints,
          title: meeting.title,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final meetingAsync = ref.watch(meetingDetailProvider(widget.meetingId));

    return meetingAsync.when(
      data: (meeting) => Scaffold(
        appBar: AppBar(
          title: GestureDetector(
            onTap: () => _editTitle(context, meeting.title),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    meeting.title,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.edit, size: 16, color: Colors.grey),
              ],
            ),
          ),
          actions: [
            // Export button — only when completed
            if (meeting.isCompleted)
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Share',
                onPressed: () => _exportCurrentTab(meeting),
              ),
            // Export as PDF/TXT
            if (meeting.isCompleted)
              PopupMenuButton<String>(
                icon: const Icon(Icons.download),
                tooltip: 'Export',
                onSelected: (value) => _handleExport(value, meeting),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'pdf',
                    child: Row(children: [
                      Icon(Icons.picture_as_pdf),
                      SizedBox(width: 8),
                      Text('Export as PDF'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'txt',
                    child: Row(children: [
                      Icon(Icons.text_snippet),
                      SizedBox(width: 8),
                      Text('Export as TXT'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'email',
                    child: Row(children: [
                      Icon(Icons.email),
                      SizedBox(width: 8),
                      Text('Send via Email'),
                    ]),
                  ),
                ],
              ),
            // Delete button
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(context),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.transcribe), text: 'Transcript'),
              Tab(icon: Icon(Icons.summarize), text: 'Summary'),
              Tab(icon: Icon(Icons.task), text: 'Actions'),
            ],
          ),
        ),

        // Processing banner
        body: Column(
          children: [
            if (meeting.isProcessing)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                color: const Color(0xFF2563EB).withOpacity(0.1),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Processing your meeting... '
                        'Results will appear here shortly.'),
                  ],
                ),
              ),
            if (meeting.isFailed)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                color: const Color(0xFFEF4444).withOpacity(0.1),
                child: const Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: Color(0xFFEF4444), size: 18),
                    SizedBox(width: 12),
                    Text('Processing failed. Please try again.',
                        style: TextStyle(color: Color(0xFFEF4444))),
                  ],
                ),
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
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        body: Center(child: Text('Error: $err')),
      ),
    );
  }

  void _handleExport(String type, Meeting meeting) {
    final meetingId = widget.meetingId;
    final transcriptAsync = ref.read(transcriptProvider(meetingId));
    final intelAsync = ref.read(intelligenceProvider(meetingId));

    String fullText = 'MEETING: ${meeting.title}\n';
    fullText += 'Date: ${meeting.createdAt}\n';
    fullText += 'Duration: ${meeting.formattedDuration}\n\n';

    transcriptAsync.whenData((transcript) {
      fullText += '─── TRANSCRIPT ───\n\n';
      fullText += transcript.segments.map((seg) {
        final speaker = seg.speaker != null ? '${seg.speaker}: ' : '';
        return '[${_secondsToTime(seg.startTime)}] $speaker${seg.text}';
      }).join('\n');

      intelAsync.whenData((intel) {
        fullText += '\n\n─── MEETING MINUTES ───\n\n${intel.summary ?? ''}';
        fullText += '\n\n─── KEY INSIGHTS ───\n\n';
        fullText += intel.keyInsights.map((i) => '• $i').join('\n');
        fullText += '\n\n─── ACTION POINTS ───\n\n';
        fullText += intel.actionPoints.map((a) => '☐ $a').join('\n');

        switch (type) {
          case 'pdf':
            ExportService.exportAsPdf(fullText, title: meeting.title);
            break;
          case 'txt':
            ExportService.exportAsTxt(fullText, title: meeting.title);
            break;
          case 'email':
            ExportService.shareViaEmail(fullText, title: meeting.title);
            break;
        }
      });
    });
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
          return const Center(child: Text('No transcript available yet.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: transcript.segments.length,
          itemBuilder: (_, i) {
            final seg = transcript.segments[i];
            final colorIndex =
                (seg.speaker ?? 'Speaker 0').hashCode.abs() %
                    Colors.primaries.length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      _formatTime(seg.startTime),
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (seg.speaker != null)
                          Text(
                            seg.speaker!,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.primaries[colorIndex],
                            ),
                          ),
                        Text(seg.text),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text(
          'Transcript not available yet.\nCheck back after processing completes.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[500]),
        ),
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
    return intelAsync.when(
      data: (intel) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Meeting Minutes',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(intel.summary ?? 'No summary generated yet.'),
            const SizedBox(height: 24),
            Text('Key Insights',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (intel.keyInsights.isEmpty)
              Text('No insights extracted.',
                  style: TextStyle(color: Colors.grey[500]))
            else
              ...intel.keyInsights.map(
                (insight) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          size: 20, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(insight)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text(
          'Summary not available yet.\nCheck back after processing completes.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[500]),
        ),
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
    return intelAsync.when(
      data: (intel) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Action Points',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          if (intel.actionPoints.isEmpty)
            Text('No action points extracted.',
                style: TextStyle(color: Colors.grey[500]))
          else
            ...intel.actionPoints.map(
              (action) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: CheckboxListTile(
                  value: false,
                  onChanged: (_) {},
                  title: Text(action),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text(
          'Actions not available yet.\nCheck back after processing completes.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[500]),
        ),
      ),
    );
  }
}