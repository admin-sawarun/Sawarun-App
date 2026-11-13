import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_web_api.dart';
import '../widgets/common.dart';
import 'users_page.dart' show showUserDetailPanel;

class PostsPage extends ConsumerStatefulWidget {
  const PostsPage({super.key});

  @override
  ConsumerState<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends ConsumerState<PostsPage> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _q = '';

  List<PostRow> _posts = [];
  String? _cursor;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await fetchPosts(q: _q);
      if (!mounted || id != _requestId) return;
      setState(() {
        _posts = page.items;
        _cursor = page.nextCursor;
      });
    } catch (e) {
      if (mounted && id == _requestId) setState(() => _error = e);
    } finally {
      if (mounted && id == _requestId) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await fetchPosts(q: _q, cursor: _cursor);
      if (!mounted) return;
      final seen = _posts.map((p) => p.id).toSet();
      setState(() {
        _posts = [..._posts, ...page.items.where((p) => seen.add(p.id))];
        _cursor = page.nextCursor;
      });
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (v.trim() == _q) return;
      _q = v.trim();
      _load();
    });
  }

  /// Client-side filter too, in case the backend ignores q.
  List<PostRow> get _visible {
    final q = _q.toLowerCase();
    if (q.isEmpty) return _posts;
    return _posts
        .where((p) => [p.caption, p.authorName, p.authorUsername, p.style]
            .any((f) => f != null && f.toLowerCase().contains(q)))
        .toList();
  }

  Future<void> _open(PostRow p) async {
    final deleted = await showDialog<bool>(
      context: context,
      builder: (_) => _PostPreviewDialog(post: p, onAuthor: _openAuthor),
    );
    if (deleted == true && mounted) {
      setState(() => _posts = _posts.where((x) => x.id != p.id).toList());
    }
  }

  void _openAuthor(PostRow p) {
    final uid = p.authorUid;
    if (uid == null) return;
    showUserDetailPanel(
      context,
      UserRow(
        uid: uid,
        name: p.authorName,
        username: p.authorUsername,
        photoURL: p.authorPhotoURL,
        status: 'active',
        followers: 0,
      ),
      onStatusChanged: (_) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(refreshTickProvider, (_, _) => _load());
    final posts = _visible;
    return PageScroll(
      children: [
        PanelCard(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 340,
                child: TextField(
                  controller: _search,
                  onChanged: _onSearch,
                  onSubmitted: (v) {
                    _debounce?.cancel();
                    _q = v.trim();
                    _load();
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search caption, author or style',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                  ),
                ),
              ),
              if (!_loading && _error == null)
                Text('${posts.length} shown',
                    style: const TextStyle(
                        fontSize: 13, color: AdminPalette.muted)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_loading)
          const _GridSkeleton()
        else if (_error != null)
          PanelCard(child: ErrorState(error: _error!, onRetry: _load))
        else if (posts.isEmpty)
          PanelCard(
            child: EmptyState(
              title: 'No posts found',
              subtitle: _q.isEmpty ? null : 'Try a different search.',
              icon: Icons.photo_library_outlined,
            ),
          )
        else
          ResponsiveGrid(
            minItemWidth: 220,
            maxColumns: 5,
            children: [
              for (final p in posts)
                _PostCard(
                  post: p,
                  onTap: () => _open(p),
                  onAuthor: () => _openAuthor(p),
                ),
            ],
          ),
        if (!_loading && _error == null && _cursor != null)
          LoadMoreButton(loading: _loadingMore, onPressed: _loadMore),
      ],
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      minItemWidth: 220,
      maxColumns: 5,
      children: [
        for (var i = 0; i < 10; i++)
          const AspectRatio(
            aspectRatio: 0.8,
            child: Skeleton(radius: 16),
          ),
      ],
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.onTap,
    required this.onAuthor,
  });
  final PostRow post;
  final VoidCallback onTap;
  final VoidCallback onAuthor;

  @override
  Widget build(BuildContext context) {
    final p = post;
    return Material(
      color: AdminPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AdminPalette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(
                builder: (_, c) => NetImage(p.imageUrl,
                    width: c.maxWidth, height: c.maxHeight, radius: 0),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AuthorChip(post: p, onTap: onAuthor, size: 24),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: Text(
                      p.caption ?? 'No caption',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: p.caption == null
                              ? AdminPalette.muted
                              : AdminPalette.inkSoft),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.favorite_rounded,
                          size: 14, color: Color(0xFFD14D7E)),
                      const SizedBox(width: 4),
                      Text(formatCount(p.likes),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Tooltip(
                        message: formatDateTime(p.createdAt),
                        child: Text(timeAgo(p.createdAt),
                            style: const TextStyle(
                                fontSize: 12, color: AdminPalette.muted)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthorChip extends StatelessWidget {
  const _AuthorChip({required this.post, required this.onTap, this.size = 28});
  final PostRow post;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = post;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        UserAvatar(url: p.authorPhotoURL, name: p.authorName, size: size),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(p.authorName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              if (p.authorUsername != null && size > 26)
                Text('@${p.authorUsername}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AdminPalette.muted)),
            ],
          ),
        ),
      ],
    );
    if (p.authorUid == null) return row;
    return Tooltip(
      message: 'View user',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(2), child: row),
      ),
    );
  }
}

class _PostPreviewDialog extends ConsumerStatefulWidget {
  const _PostPreviewDialog({required this.post, required this.onAuthor});
  final PostRow post;
  final ValueChanged<PostRow> onAuthor;

  @override
  ConsumerState<_PostPreviewDialog> createState() => _PostPreviewDialogState();
}

class _PostPreviewDialogState extends ConsumerState<_PostPreviewDialog> {
  bool _busy = false;

  Future<void> _delete() async {
    final ok = await confirmAction(
      context,
      title: 'Delete this post?',
      message: 'The post is removed from the feed for everyone. '
          'This cannot be undone.',
      confirmLabel: 'Delete post',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(adminWebRepoProvider).deletePost(widget.post.id);
      if (!mounted) return;
      showToast(context, 'Post deleted');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        showToast(context, errorText(e), error: true);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 900;

    final image = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: const Color(0xFFF0EEF5),
        child: p.imageUrl == null
            ? const SizedBox(
                height: 320,
                child: Center(
                    child: Icon(Icons.image_outlined,
                        color: AdminPalette.muted, size: 40)),
              )
            : Image.network(
                p.imageUrl!,
                fit: BoxFit.contain,
                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                errorBuilder: (_, _, _) => const SizedBox(
                  height: 320,
                  child: Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: AdminPalette.muted, size: 40)),
                ),
              ),
      ),
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _AuthorChip(
          post: p,
          size: 40,
          onTap: () {
            Navigator.of(context).pop();
            widget.onAuthor(p);
          },
        ),
        const SizedBox(height: 16),
        Text(p.caption ?? 'No caption',
            style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: p.caption == null ? AdminPalette.muted : AdminPalette.ink)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (p.style != null) StatusChip('featured', label: capitalize(p.style!)),
            StatusChip('other', label: '${formatCount(p.likes)} likes'),
          ],
        ),
        const SizedBox(height: 16),
        _kv('Posted', formatDateTime(p.createdAt)),
        _kv('Post ID', p.id),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _busy ? null : _delete,
          style: OutlinedButton.styleFrom(
            foregroundColor: AdminPalette.danger,
            side: const BorderSide(color: Color(0xFFF2C4BF)),
          ),
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.delete_outline_rounded, size: 18),
          label: const Text('Delete post'),
        ),
      ],
    );

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: 1000, maxHeight: size.height - 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Post',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: image),
                          const SizedBox(width: 24),
                          Expanded(flex: 2, child: details),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [image, const SizedBox(height: 20), details],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Text(k,
                  style:
                      const TextStyle(fontSize: 13, color: AdminPalette.muted)),
            ),
            Expanded(
                child: SelectableText(v, style: const TextStyle(fontSize: 13))),
          ],
        ),
      );
}
