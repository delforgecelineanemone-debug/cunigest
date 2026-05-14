import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Barre de recherche avec debounce intégré (300 ms).
/// Utilisée en tête de liste (lapins, lots, cages…).
class CuSearchBar extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final Duration debounce;

  const CuSearchBar({
    super.key,
    required this.onChanged,
    this.hint = 'Rechercher…',
    this.onClear,
    this.debounce = const Duration(milliseconds: 300),
  });

  @override
  State<CuSearchBar> createState() => _CuSearchBarState();
}

class _CuSearchBarState extends State<CuSearchBar> {
  final _ctrl = TextEditingController();
  DateTime? _lastType;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _lastType = DateTime.now();
    final captured = _lastType;
    Future.delayed(widget.debounce, () {
      if (captured == _lastType) widget.onChanged(v);
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? CuColors.raisedDark : CuColors.raisedLight;
    final border = isDark ? CuColors.borderDark : CuColors.borderLight;
    final hint =
        isDark ? CuColors.textDisabledDark : CuColors.textDisabledLight;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: CuRadius.mdAll,
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          const SizedBox(width: CuSpacing.md),
          Icon(Icons.search, size: 20, color: hint),
          const SizedBox(width: CuSpacing.sm),
          Expanded(
            child: TextField(
              controller: _ctrl,
              onChanged: _onChanged,
              style: CuTypography.textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? CuColors.textPrimaryDark
                    : CuColors.textPrimaryLight,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: CuTypography.textTheme.bodyMedium
                    ?.copyWith(color: hint),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          if (_ctrl.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _ctrl.clear();
                widget.onChanged('');
                widget.onClear?.call();
                setState(() {});
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: CuSpacing.sm),
                child: Icon(Icons.close, size: 18, color: hint),
              ),
            )
          else
            const SizedBox(width: CuSpacing.md),
        ],
      ),
    );
  }
}
