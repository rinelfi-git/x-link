import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../widgets/file_transfer_bubble.dart';
import '../widgets/message_bubble.dart';

class ContextPage extends StatefulWidget {
  final String hostname;
  final String os;

  const ContextPage({
    super.key,
    required this.hostname,
    required this.os,
  });

  @override
  State<ContextPage> createState() => _ContextPageState();
}

class _ContextPageState extends State<ContextPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _isDragging = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    debugPrint('[TEXT] Envoi: "$text"');
    _controller.clear();
    _focusNode.requestFocus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(widget.hostname),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.os,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
      body: DropTarget(
        onDragEntered: (_) => setState(() => _isDragging = true),
        onDragExited: (_) => setState(() => _isDragging = false),
        onDragDone: (details) {
          setState(() => _isDragging = false);
          for (final file in details.files) {
            debugPrint('[DROP] Fichier: ${file.path}');
          }
        },
        child: Stack(
          children: [
            // Contenu principal
            Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    children: [
                      MessageBubble(
                        content:
                            'Salut, je t\'envoie les fichiers du projet',
                        isMine: true,
                        isFile: false,
                        peerName: widget.hostname,
                      ),
                      FileTransferBubble(
                        filename: 'maquette_v2.fig',
                        fileSize: '4.7 MB',
                        isMine: false,
                        peerName: widget.hostname,
                        status: FileTransferStatus.completed,
                        onAction: () {},
                      ),
                      MessageBubble(
                        content:
                            'Merci ! Je t\'envoie les specs en retour',
                        isMine: false,
                        isFile: false,
                        peerName: widget.hostname,
                      ),
                      FileTransferBubble(
                        filename: 'specs_technique.pdf',
                        fileSize: '0.5 MB / 2.1 MB (25%)',
                        isMine: true,
                        peerName: widget.hostname,
                        status: FileTransferStatus.transferring,
                        progress: 0.25,
                        onAction: () {},
                      ),
                      FileTransferBubble(
                        filename: 'video_demo.mp4',
                        fileSize: '158.3 MB',
                        isMine: true,
                        peerName: widget.hostname,
                        status: FileTransferStatus.failed,
                        onAction: () {},
                      ),
                      FileTransferBubble(
                        filename: 'archive_sources.zip',
                        fileSize: '47.2 MB',
                        isMine: true,
                        peerName: widget.hostname,
                        status: FileTransferStatus.pending,
                        onAction: () {},
                      ),
                      FileTransferBubble(
                        filename: 'rapport_final.docx',
                        fileSize: '1.3 MB',
                        isMine: true,
                        peerName: widget.hostname,
                        status: FileTransferStatus.completed,
                        onAction: () {},
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                        width: 0.5,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.attach_file,
                          color: theme.colorScheme.primary,
                        ),
                        onPressed: () async {
                          final result = await FilePicker.pickFiles(
                            allowMultiple: true,
                          );
                          if (result != null) {
                            for (final file in result.files) {
                              debugPrint('[PICK] Fichier: ${file.path}');
                            }
                          }
                        },
                      ),
                      Expanded(
                        child: TextField(
                          focusNode: _focusNode,
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: 'Message...',
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerLow,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton.filled(
                        icon: const Icon(Icons.send, size: 20),
                        onPressed: _sendMessage,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Overlay dropzone
            if (_isDragging)
              AnimatedOpacity(
                opacity: _isDragging ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  color: theme.colorScheme.primary.withValues(alpha: 0.9),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: theme.colorScheme.onPrimary
                                  .withValues(alpha: 0.5),
                              width: 3,
                              strokeAlign: BorderSide.strokeAlignInside,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_upload_outlined,
                                size: 64,
                                color: theme.colorScheme.onPrimary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Déposer ici',
                                style:
                                    theme.textTheme.titleLarge?.copyWith(
                                  color: theme.colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Fichiers ou dossiers',
                                style:
                                    theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onPrimary
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                              Text(
                                'vers ${widget.hostname}',
                                style:
                                    theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onPrimary
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
