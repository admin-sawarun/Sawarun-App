import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/admin_session.dart';
import '../data/admin_web_api.dart';
import '../widgets/common.dart';

class AdminNavItem {
  const AdminNavItem(this.path, this.label, this.icon, this.activeIcon);
  final String path;
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

const adminNavItems = [
  AdminNavItem('/dashboard', 'Dashboard', Icons.space_dashboard_outlined,
      Icons.space_dashboard_rounded),
  AdminNavItem(
      '/users', 'Users', Icons.people_outline_rounded, Icons.people_rounded),
  AdminNavItem('/brands', 'Brands', Icons.storefront_outlined,
      Icons.storefront_rounded),
  AdminNavItem('/products', 'Products', Icons.shopping_bag_outlined,
      Icons.shopping_bag_rounded),
  AdminNavItem(
      '/reports', 'Reports', Icons.flag_outlined, Icons.flag_rounded),
  AdminNavItem('/tuning', 'AI Tuning', Icons.tune_outlined, Icons.tune_rounded),
];

/// Authenticated layout: sidebar (≥1000px), collapsible rail (700–1000px) or
/// drawer (<700px), plus a top bar with the page title and a refresh button.
class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  bool _railExpanded = false;

  AdminNavItem get _current => adminNavItems.firstWhere(
        (i) => widget.location.startsWith(i.path),
        orElse: () => adminNavItems.first,
      );

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 700;
    final wide = width >= 1000;
    final expanded = wide || _railExpanded;

    final sidebar = _Sidebar(
      expanded: mobile || expanded,
      current: _current.path,
      onNavigate: (path) {
        if (mobile) Navigator.of(context).maybePop();
        context.go(path);
      },
      onToggle: wide || mobile
          ? null
          : () => setState(() => _railExpanded = !_railExpanded),
    );

    final body = Column(
      children: [
        _TopBar(
          title: _current.label,
          showMenu: mobile,
          onRefresh: () => refreshAll(ref),
        ),
        Expanded(child: widget.child),
      ],
    );

    return Scaffold(
      drawer: mobile ? Drawer(width: 272, child: sidebar) : null,
      body: mobile
          ? body
          : Row(
              children: [
                SizedBox(
                  width: expanded ? 248 : 76,
                  child: sidebar,
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.showMenu,
    required this.onRefresh,
  });
  final String title;
  final bool showMenu;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: EdgeInsets.symmetric(horizontal: showMenu ? 8 : 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AdminPalette.border)),
      ),
      child: Row(
        children: [
          if (showMenu)
            IconButton(
              tooltip: 'Menu',
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          Expanded(
            child: Text(title,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh'),
          ),
          if (showMenu) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({
    required this.expanded,
    required this.current,
    required this.onNavigate,
    this.onToggle,
  });
  final bool expanded;
  final String current;
  final ValueChanged<String> onNavigate;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(adminSessionProvider);
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 68,
              child: Row(
                mainAxisAlignment: expanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  if (expanded) const SizedBox(width: 20),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AdminPalette.accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Text('S',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 17)),
                  ),
                  if (expanded) ...[
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                              text: 'Savarun',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                          TextSpan(
                              text: '  Admin',
                              style: TextStyle(
                                  color: AdminPalette.muted,
                                  fontWeight: FontWeight.w500)),
                        ]),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 17),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(),
            const SizedBox(height: 12),
            for (final item in adminNavItems)
              _NavTile(
                item: item,
                selected: item.path == current,
                expanded: expanded,
                onTap: () => onNavigate(item.path),
              ),
            const Spacer(),
            if (onToggle != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: IconButton(
                  tooltip: expanded ? 'Collapse' : 'Expand',
                  onPressed: onToggle,
                  icon: Icon(expanded
                      ? Icons.keyboard_double_arrow_left_rounded
                      : Icons.keyboard_double_arrow_right_rounded),
                ),
              ),
            const Divider(),
            ListenableBuilder(
              listenable: session,
              builder: (context, _) => _UserFooter(
                name: session.displayName,
                contact: session.contact,
                photoURL: session.user?.photoURL,
                expanded: expanded,
                onSignOut: () async {
                  final ok = await confirmAction(context,
                      title: 'Sign out?',
                      message: 'You will need to sign in again to continue.',
                      confirmLabel: 'Sign out',
                      destructive: false);
                  if (ok) await session.signOut();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });
  final AdminNavItem item;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AdminPalette.accent : AdminPalette.inkSoft;
    final tile = Material(
      color: selected ? AdminPalette.accentSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment:
                expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              if (expanded) const SizedBox(width: 14),
              Icon(selected ? item.activeIcon : item.icon,
                  size: 21, color: color),
              if (expanded) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(item.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          color: color,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: expanded ? tile : Tooltip(message: item.label, child: tile),
    );
  }
}

class _UserFooter extends StatelessWidget {
  const _UserFooter({
    required this.name,
    required this.contact,
    required this.photoURL,
    required this.expanded,
    required this.onSignOut,
  });
  final String name;
  final String? contact;
  final String? photoURL;
  final bool expanded;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    if (!expanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Tooltip(
                message: name,
                child: UserAvatar(url: photoURL, name: name, size: 34)),
            const SizedBox(height: 8),
            IconButton(
              tooltip: 'Sign out',
              onPressed: onSignOut,
              icon: const Icon(Icons.logout_rounded, size: 20),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        children: [
          UserAvatar(url: photoURL, name: name, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
                if (contact != null && contact != name)
                  Text(contact!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AdminPalette.muted)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}
