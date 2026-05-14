// ──────────────────────────────────────────────────────────────
// GrowthChart — Courbe de croissance (V2.3 — Phase 3)
// ──────────────────────────────────────────────────────────────
// Widget réutilisable affichant une courbe (date → poids ou autre
// métrique) basée sur fl_chart. Compatible thème clair/sombre.
//
// Usage :
//   GrowthChart(
//     points: [(date1, 1.2), (date2, 1.5), ...],
//     unit: 'kg',
//     title: 'Poids moyen',
//   )
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/theme.dart';

class GrowthChart extends StatelessWidget {
  const GrowthChart({
    super.key,
    required this.points,
    this.unit = '',
    this.title,
    this.height = 220,
    this.color = AppTheme.primary,
  });

  /// Liste de (date, valeur) triée par date croissante.
  final List<(DateTime, double)> points;
  final String unit;
  final String? title;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gridColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final labelStyle = TextStyle(
      fontSize: 10,
      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
    );

    if (points.length < 2) {
      return Container(
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Text(
          points.isEmpty
              ? 'Pas encore de données.'
              : 'Au moins 2 mesures sont nécessaires pour tracer une courbe.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    final firstMs = points.first.$1.millisecondsSinceEpoch.toDouble();
    final lastMs = points.last.$1.millisecondsSinceEpoch.toDouble();
    final spots = points
        .map((p) => FlSpot(
              p.$1.millisecondsSinceEpoch.toDouble(),
              p.$2,
            ))
        .toList();

    final values = points.map((p) => p.$2).toList();
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) * 0.15;
    final chartMin = (minY - pad).clamp(0, double.infinity).toDouble();
    final chartMax = maxY + pad;

    // Alerte perte de poids : dernière pesée < précédente
    final double? perte;
    if (points.length >= 2) {
      final delta = points.last.$2 - points[points.length - 2].$2;
      perte = delta < 0 ? -delta : null;
    } else {
      perte = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title!,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        if (perte != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppTheme.error.withValues(alpha: 0.4), width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_down,
                    size: 16, color: AppTheme.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Perte de poids détectée (-${perte.toStringAsFixed(2)} $unit) — surveillez la santé.',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.error,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minX: firstMs,
              maxX: lastMs,
              minY: chartMin,
              maxY: chartMax,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: gridColor, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 38,
                    getTitlesWidget: (v, _) => Text(
                      v.toStringAsFixed(v >= 10 ? 0 : 1),
                      style: labelStyle,
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: (lastMs - firstMs) / 3,
                    getTitlesWidget: (v, _) {
                      final d = DateTime.fromMillisecondsSinceEpoch(v.toInt());
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${d.day}/${d.month}',
                          style: labelStyle,
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots.map((s) {
                    final d = DateTime.fromMillisecondsSinceEpoch(s.x.toInt());
                    return LineTooltipItem(
                      '${s.y.toStringAsFixed(2)} $unit\n${d.day}/${d.month}/${d.year}',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.25,
                  color: color,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 4,
                      color: color,
                      strokeWidth: 2,
                      strokeColor: isDark ? Colors.black : Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: color.withValues(alpha: 0.15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
