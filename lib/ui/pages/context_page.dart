import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/models/chat_message.dart';
import '../../core/models/peer.dart';
import '../../core/services/permissions.dart';
import '../../main.dart' show messageStore, textClient;
import '../widgets/message_bubble.dart';

class ContextPage extends StatefulWidget {
  final Peer peer;

  const ContextPage({
    super.key,
    required this.peer,
  });

  @override
  State<ContextPage> createState() => _ContextPageState();
}

class _ContextPageState extends State<ContextPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _isDragging = false;
  bool _sending = false;
  late StreamSubscription<String> _sub;
  late List<ChatMessage> _messages;

  FaIconData? get _osIcon => switch (widget.peer.os) {
    'linux' => FontAwesomeIcons.linux,
    'windows' => FontAwesomeIcons.windows,
    'macos' => FontAwesomeIcons.apple,
    'android' => FontAwesomeIcons.android,
    'ios' => FontAwesomeIcons.apple,
    _ => null,
  };

  @override
  void initState() {
    super.initState();
    _messages = messageStore.messagesFor(widget.peer.id);
    _sub = messageStore.updates.listen((peerId) {
      if (peerId != widget.peer.id) return;
      if (!mounted) return;
      setState(() {
        _messages = messageStore.messagesFor(widget.peer.id);
      });
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickFiles() async {
    try {
      await AppPermissions.ensureStorage();
      final result = await FilePicker.pickFiles(allowMultiple: true);
      if (result == null) return;
      for (final file in result.files) {
        debugPrint('[PICK] Fichier: ${file.path}');
      }
    } on PermissionDeniedException catch (e) {
      _showError(e.message);
    }
  }

  Future<void> _handleDrop(List<dynamic> files) async {
    try {
      await AppPermissions.ensureStorage();
      for (final file in files) {
        debugPrint('[DROP] Fichier: ${file.path}');
      }
    } on PermissionDeniedException catch (e) {
      _showError(e.message);
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await textClient.send(widget.peer, text);
      _controller.clear();
      _focusNode.requestFocus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de l\'envoi : $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (_osIcon != null)
              FaIcon(
                _osIcon!,
                size: 18,
                color: theme.colorScheme.onPrimary,
              )
            else
              Icon(
                Icons.lan,
                size: 20,
                color: theme.colorScheme.onPrimary,
              ),
            const SizedBox(width: 10),
            Text(widget.peer.hostname),
          ],
        ),
      ),
      body: DropTarget(
        onDragEntered: (_) => setState(() => _isDragging = true),
        onDragExited: (_) => setState(() => _isDragging = false),
        onDragDone: (details) {
          setState(() => _isDragging = false);
          _handleDrop(details.files);
        },
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Text(
                            'Aucun message',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            return MessageBubble(
                              content: msg.content,
                              isMine: msg.isMine,
                              isFile: false,
                              peerName: widget.peer.hostname,
                            );
                          },
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
                        onPressed: _pickFiles,
                      ),
                      Expanded(
                        child: TextField(
                          focusNode: _focusNode,
                          controller: _controller,
                          enabled: !_sending,
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
                        icon: _sending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send, size: 20),
                        onPressed: _sending ? null : _sendMessage,
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
                                'vers ${widget.peer.hostname}',
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
