import 'package:cached_network_image/cached_network_image.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/message.dart';
import 'package:ciro_chat_app/features/chat/presentation/bloc/chat_cubit.dart';
import 'package:ciro_chat_app/features/chat/presentation/widgets/media_gallery_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

const _kBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://firstly-perforative-jaylah.ngrok-free.dev',
);

String _resolveUrl(String? relative) {
  if (relative == null || relative.isEmpty) return '';
  if (relative.startsWith('http')) return relative;
  final base = _kBaseUrl.endsWith('/') ? _kBaseUrl : '$_kBaseUrl/';
  final path = relative.startsWith('/') ? relative.substring(1) : relative;
  return '$base$path';
}

/// FR-024: Tabbed screen showing Media, Links, Docs shared in a chat room.
/// Opens from ChatInfoScreen → "Media, links and documents" row.
class SharedMediaScreen extends StatefulWidget {
  final String roomId;

  const SharedMediaScreen({super.key, required this.roomId});

  @override
  State<SharedMediaScreen> createState() => _SharedMediaScreenState();
}

class _SharedMediaScreenState extends State<SharedMediaScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<Message> _mediaMessages = [];
  List<Message> _linkMessages = [];
  List<Message> _docMessages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final cubit = context.read<ChatCubit>();
    final results = await Future.wait([
      cubit.getSharedMedia(widget.roomId),
      cubit.getSharedLinks(widget.roomId),
      cubit.getSharedDocs(widget.roomId),
    ]);
    if (mounted) {
      setState(() {
        _mediaMessages = results[0];
        _linkMessages = results[1];
        _docMessages = results[2];
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Media, Links & Docs',
          style: AppTypography.subtitle1.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(
              child: Text(
                'Media (${_mediaMessages.length})',
                style: AppTypography.caption,
              ),
            ),
            Tab(
              child: Text(
                'Links (${_linkMessages.length})',
                style: AppTypography.caption,
              ),
            ),
            Tab(
              child: Text(
                'Docs (${_docMessages.length})',
                style: AppTypography.caption,
              ),
            ),
          ],
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _MediaGrid(messages: _mediaMessages),
                _LinkList(messages: _linkMessages),
                _DocList(messages: _docMessages),
              ],
            ),
    );
  }
}

// ── Media Grid (4-column) ────────────────────────────────────────────────────

class _MediaGrid extends StatelessWidget {
  final List<Message> messages;
  const _MediaGrid({required this.messages});

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        child: Text(
          'No media shared yet',
          style: AppTypography.body1.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(4.resW),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 2.resW,
        crossAxisSpacing: 2.resW,
      ),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        final url = _resolveUrl(msg.fileUrl);
        final isVideo = msg.type == MessageType.video;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MediaGalleryViewer(
                  mediaMessages: messages,
                  initialIndex: index,
                ),
              ),
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: Colors.grey[200]),
                errorWidget: (_, __, ___) =>
                    Container(color: Colors.grey[300], child: const Icon(Icons.broken_image)),
              ),
              if (isVideo)
                const Center(
                  child: Icon(Icons.play_circle_fill, color: Colors.white, size: 28),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Links List ───────────────────────────────────────────────────────────────

class _LinkList extends StatelessWidget {
  final List<Message> messages;
  const _LinkList({required this.messages});

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        child: Text(
          'No links shared yet',
          style: AppTypography.body1.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: 8.resH),
      itemCount: messages.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.divider),
      itemBuilder: (context, index) {
        final msg = messages[index];
        // Extract first URL from text
        final urlRegex = RegExp(r'https?://\S+');
        final match = urlRegex.firstMatch(msg.text);
        final url = match?.group(0) ?? msg.text;

        return ListTile(
          leading: Container(
            width: 40.resW,
            height: 40.resW,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.resR),
            ),
            child: Icon(Icons.link, color: AppColors.primary, size: 20.resW),
          ),
          title: Text(
            url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body2.copyWith(color: AppColors.primary),
          ),
          subtitle: Text(
            DateFormat('MMM d, yyyy').format(msg.timestamp),
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
        );
      },
    );
  }
}

// ── Docs List ────────────────────────────────────────────────────────────────

class _DocList extends StatelessWidget {
  final List<Message> messages;
  const _DocList({required this.messages});

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        child: Text(
          'No documents shared yet',
          style: AppTypography.body1.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: 8.resH),
      itemCount: messages.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.divider),
      itemBuilder: (context, index) {
        final msg = messages[index];
        final fileName = msg.metadata?['fileName'] as String? ?? 'Document';
        final fileSize = msg.metadata?['fileSize'];
        final sizeLbl = fileSize != null
            ? '${((fileSize as num) / 1024).toStringAsFixed(1)} KB'
            : '';

        return ListTile(
          leading: Container(
            width: 40.resW,
            height: 40.resW,
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.resR),
            ),
            child: Icon(Icons.insert_drive_file, color: AppColors.warning, size: 20.resW),
          ),
          title: Text(
            fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body2,
          ),
          subtitle: Text(
            '$sizeLbl  •  ${DateFormat('MMM d, yyyy').format(msg.timestamp)}',
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
        );
      },
    );
  }
}
