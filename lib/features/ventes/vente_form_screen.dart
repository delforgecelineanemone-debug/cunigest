// ──────────────────────────────────────────────────────────────
// Écran : Formulaire Vente
// ──────────────────────────────────────────────────────────────
// Permet d'enregistrer la vente d'un lapin spécifique
// ou d'un lot de lapins.
//
// IMPORTANT : si le lapin est sous délai d'attente médicament,
// la vente pour la consommation est bloquée (réglementaire).
// L'éleveur peut forcer en confirmant qu'il s'agit d'une vente
// non destinée à la consommation (ex: vivant, reproduction).
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/lot.dart';
import '../../models/vente.dart';
import '../../models/lapin.dart';
import '../../models/soin.dart';
import '../../utils/theme.dart';
import '../../utils/validators.dart';
import '../../widgets/common_widgets.dart';
import '../../ui/cu_ui.dart';

class VenteFormScreen extends StatefulWidget {
  final Map<int, Lapin> lapinsMap;
  const VenteFormScreen({super.key, required this.lapinsMap});

  @override
  State<VenteFormScreen> createState() => _VenteFormScreenState();
}

class _VenteFormScreenState extends State<VenteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _formCtrl = CuFormController(); // V2.5 — Sprint 3 : anti-perte de saisie
  final db = DBHelper.instance;

  bool _venteIndividuelle = true;
  int? _lapinId;
  int? _lotIdSel;          // V2.5 — vente attribuée à un lot (mode "Lot anonyme")
  List<Lot> _lotsDispo = const [];
  // V2.5 — UX Sprint 1 : SANS défaut. Choix explicite obligatoire.
  // Évite qu'un lapin soit vendu "abattu" au lieu de "vivant" par accident
  // (impact réglementaire délai d'attente médicament).
  String? _typeVente;
  String _dateVente = DateTime.now().toIso8601String().substring(0, 10);

  final _acheteurCtrl = TextEditingController();
  final _prixUnitaireCtrl = TextEditingController();
  final _prixCtrl = TextEditingController();
  final _poidsCtrl = TextEditingController();
  final _quantiteCtrl = TextEditingController(text: '1');
  final _notesCtrl = TextEditingController();

  /// True quand l'utilisateur a saisi manuellement le prix total :
  /// dans ce cas on n'écrase plus avec le calcul auto.
  bool _prixTotalManuel = false;

  bool _saving = false;

  // Délai d'attente actif sur le lapin sélectionné (null = OK)
  Soin? _delaiActif;
  bool _checkingDelai = false;

  List<Lapin> get _lapinsVendables => widget.lapinsMap.values
      .where((l) => l.statut != 'vendu' && l.statut != 'mort')
      .toList();

  @override
  void dispose() {
    for (final c in [
      _acheteurCtrl,
      _prixUnitaireCtrl,
      _prixCtrl,
      _poidsCtrl,
      _quantiteCtrl,
      _notesCtrl,
    ]) {
      c.dispose();
    }
    _formCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _chargerLots();
  }

  Future<void> _chargerLots() async {
    final repo = await db.lots;
    final lots = await repo.getAll();
    if (!mounted) return;
    setState(() => _lotsDispo = lots);
  }

  /// Calcule prix total = prix unitaire × quantité (V2.5 — automatisation B2).
  /// N'écrase pas si l'utilisateur a saisi un prix total manuellement.
  void _recalcPrixTotal() {
    if (_prixTotalManuel) return;
    final pu = double.tryParse(_prixUnitaireCtrl.text.replaceAll(',', '.'));
    final qte = int.tryParse(_quantiteCtrl.text);
    if (pu == null || qte == null || qte <= 0) return;
    final total = pu * qte;
    final formatted =
        total == total.roundToDouble() ? total.toStringAsFixed(0) : total.toStringAsFixed(2);
    _prixCtrl.text = formatted;
  }

  Future<void> _verifierDelai(int? lapinId) async {
    if (lapinId == null) {
      setState(() => _delaiActif = null);
      return;
    }
    setState(() => _checkingDelai = true);
    final soin = await db.getSoinDelaiAttenteActif(lapinId);
    if (mounted) {
      setState(() {
        _delaiActif = soin;
        _checkingDelai = false;
      });
    }
  }

  /// Le type de vente correspond-il à de la consommation (donc bloqué par délai) ?
  /// 'abattu' = vente carcasse → bloqué par délai d'attente médicament.
  /// 'vivant' / 'lapereau' = lapin vivant → autorisé même sous délai.
  bool get _venteConsommation {
    if (_typeVente == null) return false;
    final t = _typeVente!.toLowerCase();
    return t == 'abattu' ||
        t.contains('viande') ||
        t.contains('abattage') ||
        t.contains('carcasse') ||
        t.contains('consommation');
  }

  @override
  Widget build(BuildContext context) {
    return CuFormScaffold(
      controller: _formCtrl,
      appBar: const CuAppBar(
        title: 'Nouvelle vente',
        accent: CuColors.accentFinance,
        showActions: false,
      ),
      child: Form(
        key: _formKey,
        onChanged: _formCtrl.markDirty,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('Type de vente'),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Lapin précis')),
                ButtonSegment(value: false, label: Text('Lot anonyme')),
              ],
              selected: {_venteIndividuelle},
              onSelectionChanged: (s) => setState(() {
                _venteIndividuelle = s.first;
                if (!_venteIndividuelle) {
                  _lapinId = null;
                  _delaiActif = null;
                }
              }),
            ),

            if (_venteIndividuelle) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _lapinId,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Lapin vendu *', prefixIcon: Icon(Icons.pets)),
                items: _lapinsVendables
                    .map((l) => DropdownMenuItem(
                        value: l.id,
                        child: Text('${l.displayName} (${l.numeroBague})',
                            overflow: TextOverflow.ellipsis)))
                    .toList(),
                validator: (v) => v == null ? 'Sélectionnez un lapin' : null,
                onChanged: (v) {
                  setState(() {
                    _lapinId = v;
                    final lapin = widget.lapinsMap[v];
                    if (lapin?.poids != null) {
                      _poidsCtrl.text = lapin!.poids.toString();
                    }
                  });
                  _verifierDelai(v);
                },
              ),

              // ── Avertissement délai d'attente ──
              if (_checkingDelai)
                const Padding(
                    padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
              if (!_checkingDelai && _delaiActif != null) _buildDelaiBanner(),
            ] else ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantiteCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Nombre de lapins vendus *',
                    prefixIcon: Icon(Icons.numbers)),
                validator: Validators.quantiteEntiere,
                onChanged: (_) => _recalcPrixTotal(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _prixUnitaireCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Prix unitaire',
                  prefixIcon: const Icon(Icons.sell_outlined),
                  suffixText: AppTheme.devise,
                  helperText: 'Optionnel — calcule le prix total automatiquement',
                  helperMaxLines: 2,
                ),
                // Optionnel mais si saisi : > 0.
                validator: (v) => Validators.prix(v, requisField: false),
                onChanged: (_) => _recalcPrixTotal(),
              ),
              if (_lotsDispo.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: _lotIdSel,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Lot d\'origine (optionnel)',
                    prefixIcon: Icon(Icons.groups),
                    helperText: 'Pour calculer la rentabilité du lot',
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('— Aucun —'),
                    ),
                    ..._lotsDispo.map((l) => DropdownMenuItem<int?>(
                          value: l.id,
                          child: Text(
                            '${l.code} (${l.nombreInitial} sujets — ${l.statut})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                  ],
                  onChanged: (v) => setState(() => _lotIdSel = v),
                ),
              ],
            ],
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: _typeVente,
              decoration: const InputDecoration(
                  labelText: 'État du produit *',
                  prefixIcon: Icon(Icons.category),
                  helperText:
                      'Choix obligatoire — détermine si la vente est soumise au délai d\'attente médicament.',
                  helperMaxLines: 2),
              hint: const Text('— Sélectionnez —'),
              items: Vente.typesVente
                  .map((t) =>
                      DropdownMenuItem(value: t, child: Text(Vente.typesVenteLabels[t]!)))
                  .toList(),
              validator: (v) => v == null ? 'État obligatoire' : null,
              onChanged: (v) => setState(() => _typeVente = v),
            ),
            const SizedBox(height: 12),

            _section('Transaction'),
            _datePicker('Date de vente *', _dateVente,
                (d) => setState(() => _dateVente = d)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _prixCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: 'Prix total *',
                  prefixIcon: const Icon(Icons.attach_money),
                  suffixText: AppTheme.devise),
              // Validator centralisé : refuse négatif, zéro, montant aberrant.
              validator: Validators.prix,
              onChanged: (_) {
                _prixTotalManuel = true;
                setState(() {}); // rebuild bandeau marge brute
              },
            ),
            // V2.5 — Sprint 3 : bandeau marge brute si prix d'achat du
            // reproducteur connu (vente individuelle uniquement).
            if (_margeAffichable()) ...[
              const SizedBox(height: 8),
              _bandeauMarge(),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _acheteurCtrl,
              decoration: const InputDecoration(
                  labelText: 'Nom du client', prefixIcon: Icon(Icons.person)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _poidsCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Poids total (kg)',
                  prefixIcon: Icon(Icons.monitor_weight),
                  suffixText: 'kg',
                  helperText:
                      'Poids vif si vivant, carcasse si abattu — selon le type ci-dessus.',
                  helperMaxLines: 2),
              // Optionnel mais si saisi : borné réaliste (lot possible).
              validator: Validators.poidsLot,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Notes', prefixIcon: Icon(Icons.notes)),
            ),
            const SizedBox(height: 24),
            // V2.5 — Sprint 4 : CTA unifié via CuButton (design system).
            CuButton(
              label: 'Enregistrer la vente',
              icon: Icons.check,
              variant: CuButtonVariant.primary,
              size: CuButtonSize.lg,
              fullWidth: true,
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ).responsive(),
    );
  }

  /// V2.5 — Sprint 3 : marge brute = prix vente - prix d'achat
  /// (uniquement si lapin individuel ET prix d'achat connu).
  bool _margeAffichable() {
    if (!_venteIndividuelle || _lapinId == null) return false;
    final lapin = widget.lapinsMap[_lapinId];
    if (lapin?.prixAchat == null) return false;
    final prix = double.tryParse(_prixCtrl.text.replaceAll(',', '.'));
    return prix != null && prix > 0;
  }

  Widget _bandeauMarge() {
    final lapin = widget.lapinsMap[_lapinId];
    final achat = lapin!.prixAchat!;
    final prix = double.parse(_prixCtrl.text.replaceAll(',', '.'));
    final marge = prix - achat;
    final positif = marge >= 0;
    final color = positif ? CuColors.primary : AppTheme.error;
    final signe = positif ? '+' : '';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(positif ? Icons.trending_up : Icons.trending_down,
              size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Marge brute : $signe${marge.toStringAsFixed(0)} ${AppTheme.devise} '
              '(achat : ${achat.toStringAsFixed(0)} ${AppTheme.devise})',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDelaiBanner() {
    final fin = _delaiActif!.finDelaiAttente;
    final finStr = fin != null ? formatDate(fin.toIso8601String().substring(0, 10)) : '?';
    final color = _venteConsommation ? Colors.red : Colors.orange;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.medication_liquid, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ Délai d\'attente médicament en cours',
                    style: TextStyle(fontWeight: FontWeight.bold, color: color),
                  ),
                  Text(
                    'Soin "${_delaiActif!.typeSoin}" du ${formatDate(_delaiActif!.dateSoin)}, '
                    '${_delaiActif!.delaiAttenteJours} jours d\'attente. '
                    'Fin du délai : $finStr.',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  if (_venteConsommation)
                    const Text(
                      'La vente pour consommation est INTERDITE pendant cette période.',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
                    )
                  else
                    const Text(
                      'La vente vivante (reproducteur, animalerie) reste possible.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(t,
            style: TextStyle(fontWeight: FontWeight.bold, color: context.cuTextPrimary)),
      );

  Widget _datePicker(String label, String value, Function(String) onPick) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.parse(value),
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 30)),
        );
        if (picked != null) onPick(picked.toIso8601String().substring(0, 10));
      },
      child: InputDecorator(
        decoration:
            InputDecoration(labelText: label, prefixIcon: const Icon(Icons.calendar_today)),
        child: Text(formatDate(value)),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Bloquer la vente pour consommation si délai d'attente actif
    if (_venteConsommation && _delaiActif != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('🚫 Vente bloquée'),
          content: Text(
              'Ce lapin est sous délai d\'attente médicament jusqu\'au ${formatDate(_delaiActif!.finDelaiAttente?.toIso8601String().substring(0, 10))}.\n\n'
              'La vente pour consommation est interdite (résidus de médicaments). '
              'Si vous confirmez quand même, vous prenez la responsabilité de cette infraction.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Annuler')),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Forcer'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _saving = true);

    final vente = Vente(
      lapinId: _venteIndividuelle ? _lapinId : null,
      lotId: _venteIndividuelle ? null : _lotIdSel,
      dateVente: _dateVente,
      // Garanti non-null par le validator du formulaire (validate() en haut de _save).
      typeVente: _typeVente!,
      acheteur: _acheteurCtrl.text.trim().isEmpty ? null : _acheteurCtrl.text.trim(),
      prixVente: double.parse(_prixCtrl.text.replaceAll(',', '.')),
      poids: _poidsCtrl.text.isEmpty
          ? null
          : double.tryParse(_poidsCtrl.text.replaceAll(',', '.')),
      quantite: _venteIndividuelle ? 1 : int.parse(_quantiteCtrl.text),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    try {
      await db.insertVente(vente);
      if (mounted) {
        _formCtrl.markClean();
        showSuccessSnackBar(context, 'Vente enregistrée !');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showErrorSnackBar(context, 'Erreur d\'enregistrement : $e');
      }
    }
  }
}
