import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/upload_service.dart';
import '../../core/theme/app_colors.dart';
import '../auth/data/auth_providers.dart';
import '../profile/data/profile_providers.dart';
import 'data/block_providers.dart';
import 'data/chat_providers.dart';
import 'data/report_service.dart';
import 'widgets/report_sheet.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.otherUid});
  final String otherUid;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  bool _sendingImage = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// True when I've blocked the other person — no sending in either form.
  bool get _blocked => ref.read(isBlockedProvider(widget.otherUid));

  /// Long-press on a message they sent → report it.
  void _reportMessage(ChatMessage message) {
    final me = ref.read(authStateProvider).value?.uid;
    if (me == null || message.id.isEmpty) return;
    final chatId = ref.read(chatRepoProvider).chatIdFor(me, widget.otherUid);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.flag_outlined, color: AppColors.danger),
          title: const Text('Report message',
              style: TextStyle(color: AppColors.danger)),
          onTap: () {
            Navigator.pop(sheetCtx);
            showReportSheet(
              context,
              targetType: ReportTarget.message,
              targetId: '$chatId/${message.id}',
              targetUid: message.senderId,
            );
          },
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final me = ref.read(authStateProvider).value?.uid;
    if (me == null || _blocked) return;
    _controller.clear();
    await ref
        .read(chatRepoProvider)
        .sendMessage(me, widget.otherUid, text: text);
  }

  /// Share an outfit photo from the gallery (spec: Module 3, Chat System).
  Future<void> _sendImage() async {
    final me = ref.read(authStateProvider).value?.uid;
    if (me == null || _blocked) return;

    final upload = ref.read(uploadServiceProvider);
    final file = await upload.pickFromGallery();
    if (file == null) return;

    setState(() => _sendingImage = true);
    try {
      final url = await upload.uploadImage(file);
      await ref
          .read(chatRepoProvider)
          .sendMessage(me, widget.otherUid, imageUrl: url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not send photo: $e')));
      }
    } finally {
      if (mounted) setState(() => _sendingImage = false);
    }
  }

  Future<void> _accept() async {
    final me = ref.read(authStateProvider).value?.uid;
    if (me == null || _blocked) return;
    await ref.read(chatRepoProvider).acceptRequest(me, widget.otherUid);
  }

  Future<void> _decline() async {
    final me = ref.read(authStateProvider).value?.uid;
    if (me == null) return;
    await ref.read(chatRepoProvider).declineRequest(me, widget.otherUid);
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _sendRequest() async {
    final me = ref.read(authStateProvider).value?.uid;
    if (me == null || _blocked) return;
    await ref.read(chatRepoProvider).sendRequest(me, widget.otherUid);
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authStateProvider).value?.uid;
    final other = ref.watch(userByUidProvider(widget.otherUid)).value;
    final thread = ref.watch(chatThreadProvider(widget.otherUid)).value;
    final accepted = thread?.status == ChatStatus.accepted;
    final blocked = ref.watch(isBlockedProvider(widget.otherUid));

    // Only subscribe once the thread is accepted — reading messages of a
    // thread that doesn't exist yet is denied by the rules.
    final messagesAsync =
        accepted ? ref.watch(chatMessagesProvider(widget.otherUid)) : null;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.surface,
              backgroundImage:
                  (other?.photoURL != null && other!.photoURL!.isNotEmpty)
                      ? NetworkImage(other.photoURL!)
                      : null,
              child: (other?.photoURL == null || other!.photoURL!.isEmpty)
                  ? Text(other?.initial ?? '?',
                      style: const TextStyle(
                          color: AppColors.ink, fontSize: 13))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                other?.name ?? 'Chat',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync != null
                ? messagesAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('$e', textAlign: TextAlign.center),
                      ),
                    ),
                    data: (messages) {
                      if (messages.isEmpty) {
                        return const Center(
                          child: Text('Say hi 👋',
                              style: TextStyle(color: AppColors.inkMuted)),
                        );
                      }
                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, i) => _Bubble(
                          message: messages[i],
                          mine: messages[i].senderId == me,
                          onLongPress: messages[i].senderId == me
                              ? null
                              : () => _reportMessage(messages[i]),
                        ),
                      );
                    },
                  )
                : blocked
                    ? const SizedBox.shrink()
                    : _RequestGate(
                    thread: thread,
                    me: me,
                    otherName: other?.name ?? 'this user',
                    onSendRequest: _sendRequest,
                    onAccept: _accept,
                    onDecline: _decline,
                  ),
          ),
          if (blocked)
            _BlockedBar(otherUid: widget.otherUid)
          else if (accepted)
            _Composer(
              controller: _controller,
              busy: _sendingImage,
              onSend: _send,
              onAttach: _sendImage,
            ),
        ],
      ),
    );
  }
}

/// Shown until the conversation is accepted: either "send a request" or
/// "accept / decline this request".
class _RequestGate extends StatelessWidget {
  const _RequestGate({
    required this.thread,
    required this.me,
    required this.otherName,
    required this.onSendRequest,
    required this.onAccept,
    required this.onDecline,
  });

  final ChatThread? thread;
  final String? me;
  final String otherName;
  final VoidCallback onSendRequest;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final waitingOnMe = me != null && (thread?.awaitingMyDecision(me!) ?? false);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.forum_outlined,
                  size: 36, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 22),
            if (thread == null) ...[
              const Text(
                'Send a chat request',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You can start messaging $otherName once they accept.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 26),
              ElevatedButton(
                onPressed: onSendRequest,
                child: const Text('Send Chat Request'),
              ),
            ] else if (waitingOnMe) ...[
              Text(
                '$otherName wants to chat',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Accept to start the conversation.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDecline,
                      child: const Center(child: Text('Decline')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onAccept,
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Text(
                'Request sent',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Waiting for $otherName to accept.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.inkMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine, this.onLongPress});
  final ChatMessage message;
  final bool mine;

  /// Set for received messages: opens the report option.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.72;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(mine ? 18 : 4),
      bottomRight: Radius.circular(mine ? 4 : 18),
    );

    if (message.isImage) {
      return Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ClipRRect(
            borderRadius: radius,
            child: Image.network(
              message.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                padding: const EdgeInsets.all(20),
                color: AppColors.surface,
                child: const Icon(Icons.broken_image_outlined,
                    color: AppColors.inkMuted),
              ),
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: maxWidth),
        decoration: BoxDecoration(
          color: mine ? AppColors.ink : AppColors.white,
          borderRadius: radius,
        ),
        child: Text(
          message.text,
          style: TextStyle(
            fontSize: 14,
            color: mine ? AppColors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.busy,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            IconButton(
              onPressed: busy ? null : onAttach,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.image_outlined),
              color: AppColors.inkMuted,
              tooltip: 'Share an outfit photo',
            ),
            Expanded(
              child: TextField(
                controller: controller,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(hintText: 'Type a message…'),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onSend,
              child: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: AppColors.ink,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_upward_rounded,
                    color: AppColors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Replaces the composer when I've blocked the other person.
class _BlockedBar extends ConsumerWidget {
  const _BlockedBar({required this.otherUid});
  final String otherUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authStateProvider).value?.uid;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Icon(Icons.block_rounded, size: 18, color: AppColors.inkMuted),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'You blocked this user. Unblock to chat.',
                style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
              ),
            ),
            TextButton(
              onPressed: me == null
                  ? null
                  : () => ref.read(blockRepoProvider).unblock(me, otherUid),
              child: const Text('Unblock'),
            ),
          ],
        ),
      ),
    );
  }
}
