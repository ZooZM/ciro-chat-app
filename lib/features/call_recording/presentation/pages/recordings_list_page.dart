import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/recording.dart';
import '../bloc/call_recording_cubit.dart';

class RecordingsListPage extends StatefulWidget {
  const RecordingsListPage({super.key});

  @override
  State<RecordingsListPage> createState() => _RecordingsListPageState();
}

class _RecordingsListPageState extends State<RecordingsListPage> {
  List<Recording> _recordings = [];
  bool _loading = true;
  String? _playingId;
  final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _loadRecordings();
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) setState(() => _playingId = null);
      }
    });
  }

  Future<void> _loadRecordings() async {
    final list = await getIt<CallRecordingCubit>().listRecordings();
    if (mounted) setState(() { _recordings = list; _loading = false; });
  }

  Future<void> _togglePlay(Recording rec) async {
    if (_playingId == rec.id) {
      await _player.stop();
      setState(() => _playingId = null);
      return;
    }
    setState(() => _playingId = rec.id);
    try {
      await _player.stop();
      await _player.setFilePath(rec.filePath);
      await _player.play();
    } catch (e) {
      if (mounted) {
        setState(() => _playingId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot play: $e')),
        );
      }
    }
  }

  Future<void> _delete(Recording rec) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete recording?'),
        content: Text(rec.displayName),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    await getIt<CallRecordingCubit>().deleteRecording(rec.id);
    if (_playingId == rec.id) await _player.stop();
    await _loadRecordings();
  }

  Future<void> _rename(Recording rec) async {
    final controller = TextEditingController(text: rec.displayName);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    await getIt<CallRecordingCubit>().renameRecording(rec.id, newName);
    await _loadRecordings();
  }

  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')} '
        '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CallRecordingCubit, CallRecordingState>(
      listener: (context, state) {
        if (state is RecordingSaved) _loadRecordings();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Recordings')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _recordings.isEmpty
                ? const Center(child: Text('No recordings yet'))
                : ListView.separated(
                    itemCount: _recordings.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final rec = _recordings[i];
                      final isPlaying = _playingId == rec.id;
                      return ListTile(
                        leading: IconButton(
                          icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
                          onPressed: () => _togglePlay(rec),
                        ),
                        title: Text(rec.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${_formatDuration(rec.durationMs)}  ·  ${_formatSize(rec.sizeBytes)}  ·  ${_formatDate(rec.createdAt)}',
                        ),
                        onTap: () => _togglePlay(rec),
                        onLongPress: () => _showActions(rec),
                      );
                    },
                  ),
      ),
    );
  }

  void _showActions(Recording rec) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () { Navigator.pop(context); _rename(rec); },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () { Navigator.pop(context); _delete(rec); },
            ),
          ],
        ),
      ),
    );
  }
}
