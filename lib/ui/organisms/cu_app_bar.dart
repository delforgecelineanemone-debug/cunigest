// CuAppBar — AppBar global standardisée CuniGest
//
// Fournit les actions globales (notifications, QR, réglages, déconnexion)
// pour TOUS les écrans, avec un titre + emoji optionnel et une couleur
// d'accent par module.
//
// Usage minimal (écran enfant) :
//   appBar: const CuAppBar(title: 'Lapins')
//
// Usage onglet racine (avec branding) :
//   appBar: const CuAppBar.brand()
//
// Usage écran formulaire (pas d'actions globales) :
//   appBar: const CuAppBar(title: 'Nouveau lapin', showActions: false)
//
// Couleur d'accent module :
//   appBar: const CuAppBar(title: 'Reproduction', accent: CuColors.accentRepro)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/alertes/alertes_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/qr/qr_scan_screen.dart';
import '../../features/reglages/reglages_screen.dart';
import '../../providers/state_providers.dart';
import '../../widgets/common_widgets.dart';
import '../tokens/colors.dart';

class CuAppBar extends ConsumerWidget implements PreferredSizeWidget {
  /// Titre affiché.
  final String title;

  /// Emoji prefix optionnel ('🌾', '💰'…). Centralise la convention.
  final String? emoji;

  /// Mode « branding » : affiche le logo + « CuniGest » au lieu d'un titre simple.
  /// Utilisé sur l'écran d'Accueil.
  final bool brand;

  /// Affiche les actions globales (notifs / QR / réglages / déconnexion).
  /// Met à false sur les écrans formulaire / détail.
  final bool showActions;

  /// Affiche l'icône QR.
  final bool showQr;

  /// Affiche la cloche notifications.
  final bool showNotifications;

  /// Affiche l'engrenage réglages (limité aux admins).
  final bool showSettings;

  /// Affiche l'icône déconnexion (uniquement si user authentifié).
  final bool showLogout;

  /// Couleur d'accent du module (override le primary).
  final Color? accent;

  /// Actions supplémentaires propres à l'écran (avant les actions globales).
  final List<Widget> extraActions;

  /// Widget bottom (TabBar, segmented…).
  final PreferredSizeWidget? bottom;

  /// Centre le titre.
  final bool centerTitle;

  /// Désactive le back automatique.
  final bool automaticallyImplyLeading;

  /// Leading custom.
  final Widget? leading;

  const CuAppBar({
    super.key,
    required this.title,
    this.emoji,
    this.brand = false,
    this.showActions = true,
    this.showQr = true,
    this.showNotifications = true,
    this.showSettings = true,
    this.showLogout = false,
    this.accent,
    this.extraActions = const [],
    this.bottom,
    this.centerTitle = false,
    this.automaticallyImplyLeading = true,
    this.leading,
  });

  /// Variante « onglet racine Accueil » : logo + branding + déconnexion.
  const CuAppBar.brand({
    super.key,
    this.accent,
    this.extraActions = const [],
    this.bottom,
  })  : title = 'CuniGest',
        emoji = null,
        brand = true,
        showActions = true,
        showQr = true,
        showNotifications = true,
        showSettings = true,
        showLogout = true,
        centerTitle = false,
        automaticallyImplyLeading = false,
        leading = null;

  @override
  Size get preferredSize {
    const base = kToolbarHeight;
    final extra = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(base + extra);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final alertesCount = ref.watch(alertesCountProvider).count;

    final estAdmin = session.isAdmin || !session.isAuthenticated;
    final bg = accent ?? CuColors.primary;

    final actions = <Widget>[];

    // Actions custom de l'écran d'abord
    actions.addAll(extraActions);

    if (showActions) {
      if (showQr) {
        actions.add(
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scanner un QR',
            onPressed: () => _push(context, const QrScanScreen()),
          ),
        );
      }
      if (showNotifications) {
        actions.add(
          _NotifBell(
            count: alertesCount,
            onTap: () => _push(context, const AlertesScreen()),
          ),
        );
      }
      if (showSettings && estAdmin) {
        actions.add(
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Réglages',
            onPressed: () => _push(context, const ReglagesScreen()),
          ),
        );
      }
      if (showLogout && session.isAuthenticated) {
        actions.add(
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: () => _confirmLogout(context, ref),
          ),
        );
      }
    }

    return AppBar(
      backgroundColor: bg,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: centerTitle,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading,
      title: brand ? _BrandTitle() : _PlainTitle(title: title, emoji: emoji),
      actions: actions,
      bottom: bottom,
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Se déconnecter ?',
      message: 'Vous reviendrez à l\'écran de connexion.',
      confirmLabel: 'Déconnexion',
    );
    if (!ok || !context.mounted) return;
    ref.read(sessionProvider.notifier).logout();
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }
}

// ── Titre simple : emoji + libellé ────────────────────────────

class _PlainTitle extends StatelessWidget {
  final String title;
  final String? emoji;
  const _PlainTitle({required this.title, this.emoji});

  @override
  Widget build(BuildContext context) {
    final text = emoji != null ? '$emoji  $title' : title;
    return Text(
      text,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

// ── Titre branding : logo + nom app ───────────────────────────

class _BrandTitle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.eco, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Text(
          'CuniGest',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

// ── Cloche notifications avec badge ──────────────────────────

class _NotifBell extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _NotifBell({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          tooltip: 'Notifications',
          onPressed: onTap,
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: CuColors.danger,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                count > 9 ? '9+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
