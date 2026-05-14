// ──────────────────────────────────────────────────────────────
// Écran : Calculatrices pro (V2.4 — Phase 4 — Outils)
// ──────────────────────────────────────────────────────────────
// 3 calculatrices utiles à l'éleveur :
//   1. Ration alimentaire (kg/jour pour X lapins)
//   2. Prix de revient unitaire (coûts totaux / nb produit)
//   3. Projection de croissance (poids futur estimé GMQ)
// Aucun stockage : pures formules.
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/theme.dart';
import '../../ui/cu_ui.dart';

class CalculatricesScreen extends StatelessWidget {
  const CalculatricesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: CuAppBar(
          title: 'Calculatrices',
          emoji: '🧮',
          showActions: false,
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.grass), text: 'Ration'),
              Tab(icon: Icon(Icons.payments), text: 'Prix revient'),
              Tab(icon: Icon(Icons.trending_up), text: 'Croissance'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _RationCalc(),
            _PrixRevientCalc(),
            _CroissanceCalc(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 1. Ration alimentaire
// ─────────────────────────────────────────────
class _RationCalc extends StatefulWidget {
  const _RationCalc();
  @override
  State<_RationCalc> createState() => _RationCalcState();
}

class _RationCalcState extends State<_RationCalc> {
  final _nb = TextEditingController(text: '10');
  final _ration = TextEditingController(text: '120');
  final _jours = TextEditingController(text: '30');

  @override
  void dispose() {
    _nb.dispose();
    _ration.dispose();
    _jours.dispose();
    super.dispose();
  }

  double get _nombreLapins => double.tryParse(_nb.text.replaceAll(',', '.')) ?? 0;
  double get _gParJour =>
      double.tryParse(_ration.text.replaceAll(',', '.')) ?? 0;
  int get _nombreJours => int.tryParse(_jours.text) ?? 0;

  @override
  Widget build(BuildContext context) {
    final besoinJour = _nombreLapins * _gParJour / 1000; // kg/j
    final besoinPeriode = besoinJour * _nombreJours;
    final besoin25kg = besoinPeriode / 25;

    return _Form(
      children: [
        _Input(
          ctrl: _nb,
          label: 'Nombre de lapins',
          icon: Icons.pets,
          onChanged: () => setState(() {}),
        ),
        _Input(
          ctrl: _ration,
          label: 'Ration par lapin/jour (g)',
          icon: Icons.grass,
          onChanged: () => setState(() {}),
        ),
        _Input(
          ctrl: _jours,
          label: 'Période (jours)',
          icon: Icons.calendar_today,
          decimal: false,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 16),
        _Result(
          label: 'Besoin journalier',
          value: '${besoinJour.toStringAsFixed(2)} kg/jour',
          icon: Icons.today,
        ),
        _Result(
          label: 'Besoin sur la période',
          value: '${besoinPeriode.toStringAsFixed(2)} kg',
          icon: Icons.event_repeat,
        ),
        _Result(
          label: 'Sacs de 25 kg nécessaires',
          value: '${besoin25kg.toStringAsFixed(1)} sacs',
          icon: Icons.shopping_bag,
          highlight: true,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// 2. Prix de revient
// ─────────────────────────────────────────────
class _PrixRevientCalc extends StatefulWidget {
  const _PrixRevientCalc();
  @override
  State<_PrixRevientCalc> createState() => _PrixRevientCalcState();
}

class _PrixRevientCalcState extends State<_PrixRevientCalc> {
  final _aliment = TextEditingController(text: '180');
  final _soins = TextEditingController(text: '30');
  final _autres = TextEditingController(text: '20');
  final _nbProduit = TextEditingController(text: '40');
  final _prixVente = TextEditingController(text: '12');

  @override
  void dispose() {
    _aliment.dispose();
    _soins.dispose();
    _autres.dispose();
    _nbProduit.dispose();
    _prixVente.dispose();
    super.dispose();
  }

  double _v(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final coutTotal = _v(_aliment) + _v(_soins) + _v(_autres);
    final nbProduit = _v(_nbProduit);
    final coutUnitaire = nbProduit > 0 ? coutTotal / nbProduit : 0;
    final prixVente = _v(_prixVente);
    final marge = prixVente - coutUnitaire;
    final margePct =
        coutUnitaire > 0 ? (marge / coutUnitaire) * 100 : 0;
    final estRentable = marge > 0;

    return _Form(
      children: [
        _Input(
            ctrl: _aliment,
            label: 'Coût aliment (${AppTheme.devise})',
            icon: Icons.grass,
            onChanged: () => setState(() {})),
        _Input(
            ctrl: _soins,
            label: 'Coût soins/santé (${AppTheme.devise})',
            icon: Icons.health_and_safety,
            onChanged: () => setState(() {})),
        _Input(
            ctrl: _autres,
            label: 'Autres coûts (${AppTheme.devise})',
            icon: Icons.miscellaneous_services,
            onChanged: () => setState(() {})),
        _Input(
            ctrl: _nbProduit,
            label: 'Nombre de lapins produits',
            icon: Icons.pets,
            decimal: false,
            onChanged: () => setState(() {})),
        _Input(
            ctrl: _prixVente,
            label: 'Prix de vente unitaire (${AppTheme.devise})',
            icon: Icons.point_of_sale,
            onChanged: () => setState(() {})),
        const SizedBox(height: 16),
        _Result(
            label: 'Coût total',
            value: '${coutTotal.toStringAsFixed(2)} ${AppTheme.devise}',
            icon: Icons.summarize),
        _Result(
            label: 'Prix de revient unitaire',
            value: '${coutUnitaire.toStringAsFixed(2)} ${AppTheme.devise}',
            icon: Icons.payments,
            highlight: true),
        _Result(
            label: 'Marge unitaire',
            value:
                '${marge.toStringAsFixed(2)} ${AppTheme.devise} (${margePct.toStringAsFixed(0)} %)',
            icon: estRentable ? Icons.trending_up : Icons.trending_down,
            color: estRentable ? Colors.green : Colors.red),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// 3. Projection de croissance (GMQ)
// ─────────────────────────────────────────────
class _CroissanceCalc extends StatefulWidget {
  const _CroissanceCalc();
  @override
  State<_CroissanceCalc> createState() => _CroissanceCalcState();
}

class _CroissanceCalcState extends State<_CroissanceCalc> {
  final _poidsActuel = TextEditingController(text: '1.2');
  final _gmq = TextEditingController(text: '35');
  final _objectif = TextEditingController(text: '2.5');

  @override
  void dispose() {
    _poidsActuel.dispose();
    _gmq.dispose();
    _objectif.dispose();
    super.dispose();
  }

  double _v(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final poidsActuel = _v(_poidsActuel);
    final gmq = _v(_gmq); // g/jour
    final objectif = _v(_objectif);
    final gainKgRestant = (objectif - poidsActuel).clamp(0, double.infinity);
    final joursRestants =
        gmq > 0 ? (gainKgRestant * 1000 / gmq).ceil() : 0;
    final dateAtteinte = joursRestants > 0
        ? DateTime.now().add(Duration(days: joursRestants))
        : DateTime.now();
    final poidsDans30j = poidsActuel + (gmq * 30 / 1000);
    final poidsDans60j = poidsActuel + (gmq * 60 / 1000);

    return _Form(
      children: [
        _Input(
            ctrl: _poidsActuel,
            label: 'Poids actuel (kg)',
            icon: Icons.scale,
            onChanged: () => setState(() {})),
        _Input(
            ctrl: _gmq,
            label: 'GMQ moyen (g/jour)',
            icon: Icons.speed,
            onChanged: () => setState(() {})),
        _Input(
            ctrl: _objectif,
            label: 'Poids objectif (kg)',
            icon: Icons.flag,
            onChanged: () => setState(() {})),
        const SizedBox(height: 16),
        _Result(
            label: 'Poids dans 30 jours',
            value: '${poidsDans30j.toStringAsFixed(2)} kg',
            icon: Icons.calendar_today),
        _Result(
            label: 'Poids dans 60 jours',
            value: '${poidsDans60j.toStringAsFixed(2)} kg',
            icon: Icons.calendar_view_month),
        _Result(
            label: 'Jours pour atteindre l\'objectif',
            value: joursRestants > 0
                ? '$joursRestants jours'
                : 'Objectif déjà atteint',
            icon: Icons.timer),
        if (joursRestants > 0)
          _Result(
              label: 'Date estimée',
              value:
                  '${dateAtteinte.day}/${dateAtteinte.month}/${dateAtteinte.year}',
              icon: Icons.event,
              highlight: true),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Composants partagés
// ─────────────────────────────────────────────
class _Form extends StatelessWidget {
  const _Form({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: children,
      );
}

class _Input extends StatelessWidget {
  const _Input({
    required this.ctrl,
    required this.label,
    required this.icon,
    required this.onChanged,
    this.decimal = true,
  });
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final VoidCallback onChanged;
  final bool decimal;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
          ),
          keyboardType:
              TextInputType.numberWithOptions(decimal: decimal),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
                RegExp(decimal ? r'[0-9.,]' : r'[0-9]')),
          ],
          onChanged: (_) => onChanged(),
        ),
      );
}

class _Result extends StatelessWidget {
  const _Result({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
    this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final bool highlight;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? (highlight ? AppTheme.primary : Colors.grey.shade700);
    return Card(
      color: highlight ? AppTheme.primary.withValues(alpha: 0.08) : null,
      child: ListTile(
        leading: Icon(icon, color: c),
        title: Text(label, style: const TextStyle(fontSize: 13)),
        trailing: Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: highlight ? 16 : 14,
            color: c,
          ),
        ),
      ),
    );
  }
}
