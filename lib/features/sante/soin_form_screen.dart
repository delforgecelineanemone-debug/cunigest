// ──────────────────────────────────────────────────────────────
// Écran : Formulaire Soin (Ajout / Modification)
// ──────────────────────────────────────────────────────────────
// Permet d'enregistrer un traitement médical ou vaccin.
//
// Champ "délai d'attente" : nombre de jours pendant lesquels
// le lapin ne peut pas être vendu/abattu pour la consommation.
// Pré-rempli automatiquement selon le type de soin (valeurs
// indicatives — vérifier le RCP du produit utilisé).
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/soin.dart';
import '../../models/lapin.dart';
import '../../services/business_rules_service.dart';
import '../../utils/theme.dart';
import '../../utils/validators.dart';
import '../../widgets/common_widgets.dart';
import '../../ui/cu_ui.dart';
import '../../data/cunicole_reference.dart';

class SoinFormScreen extends StatefulWidget {
  final Soin? soin;
  final Map<int, Lapin>? lapinsMap;
  final Lapin? lapinPreselect;

  const SoinFormScreen({super.key, this.soin, this.lapinsMap, this.lapinPreselect});

  @override
  State<SoinFormScreen> createState() => _SoinFormScreenState();
}

class _SoinFormScreenState extends State<SoinFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _formCtrl = CuFormController(); // V2.5 — Sprint 3 : anti-perte de saisie
  final db = DBHelper.instance;

  int? _lapinId;
  String _typeSoin = Soin.typesSoins.first;
  String _dateSoin = DateTime.now().toIso8601String().substring(0, 10);
  String? _dateRappel;
  final _produitCtrl = TextEditingController();
  final _doseCtrl = TextEditingController();
  final _vetoCtrl = TextEditingController();
  final _coutCtrl = TextEditingController();
  final _delaiCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;
  bool _toutElevage = false;

  List<Lapin> get _lapins =>
      widget.lapinsMap?.values.where((l) => l.statut == 'actif').toList() ?? [];

  @override
  void initState() {
    super.initState();
    if (widget.lapinPreselect != null) _lapinId = widget.lapinPreselect!.id;
    final s = widget.soin;
    if (s != null) {
      _lapinId = s.lapinId;
      _typeSoin = s.typeSoin;
      _dateSoin = s.dateSoin;
      _dateRappel = s.dateRappel;
      _produitCtrl.text = s.produit ?? '';
      _doseCtrl.text = s.dose ?? '';
      _vetoCtrl.text = s.veterinaire ?? '';
      _coutCtrl.text = s.cout?.toString() ?? '';
      _delaiCtrl.text = s.delaiAttenteJours?.toString() ?? '';
      _notesCtrl.text = s.notes ?? '';
      _toutElevage = s.lapinId == null;
    } else {
      _appliquerDelaiParDefaut();
      _prefillVeterinaireRecent();
    }
  }

  /// V2.5 — B5 : pré-remplit le vétérinaire avec celui du dernier soin.
  /// Évite la ressaisie du nom pour les éleveurs qui ont un vétérinaire attitré.
  Future<void> _prefillVeterinaireRecent() async {
    try {
      final recents = await (await db.soins).getAllSoins(limit: 5);
      final dernier = recents
          .map((s) => s.veterinaire)
          .firstWhere((v) => v != null && v.trim().isNotEmpty,
              orElse: () => null);
      if (dernier != null && mounted && _vetoCtrl.text.isEmpty) {
        setState(() => _vetoCtrl.text = dernier);
      }
    } catch (_) {
      // silencieux : pas critique
    }
  }

  /// Pré-remplit le délai d'attente selon le type de soin
  void _appliquerDelaiParDefaut() {
    final defaut = Soin.delaisAttenteParDefaut[_typeSoin];
    if (defaut != null) {
      _delaiCtrl.text = defaut.toString();
    } else {
      _delaiCtrl.text = '';
    }
  }

  @override
  void dispose() {
    for (final c in [
      _produitCtrl,
      _doseCtrl,
      _vetoCtrl,
      _coutCtrl,
      _delaiCtrl,
      _notesCtrl
    ]) {
      c.dispose();
    }
    _formCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CuFormScaffold(
      controller: _formCtrl,
      appBar: CuAppBar(title: widget.soin != null ? 'Modifier le soin' : 'Nouveau soin', showActions: false),
      child: Form(
        key: _formKey,
        onChanged: _formCtrl.markDirty,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('🐇 Lapin concerné'),
            SwitchListTile(
              title: const Text('Tout l\'élevage'),
              subtitle: const Text('Traitement collectif'),
              value: _toutElevage,
              onChanged: (v) => setState(() {
                _toutElevage = v;
                if (v) _lapinId = null;
              }),
              contentPadding: EdgeInsets.zero,
            ),
            if (!_toutElevage) ...[
              DropdownButtonFormField<int>(
                initialValue: _lapinId,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Sélectionner un lapin *', prefixIcon: Icon(Icons.pets)),
                items: _lapins
                    .map((l) => DropdownMenuItem(
                        value: l.id,
                        child: Text('${l.displayName} (${l.numeroBague})',
                            overflow: TextOverflow.ellipsis)))
                    .toList(),
                validator: (v) =>
                    !_toutElevage && v == null ? 'Sélectionnez un lapin' : null,
                onChanged: (v) => setState(() => _lapinId = v),
              ),
            ],
            const SizedBox(height: 12),

            _section('💉 Type de soin'),
            DropdownButtonFormField<String>(
              initialValue: _typeSoin,
              decoration: const InputDecoration(
                  labelText: 'Type de soin *',
                  prefixIcon: Icon(Icons.health_and_safety)),
              items: Soin.typesSoins
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) {
                setState(() => _typeSoin = v!);
                _appliquerDelaiParDefaut();
              },
            ),
            const SizedBox(height: 12),

            _section('📅 Dates'),
            _datePicker('Date du soin *', _dateSoin, (d) => setState(() => _dateSoin = d)),
            const SizedBox(height: 12),
            _datePicker('Date de rappel (optionnel)', _dateRappel,
                (d) => setState(() => _dateRappel = d)),
            const SizedBox(height: 12),

            _section('💊 Traitement'),
            // V2.5 — Sprint 3 : disposition verticale = saisie une main.
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _produitCtrl.text),
              optionsBuilder: (v) => CunicoleRef.medicaments.where(
                  (m) => m.toLowerCase().contains(v.text.toLowerCase())),
              onSelected: (v) => _produitCtrl.text = v,
              fieldViewBuilder: (_, ctrl, focus, onSubmit) => TextFormField(
                controller: ctrl,
                focusNode: focus,
                onEditingComplete: onSubmit,
                onChanged: (v) => _produitCtrl.text = v,
                decoration: const InputDecoration(
                    labelText: 'Produit utilisé',
                    prefixIcon: Icon(Icons.medication)),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _doseCtrl,
              decoration: const InputDecoration(
                  labelText: 'Dose', prefixIcon: Icon(Icons.colorize)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _vetoCtrl,
              decoration: const InputDecoration(
                  labelText: 'Vétérinaire', prefixIcon: Icon(Icons.person)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _coutCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: 'Coût (${AppTheme.devise})',
                  prefixIcon: const Icon(Icons.euro_symbol),
                  suffixText: AppTheme.devise),
              // Coût optionnel — si saisi, refuse négatif.
              validator: (v) => Validators.prix(v, requisField: false),
            ),
            const SizedBox(height: 12),

            // ── Délai d'attente médicament ──
            _section('⏱️ Délai d\'attente avant abattage / vente'),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'Pendant ce délai, le lapin ne peut pas être vendu pour la consommation '
                '(résidus de médicaments). Vérifiez la notice du produit utilisé — '
                'la valeur pré-remplie est indicative.',
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _delaiCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Délai d\'attente',
                helperText:
                    'Nombre de jours (laisser vide si non applicable, max 120 j).',
                prefixIcon: Icon(Icons.timer),
                suffixText: 'jours',
              ),
              // Bornes : 0-120 jours. Évite délai aberrant qui bloquerait
              // la vente du lapin à vie.
              validator: Validators.delaiAttenteJours,
              // V2.5 — Sprint 3 : reconstruit le bandeau "fin délai" en live.
              onChanged: (_) => setState(() {}),
            ),
            // V2.5 — Sprint 3 : bandeau auto fin du délai d'attente
            // (= date soin + délai). Évite le calcul mental à l'éleveur.
            if (_finDelaiAttente() != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: CuColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: CuColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_available,
                        size: 18, color: CuColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Vente possible à partir du ${_finDelaiAttente()}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: CuColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),

            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration:
                  const InputDecoration(labelText: 'Notes', prefixIcon: Icon(Icons.notes)),
            ),
            const SizedBox(height: 24),
            // V2.5 — Sprint 4 : CTA unifié via CuButton.
            CuButton(
              label: widget.soin != null ? 'Enregistrer' : 'Créer le soin',
              icon: widget.soin != null ? Icons.save : Icons.check,
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

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(t,
            style: TextStyle(fontWeight: FontWeight.bold, color: context.cuTextPrimary)),
      );

  /// V2.5 — Sprint 3 : calcule la date de fin du délai d'attente
  /// (date_soin + délai jours). Évite à l'éleveur de compter.
  /// Renvoie une string formatée (jj/mm/aaaa) ou null si invalide.
  String? _finDelaiAttente() {
    final delaiStr = _delaiCtrl.text.trim();
    if (delaiStr.isEmpty) return null;
    final delai = int.tryParse(delaiStr);
    if (delai == null || delai <= 0) return null;
    final ds = DateTime.tryParse(_dateSoin);
    if (ds == null) return null;
    final fin = ds.add(Duration(days: delai));
    return '${fin.day.toString().padLeft(2, '0')}/${fin.month.toString().padLeft(2, '0')}/${fin.year}';
  }

  Widget _datePicker(String label, String? value, Function(String) onPick) {
    final display = value != null ? formatDate(value) : 'Non définie';
    return InkWell(
      onTap: () async {
        final init = value != null ? DateTime.tryParse(value) ?? DateTime.now() : DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: init,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) onPick(picked.toIso8601String().substring(0, 10));
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.calendar_today)),
        child: Row(
          children: [
            Expanded(
                child: Text(display,
                    style: TextStyle(color: value != null ? Colors.black87 : Colors.grey))),
            if (value != null && label.contains('rappel'))
              GestureDetector(
                onTap: () => setState(() => _dateRappel = null),
                child: const Icon(Icons.clear, size: 16, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // V2.5 — UX Sprint 2 : vérifier que le lapin ciblé est éligible.
    // Le statut a pu changer (mort/vendu) depuis l'ouverture du form.
    if (!_toutElevage && _lapinId != null) {
      final lapin = widget.lapinsMap?[_lapinId];
      final erreur = BusinessRules.peutRecevoirSoin(lapin);
      if (erreur != null) {
        if (mounted) showErrorSnackBar(context, erreur);
        return;
      }
    }

    setState(() => _saving = true);

    final soin = Soin(
      id: widget.soin?.id,
      lapinId: _toutElevage ? null : _lapinId,
      typeSoin: _typeSoin,
      dateSoin: _dateSoin,
      dateRappel: _dateRappel,
      produit: _produitCtrl.text.trim().isEmpty ? null : _produitCtrl.text.trim(),
      dose: _doseCtrl.text.trim().isEmpty ? null : _doseCtrl.text.trim(),
      veterinaire: _vetoCtrl.text.trim().isEmpty ? null : _vetoCtrl.text.trim(),
      cout: _coutCtrl.text.isEmpty ? null : double.tryParse(_coutCtrl.text),
      delaiAttenteJours: _delaiCtrl.text.isEmpty ? null : int.tryParse(_delaiCtrl.text),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    try {
      final soinsRepo = await db.soins;
      if (widget.soin == null) {
        await soinsRepo.insertSoin(soin);
      } else {
        await soinsRepo.updateSoin(soin);
      }
      if (mounted) {
        _formCtrl.markClean();
        showSuccessSnackBar(context, 'Soin enregistré avec succès !');
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
