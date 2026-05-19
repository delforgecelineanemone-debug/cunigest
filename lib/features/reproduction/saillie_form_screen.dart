// ──────────────────────────────────────────────────────────────
// Écran : Formulaire Saillie (Ajout / Modification)
// ──────────────────────────────────────────────────────────────
// Permet d'enregistrer un accouplement entre une femelle et un mâle.
//
// Vérification automatique de consanguinité dès qu'un mâle ET une
// femelle sont sélectionnés (basée sur la généalogie pere_id/mere_id).
// L'éleveur peut passer outre l'avertissement mais est informé.
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/lot.dart';
import '../../models/saillie.dart';
import '../../models/lapin.dart';
import '../../services/id_generator_service.dart';
import '../../services/business_rules_service.dart';
import '../../utils/theme.dart';
import '../../utils/validators.dart';
import '../../widgets/common_widgets.dart';
import '../../ui/cu_ui.dart';

class SaillieFormScreen extends StatefulWidget {
  final Saillie? saillie;
  final Map<int, Lapin> lapinsMap;
  const SaillieFormScreen({super.key, this.saillie, required this.lapinsMap});

  @override
  State<SaillieFormScreen> createState() => _SaillieFormScreenState();
}

class _SaillieFormScreenState extends State<SaillieFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _formCtrl = CuFormController(); // V2.5 — Sprint 3 : anti-perte de saisie
  final db = DBHelper.instance;

  int? _mereId;
  int? _pereId;
  String _dateSaillie = DateTime.now().toIso8601String().substring(0, 10);
  String? _dateMiseBasPrevue;
  String? _dateMiseBasReelle;
  int? _nbNes;
  int? _nbVivants;
  int? _nbMorts;
  int? _nbSevres;
  String? _dateSevrage;
  double? _poidsSevrageTotal;
  String _statut = 'en_attente';
  bool _palpationPositive = false;
  // V2.5 — B5 : défaut intelligent (la pratique terrain est 2-3 montes réussies)
  int? _nbChevauchements = 2;
  final _etatNidCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  // Avertissement de consanguinité (null = pas vérifié, '' = pas de risque, autre = description)
  String? _consanguiniteWarning;
  bool _checkingConsanguinite = false;

  List<Lapin> get _femelles =>
      widget.lapinsMap.values.where((l) => l.sexe == 'femelle' && l.statut == 'actif').toList();
  List<Lapin> get _males =>
      widget.lapinsMap.values.where((l) => l.sexe == 'male' && l.statut == 'actif').toList();

  @override
  void initState() {
    super.initState();
    final s = widget.saillie;
    if (s != null) {
      _mereId = s.mereId;
      _pereId = s.pereId;
      _dateSaillie = s.dateSaillie;
      _dateMiseBasPrevue = s.dateMiseBasPrevue;
      _dateMiseBasReelle = s.dateMiseBasReelle;
      _nbNes = s.nbNes;
      _nbVivants = s.nbVivants;
      _nbMorts = s.nbMorts;
      _nbSevres = s.nbSevres;
      _dateSevrage = s.dateSevrage;
      _poidsSevrageTotal = s.poidsSevrageTotal;
      _statut = s.statut;
      _palpationPositive = s.palpationPositive;
      _nbChevauchements = s.nbChevauchements;
      _etatNidCtrl.text = s.etatNid ?? '';
      _notesCtrl.text = s.notes ?? '';
    }
    _verifierConsanguinite();
  }

  @override
  void dispose() {
    _etatNidCtrl.dispose();
    _notesCtrl.dispose();
    _formCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifierConsanguinite() async {
    if (_mereId == null || _pereId == null) {
      setState(() => _consanguiniteWarning = null);
      return;
    }
    setState(() => _checkingConsanguinite = true);
    final result = await db.verifierConsanguinite(_mereId!, _pereId!);
    if (mounted) {
      setState(() {
        _consanguiniteWarning = result;
        _checkingConsanguinite = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.saillie != null;
    return CuFormScaffold(
      controller: _formCtrl,
      appBar: CuAppBar(title: isEdit ? 'Modifier la saillie' : 'Nouvelle saillie', showActions: false),
      child: Form(
        key: _formKey,
        onChanged: _formCtrl.markDirty,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('👫 Reproducteurs'),
            DropdownButtonFormField<int>(
              initialValue: _mereId,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Mère (femelle) *',
                  prefixIcon: Icon(Icons.female, color: Colors.pink)),
              items: _femelles
                  .map((l) => DropdownMenuItem(
                      value: l.id,
                      child: Text('${l.displayName} (${l.numeroBague})',
                          overflow: TextOverflow.ellipsis)))
                  .toList(),
              validator: (v) => v == null ? 'Sélectionnez une mère' : null,
              onChanged: (v) {
                setState(() => _mereId = v);
                _verifierConsanguinite();
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _pereId,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Père (mâle) *',
                  prefixIcon: Icon(Icons.male, color: Colors.blue)),
              items: _males
                  .map((l) => DropdownMenuItem(
                      value: l.id,
                      child: Text('${l.displayName} (${l.numeroBague})',
                          overflow: TextOverflow.ellipsis)))
                  .toList(),
              validator: (v) => v == null ? 'Sélectionnez un père' : null,
              onChanged: (v) {
                setState(() => _pereId = v);
                _verifierConsanguinite();
              },
            ),

            // ── Avertissement de consanguinité ──
            if (_checkingConsanguinite)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              )
            else if (_consanguiniteWarning != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppTheme.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '⚠️ Consanguinité détectée',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                            ),
                            Text(
                              'Lien : $_consanguiniteWarning',
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'La consanguinité augmente le risque de tares et baisse la vigueur. À éviter sauf cas particulier.',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 12),

            _section('📅 Dates'),
            _datePicker('Date de saillie *', _dateSaillie, (d) {
              setState(() {
                _dateSaillie = d;
                final saillie = DateTime.parse(d);
                _dateMiseBasPrevue =
                    saillie.add(const Duration(days: 31)).toIso8601String().substring(0, 10);
              });
            }),
            const SizedBox(height: 12),
            _intField(
                'Nb chevauchements réussis (optionnel)',
                _nbChevauchements,
                (v) => _nbChevauchements = v),
            const SizedBox(height: 12),
            _datePicker('Mise bas prévue (auto: J+31)', _dateMiseBasPrevue,
                (d) => setState(() => _dateMiseBasPrevue = d)),
            const SizedBox(height: 12),

            _section('📊 Suivi'),
            DropdownButtonFormField<String>(
              initialValue: _statut,
              decoration:
                  const InputDecoration(labelText: 'Statut', prefixIcon: Icon(Icons.info)),
              items: const [
                DropdownMenuItem(value: 'en_attente', child: Text('⏳ En attente')),
                DropdownMenuItem(value: 'mise_bas', child: Text('🐣 Mise bas effectuée')),
                DropdownMenuItem(value: 'sevrage', child: Text('🍼 En sevrage')),
                DropdownMenuItem(value: 'termine', child: Text('✅ Terminé')),
                DropdownMenuItem(value: 'echec', child: Text('❌ Échec (non gestante)')),
              ],
              // V2.5 — UX Sprint 1 : NE PLUS auto-cocher la palpation.
              // Donnée vétérinaire = l'éleveur doit la confirmer lui-même
              // (ex: une mise bas peut survenir sans palpation préalable).
              onChanged: (v) => setState(() => _statut = v!),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Palpation positive (gestante)'),
              subtitle:
                  const Text('Cocher après palpation J+10 à J+14 si gestation confirmée'),
              value: _palpationPositive,
              onChanged: (v) => setState(() => _palpationPositive = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _etatNidCtrl,
              decoration: const InputDecoration(
                labelText: 'État du nid (J+28)',
                helperText:
                    'Ex : "Prêt, litière neuve", "Lapine s\'arrache les poils", "Manque copeaux"',
                helperMaxLines: 2,
                prefixIcon: Icon(Icons.home_outlined),
              ),
            ),

            if (_statut != 'en_attente' && _statut != 'echec') ...[
              const SizedBox(height: 12),
              _datePicker('Date de mise bas réelle', _dateMiseBasReelle, (d) {
                  setState(() {
                    _dateMiseBasReelle = d;
                    // Auto-calcul sevrage J+28
                    _dateSevrage ??= DateTime.parse(d)
                        .add(const Duration(days: 28))
                        .toIso8601String()
                        .substring(0, 10);
                  });
                }),
              const SizedBox(height: 12),
              // V2.5 — Sprint 3 : disposition verticale = saisie une main
              // sur mobile (3 champs en Row sont trop serrés au pouce).
              _intField('Nés total', _nbNes, (v) {
                setState(() {
                  _nbNes = v;
                  _recalcMorts();
                });
              }),
              const SizedBox(height: 12),
              _intField('Vivants', _nbVivants, (v) {
                setState(() {
                  _nbVivants = v;
                  _recalcMorts();
                });
              }, maxValue: _nbNes),
              const SizedBox(height: 12),
              _mortsField(),
            ],

            if (_statut == 'sevrage' || _statut == 'termine') ...[
              const SizedBox(height: 12),
              _datePicker('Date de sevrage (auto: J+28)', _dateSevrage,
                  (d) => setState(() => _dateSevrage = d)),
              const SizedBox(height: 12),
              _intField('Sevrés', _nbSevres, (v) => _nbSevres = v),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _poidsSevrageTotal?.toString() ?? '',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Poids total portée (kg)',
                    suffixText: 'kg',
                    helperText: 'Poids cumulé de tous les sevrés.',
                    helperMaxLines: 2),
                validator: Validators.poidsLot,
                onChanged: (v) =>
                    _poidsSevrageTotal = v.isEmpty ? null : double.tryParse(v.replaceAll(',', '.')),
              ),
            ],

            const SizedBox(height: 12),
            TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Notes', prefixIcon: Icon(Icons.notes))),

            // ── Bandeau confirmation rappels auto (V2.5 — Phase 3) ──
            if (_rappelsAutoLignes().isNotEmpty) ...[
              const SizedBox(height: 16),
              _bandeauRappelsAuto(),
            ],

            const SizedBox(height: 24),
            // V2.5 — Sprint 4 : CTA unifié via CuButton (design system).
            CuButton(
              label: isEdit ? 'Enregistrer' : 'Créer la saillie',
              icon: isEdit ? Icons.save : Icons.check,
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

  /// Liste les rappels auto qui seront programmés selon le statut courant.
  /// Vide si statut == 'echec' ou 'termine' (rien à programmer).
  List<String> _rappelsAutoLignes() {
    if (_statut == 'echec' || _statut == 'termine') return [];
    if (_statut == 'en_attente') {
      return const [
        '🤚 Palpation à J+10 à J+14 (vérifier la gestation)',
        '🏠 Pose du nid à J+27 à J+29',
        '🐣 Mise bas imminente à J+30 à J+33',
      ];
    }
    // mise_bas ou sevrage — calculs depuis la mise bas
    return const [
      '🩺 Contrôle mamelles à J+4 (mammite précoce)',
      '⚖️ Pesée lapereaux à J+7 (objectif > 80 g)',
      '🩺 Contrôle mamelles à J+10 et J+20',
      '🍼 Sevrage à J+21 puis J+28',
    ];
  }

  Widget _bandeauRappelsAuto() {
    final lignes = _rappelsAutoLignes();
    const violet = Color(0xFF7F77DD);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: violet.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: const Border(left: BorderSide(color: violet, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: violet, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rappels programmés automatiquement',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13, color: violet),
                ),
                const SizedBox(height: 6),
                for (final l in lignes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(l, style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(t,
          style: TextStyle(fontWeight: FontWeight.bold, color: context.cuTextPrimary)));

  Widget _datePicker(String label, String? value, Function(String) onPick) {
    return InkWell(
      onTap: () async {
        final init =
            value != null ? DateTime.tryParse(value) ?? DateTime.now() : DateTime.now();
        final picked = await showDatePicker(
            context: context,
            initialDate: init,
            firstDate: DateTime(2020),
            lastDate: DateTime(2035));
        if (picked != null) onPick(picked.toIso8601String().substring(0, 10));
      },
      child: InputDecorator(
        decoration: InputDecoration(
            labelText: label, prefixIcon: const Icon(Icons.calendar_today)),
        child: Text(value != null ? formatDate(value) : 'Sélectionner',
            style: TextStyle(color: value != null ? Colors.black87 : Colors.grey)),
      ),
    );
  }

  Widget _intField(
    String label,
    int? value,
    Function(int?) onChanged, {
    int? maxValue,
  }) {
    return TextFormField(
      initialValue: value?.toString() ?? '',
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      onChanged: (v) => onChanged(int.tryParse(v)),
      // V2.5 — UX Sprint 1 : bornes réalistes (0-30) + maxValue contextuelle
      // (ex: vivants <= nés). Évite saisies aberrantes type "999 nés".
      validator: (v) {
        final base = Validators.nombreLapinsPortee(v);
        if (base != null) return base;
        if (v != null && v.isNotEmpty && maxValue != null) {
          final n = int.tryParse(v);
          if (n != null && n > maxValue) return '≤ $maxValue';
        }
        return null;
      },
    );
  }

  /// Calcul auto morts-nés = nés − vivants (V2.5 — automatisation B1).
  void _recalcMorts() {
    if (_nbNes != null && _nbVivants != null) {
      final diff = _nbNes! - _nbVivants!;
      _nbMorts = diff >= 0 ? diff : 0;
    } else {
      _nbMorts = null;
    }
  }

  /// Champ morts-nés en lecture seule, alimenté automatiquement.
  Widget _mortsField() {
    final text = _nbMorts?.toString() ?? '—';
    return TextFormField(
      key: ValueKey('morts_${_nbMorts ?? ''}'),
      initialValue: text,
      enabled: false,
      decoration: const InputDecoration(
        labelText: 'Morts-nés',
        helperText: 'auto',
        helperMaxLines: 1,
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // V2.5 — UX Sprint 2 : règles métier vérifiées AVANT submit.
    // 1) Femelle pas déjà gestante (évite chevauchement de cycles).
    if (_mereId != null) {
      final erreurGestation = await BusinessRules.femelleDejaGestante(
        mereId: _mereId!,
        saillieIdEnEdition: widget.saillie?.id,
      );
      if (erreurGestation != null) {
        if (mounted) showErrorSnackBar(context, erreurGestation);
        return;
      }
    }
    // 2) Cohérence date mise bas réelle vs date saillie.
    final erreurDates = BusinessRules.miseBasCoherente(
      dateSaillieIso: _dateSaillie,
      dateMiseBasReelleIso: _dateMiseBasReelle,
    );
    if (erreurDates != null) {
      if (mounted) showErrorSnackBar(context, erreurDates);
      return;
    }
    // 3) Cohérence nés/vivants/morts (déjà couverte par Validators
    //    sur les champs eux-mêmes via _intField + maxValue).

    // Si consanguinité détectée, demander confirmation
    if (_consanguiniteWarning != null && widget.saillie == null) {
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('⚠️ Consanguinité détectée'),
          content: Text(
              'Lien : $_consanguiniteWarning\n\nVoulez-vous quand même enregistrer cette saillie ?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Enregistrer quand même'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _saving = true);
    var saillie = Saillie(
      id: widget.saillie?.id,
      mereId: _mereId!,
      pereId: _pereId!,
      dateSaillie: _dateSaillie,
      dateMiseBasPrevue: _dateMiseBasPrevue,
      dateMiseBasReelle: _dateMiseBasReelle,
      nbNes: _nbNes,
      nbVivants: _nbVivants,
      nbMorts: _nbMorts,
      nbSevres: _nbSevres,
      dateSevrage: _dateSevrage,
      poidsSevrageTotal: _poidsSevrageTotal,
      statut: _statut,
      palpationPositive: _palpationPositive,
      nbChevauchements: _nbChevauchements,
      etatNid: _etatNidCtrl.text.trim().isEmpty ? null : _etatNidCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      lotId: widget.saillie?.lotId,
    );

    try {
      int saillieId;
      if (widget.saillie == null) {
        saillieId = await db.insertSaillie(saillie);
      } else {
        saillieId = widget.saillie!.id!;
        await db.updateSaillie(saillie);
      }

      // ── V13 : auto-création du lot à la mise bas ──
      // Conditions : statut == mise_bas (ou plus) + nbVivants > 0 +
      // pas encore de lot lié à cette saillie.
      String? messageLot;
      final dejaLot = saillie.lotId != null;
      final mbStatuts = {'mise_bas', 'sevrage', 'termine'};
      if (!dejaLot &&
          mbStatuts.contains(_statut) &&
          (_nbVivants ?? 0) > 0 &&
          _dateMiseBasReelle != null) {
        final code = await IdGeneratorService.nextLotId();
        final mereNom =
            widget.lapinsMap[_mereId]?.displayName ?? 'mère';
        final lot = Lot(
          code: code,
          dateCreation: _dateMiseBasReelle!,
          nombreInitial: _nbVivants!,
          poidsInitial: _poidsSevrageTotal,
          notes: 'Lot auto-créé depuis la mise bas de $mereNom',
          saillieId: saillieId,
        );
        final lotsRepo = await db.lots;
        final lotId = await lotsRepo.insertLot(lot);

        // Lier la saillie au lot
        saillie = saillie.copyWith(lotId: lotId);
        await db.updateSaillie(saillie);
        messageLot = 'Lot $code créé automatiquement';
      }

      // Génère les alertes reproduction en arrière-plan (idempotent)
      db.genererAlertesReproduction().ignore();

      if (mounted) {
        _formCtrl.markClean();
        showSuccessSnackBar(
            context,
            messageLot != null
                ? 'Saillie enregistrée • $messageLot'
                : 'Saillie enregistrée !');
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
