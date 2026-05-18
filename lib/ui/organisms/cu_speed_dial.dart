import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Action secondaire du Speed Dial FAB.
class CuSpeedDialItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const CuSpeedDialItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

/// FAB Speed Dial — bouton central ➕ qui s'ouvre en éventail vers le haut.
/// Utilisé dans MainScaffold pour les créations rapides.
class CuSpeedDial extends StatefulWidget {
  final List<CuSpeedDialItem> items;

  const CuSpeedDial({super.key, required this.items});

  @override
  State<CuSpeedDial> createState() => _CuSpeedDialState();
}

class _CuSpeedDialState extends State<CuSpeedDial>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeRotate;

  bool get _open => _ctrl.value > 0.5;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fadeRotate = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.mediumImpact();
    _open ? _ctrl.reverse() : _ctrl.forward();
  }

  void _close() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Mini-FABs (du plus bas au plus haut)
            if (_ctrl.value > 0)
              ...widget.items.reversed.map((item) {
                return FadeTransition(
                  opacity: _fadeRotate,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.5),
                      end: Offset.zero,
                    ).animate(_fadeRotate),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: CuSpacing.md),
                      child: _MiniFab(item: item, onTap: () {
                        _close();
                        item.onTap();
                      }),
                    ),
                  ),
                );
              }).toList().reversed,

            // FAB principal
            FloatingActionButton(
              onPressed: _toggle,
              backgroundColor: CuColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              child: AnimatedRotation(
                turns: _open ? 0.125 : 0,
                duration: const Duration(milliseconds: 220),
                child: const Icon(Icons.add, size: 28),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MiniFab extends StatelessWidget {
  final CuSpeedDialItem item;
  final VoidCallback onTap;

  const _MiniFab({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? CuColors.cardDark : CuColors.cardLight;

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label pill
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: CuSpacing.md,
              vertical: CuSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: CuRadius.mdAll,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x18000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                )
              ],
            ),
            child: Text(
              item.label,
              style: CuTypography.textTheme.labelMedium?.copyWith(
                color: item.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: CuSpacing.sm),
          // Mini bouton icône
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: item.color,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                )
              ],
            ),
            child: Icon(item.icon, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}
