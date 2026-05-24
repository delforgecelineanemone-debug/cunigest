// ──────────────────────────────────────────────────────────────
// Écran : Formulaire Lapin (V2.2 — Phase 2 cages + photos)
// ──────────────────────────────────────────────────────────────
// Permet de créer un nouveau lapin ou modifier un existant.
// Champs : photo (optionnelle), bague (UNIQUE), nom, sexe, race,
//          couleur, cage (FK → cages.id), poids, date de naissance,
//          statut, père, mère, notes.
//
// La sélection de père/mère permet la traçabilité généalogique
// et la détection automatique de consanguinité lors des saillies.
//
// Le sélecteur de cage est hiérarchique (bâtiment → clapier → cage)
// et indique la capacité disponible. Si la cage choisie est différente
// de l'ancienne (en édition), un mouvement est enregistré dans l'historique.
//
// Photo : optionnelle (jamais bloquante). Stockée dans le dossier app
// local (`/lapins/<timestamp>.jpg`).
// ──────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../services/business_rules_service.dart';
import '../../services/image_service.dart';
import '../../database/db_helper.dart';
import '../../models/batiment.dart';
import '../../models/cage.dart';
import '../../models/clapier.dart';
import '../../models/lapin.dart';
import '../../services/id_generator_service.dart';
import '../../utils/theme.dart';
import '../../utils/validators.dart';
import '../../widgets/common_widgets.dart';
import '../../ui/cu_ui.dart';
import '../../data/cunicole_reference.dart';

class LapinFormScreen extends StatefulWidget {
  final Lapin? lapin; // null = création, sinon = modification
  const LapinFormScreen({super.key, this.lapin});

  @override
  State<LapinFormScreen> createState() => _LapinFormScreenState();
}

class _LapinFormScreenState extends State<LapinFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _formCtrl = CuFormController(); // V2.5 — Sprint 3 : anti-perte de saisie
  final db = DBHelper.instance;

  late TextEditingController _bague;
  late TextEditingController _nom;
  late TextEditingController _race;
  late TextEditingController _couleur;
  late TextEditingController _poids;
  late TextEditingController _notes;
  late TextEditingController _prixAchat; // V2.5 — Phase 4 (optionnel)

  // V2.5 — UX Sprint 1 : sexe SANS défaut (choix explicite obligatoire).
  // En édition, hydraté depuis le lapin existant.
  String? _sexe;
  String _statut = 'actif';
  String? _dateNaissance;
  int? _pereId;
  int? _mereId;
  int? _cageId;
  String? _cageLabel; // libellé affiché ("Bât A • Clapier 1 • C4B1")
  String? _photoPath;
  String? _destination; // V14 — sortie de ferme
  String? _causeMortalite; // V16 — obligatoire si statut='mort'
  bool _saving = false;

  // V2.5 — P2.12 : formulaire en wizard 3 étapes pour réduire la
  // surcharge cognitive (avant : 13 champs sur une seule page scrollable).
  //   0 = Identité    1 = Généalogie    2 = Santé & sortie
  int _step = 0;
  static const int _nbSteps = 3;
  static const _stepTitres = ['Identité', 'Généalogie', 'Santé & sortie'];

  List<Lapin> _allLapins = [];
  bool _loadingParents = true;


  @override
  void initState() {
    super.initState();
    final l = widget.lapin;
    _bague = TextEditingController(text: l?.numeroBague ?? '');
    _nom = TextEditingController(text: l?.nom ?? '');
    _race = TextEditingController(text: l?.race ?? '');
    _couleur = TextEditingController(text: l?.couleur ?? '');
    _poids = TextEditingController(text: l?.poids?.toString() ?? '');
    _notes = TextEditingController(text: l?.notes ?? '');
    _prixAchat = TextEditingController(
        text: l?.prixAchat != null ? l!.prixAchat!.toStringAsFixed(2) : '');
    if (l != null) {
      _sexe = l.sexe;
      _statut = l.statut;
      _dateNaissance = l.dateNaissance;
      _pereId = l.pereId;
      _mereId = l.mereId;
      _cageId = l.cageId;
      _photoPath = l.photoPath;
      _destination = l.destination;
      _causeMortalite = l.causeMortalite;
    }
    _loadParents();
    _resolveCageLabel();
    if (widget.lapin == null) _genererBagueAuto();
  }

  Future<void> _genererBagueAuto() async {
    try {
      final id = await IdGeneratorService.nextLapinId();
      if (!mounted) return;
      // Ne pas écraser si l'éleveur a déjà tapé quelque chose
      if (_bague.text.trim().isEmpty) {
        setState(() => _bague.text = id);
      }
    } catch (_) {/* silencieux : l'éleveur peut saisir manuellement */}
  }

  Future<void> _regenererBague() async {
    try {
      final id = await IdGeneratorService.nextLapinId();
      if (!mounted) return;
      setState(() => _bague.text = id);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Génération impossible : $e');
    }
  }

  Future<void> _loadParents() async {
    final lapins = await (await db.lapins).getAllLapins();
    if (mounted) {
      setState(() {
        _allLapins = lapins;
        _loadingParents = false;
      });
    }
  }

  Future<void> _resolveCageLabel() async {
    if (_cageId == null) return;
    try {
      final repo = await db.cages;
      final c = await repo.getCageById(_cageId!);
      if (c == null) return;
      final cl = await repo.getClapierById(c.clapierId);
      final b = cl != null ? await repo.getBatimentById(cl.batimentId) : null;
      if (!mounted) return;
      setState(() {
        _cageLabel =
            '${b?.nom ?? "?"} • ${cl?.nom ?? "?"} • ${c.numero}';
      });
    } catch (_) {}
  }

  List<Lapin> get _peresPossibles => _allLapins.where((l) {
        if (l.id == widget.lapin?.id) return false;
        if (l.sexe != 'male') return false;
        if (_dateNaissance != null && l.dateNaissance != null) {
          final naissanceMoi = DateTime.tryParse(_dateNaissance!);
          final naissanceLui = DateTime.tryParse(l.dateNaissance!);
          if (naissanceMoi != null && naissanceLui != null) {
            if (!naissanceLui.isBefore(naissanceMoi)) return false;
          }
        }
        return true;
      }).toList();

  List<Lapin> get _meresPossibles => _allLapins.where((l) {
        if (l.id == widget.lapin?.id) return false;
        if (l.sexe != 'femelle') return false;
        if (_dateNaissance != null && l.dateNaissance != null) {
          final naissanceMoi = DateTime.tryParse(_dateNaissance!);
          final naissanceLui = DateTime.tryParse(l.dateNaissance!);
          if (naissanceMoi != null && naissanceLui != null) {
            if (!naissanceLui.isBefore(naissanceMoi)) return false;
          }
        }
        return true;
      }).toList();

  @override
  void dispose() {
    for (final c in [_bague, _nom, _race, _couleur, _poids, _notes, _prixAchat]) {
      c.dispose();
    }
    _formCtrl.dispose();
    super.dispose();
  }

  // ── Actions UI ──

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choisir depuis la galerie'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            if (_photoPath != null)
              ListTile(
                leading: const Icon(Icons.delete, color: CuColors.danger),
                title: const Text('Supprimer la photo',
                    style: TextStyle(color: CuColors.danger)),
                onTap: () {
                  Navigator.pop(context, null);
                  setState(() => _photoPath = null);
                },
              ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 85,
      );
      if (file == null) return;
      final newPath = await ImageService.savePhoto(file.path);
      if (!mounted) return;
      setState(() => _photoPath = newPath);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Photo : $e');
    }
  }

  Future<void> _pickCage() async {
    final result = await showModalBottomSheet<_CagePickResult?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CagePickerSheet(currentCageId: _cageId),
    );
    if (result == null || !mounted) return;
    setState(() {
      _cageId = result.cageId;
      _cageLabel = result.label;
    });
  }

  // ── Save ──

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // V2.5 — UX Sprint 2 : détection doublon bague AVANT submit.
    // Évite l'erreur DB tardive ; message clair côté utilisateur.
    final erreurBague = await BusinessRules.bagueDejaUtilisee(
      bague: _bague.text,
      lapinIdEnEdition: widget.lapin?.id,
    );
    if (erreurBague != null) {
      if (mounted) showErrorSnackBar(context, erreurBague);
      return;
    }

    setState(() => _saving = true);
    // V2.5 — P2.17 : overlay modal anti double-tap pendant la sauvegarde.
    _formCtrl.markSaving('Enregistrement du lapin…');

    final oldCageId = widget.lapin?.cageId;

    // Construire le lapin SANS toucher au cage_id (on le gère séparément)
    final lapin = Lapin(
      id: widget.lapin?.id,
      numeroBague: _bague.text.trim(),
      nom: _nom.text.trim().isEmpty ? null : _nom.text.trim(),
      // _sexe est garanti non-null ici car le validator FormField a passé.
      sexe: _sexe!,
      // V2.5 — Sprint 5 : normalisation Race/Couleur (anti-doublons "Blanc"/"blanc"/"BLANC").
      race: Validators.normaliserNom(_race.text),
      dateNaissance: _dateNaissance,
      poids: _poids.text.isEmpty ? null : double.tryParse(_poids.text),
      couleur: Validators.normaliserNom(_couleur.text),
      statut: _statut,
      cageId: widget.lapin == null ? _cageId : oldCageId, // création OK ; édition gérée ensuite
      cageLegacy: widget.lapin?.cageLegacy,
      photoPath: _photoPath,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      pereId: _pereId,
      mereId: _mereId,
      prixAchat: _prixAchat.text.trim().isEmpty
          ? null
          : double.tryParse(_prixAchat.text.replaceAll(',', '.')),
      destination: _destination,
      causeMortalite: _statut == 'mort' ? _causeMortalite : null,
    );

    try {
      int lapinId;
      final lapinsRepo = await db.lapins;
      if (widget.lapin == null) {
        lapinId = await lapinsRepo.insertLapin(lapin);
      } else {
        lapinId = widget.lapin!.id!;
        await lapinsRepo.updateLapin(lapin);
      }

      // Changement de cage en édition → enregistrer un mouvement
      if (widget.lapin != null && oldCageId != _cageId) {
        try {
          final cagesRepo = await db.cages;
          await cagesRepo.deplacerLapin(
            lapinId: lapinId,
            cageDestinationId: _cageId,
            motif: 'Édition fiche',
          );
        } catch (e) {
          // Ne bloque pas la sauvegarde du lapin si le déplacement échoue
          // (cage pleine etc) — affiche juste un avertissement.
          if (mounted) {
            showErrorSnackBar(context,
                'Lapin enregistré mais cage non changée : ${e.toString().replaceAll("Exception: ", "")}');
          }
        }
      }

      if (mounted) {
        _formCtrl.markClean(); // V2.5 — Sprint 3 : autorise le pop
        showSuccessSnackBar(
            context,
            widget.lapin == null
                ? 'Lapin créé avec succès !'
                : 'Lapin modifié avec succès !');
        Navigator.pop(context, true);
      }
    } on DatabaseException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        if (e.isUniqueConstraintError()) {
          showErrorSnackBar(
            context,
            'Le numéro de bague "${_bague.text.trim()}" existe déjà. Chaque bague doit être unique.',
          );
        } else {
          showErrorSnackBar(context, 'Erreur d\'enregistrement : ${e.toString()}');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showErrorSnackBar(context, 'Une erreur est survenue.');
      }
    } finally {
      // Toujours retirer l'overlay de sauvegarde — même si le widget est
      // unmounted ou si une exception non prévue remonte (markSaved est
      // idempotent et ne dépend pas du contexte Flutter).
      _formCtrl.markSaved();
    }
  }

  // ── Navigation wizard ──

  /// Valide l'étape courante avant d'autoriser le passage à la suivante.
  /// Étape 0 (Identité) : bague + sexe obligatoires.
  /// Étapes 1 et 2 : pas de champ bloquant pour avancer.
  bool _validerEtape(int step) {
    if (step == 0) {
      if (_bague.text.trim().isEmpty) {
        showErrorSnackBar(context, 'Le numéro de bague est obligatoire.');
        return false;
      }
      if (_sexe == null) {
        showErrorSnackBar(context, 'Choisis le sexe du lapin.');
        return false;
      }
    }
    return true;
  }

  void _suivant() {
    if (!_validerEtape(_step)) return;
    if (_step < _nbSteps - 1) {
      setState(() => _step++);
    } else {
      _save();
    }
  }

  void _precedent() {
    if (_step > 0) setState(() => _step--);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.lapin != null;
    return CuFormScaffold(
      controller: _formCtrl,
      appBar: CuAppBar(
        title: isEdit ? 'Modifier le lapin' : 'Nouveau lapin',
        showActions: false,
      ),
      child: Form(
        key: _formKey,
        // V2.5 — Sprint 3 : marque le form "dirty" dès la 1ère modif.
        onChanged: _formCtrl.markDirty,
        child: Column(
          children: [
            _buildStepIndicator(),
            Expanded(
              child: IndexedStack(
                index: _step,
                children: [
                  // ── Étape 0 : Identité ──
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Center(child: _buildPhotoSection()),
                      const SizedBox(height: 16),
                      ..._buildIdentificationSection(),
                      ..._buildCaracteristiquesSection(),
                      const SizedBox(height: 80),
                    ],
                  ),
                  // ── Étape 1 : Généalogie ──
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ..._buildGenealogieSection(),
                      const SizedBox(height: 80),
                    ],
                  ),
                  // ── Étape 2 : Santé & sortie ──
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (isEdit) ..._buildStatutSection(),
                      ..._buildAchatSection(),
                      ..._buildNotesSection(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ],
              ),
            ),
            _buildWizardNav(isEdit),
          ],
        ),
      ).responsive(),
    );
  }

  /// Barre de progression 3 segments + titre de l'étape courante.
  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Étape ${_step + 1}/$_nbSteps',
                  style: TextStyle(
                      fontSize: 12, color: context.cuTextSecondary)),
              const SizedBox(width: 8),
              Text(_stepTitres[_step],
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(_nbSteps, (i) {
              final atteint = i <= _step;
              return Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsets.only(right: i < _nbSteps - 1 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: atteint
                        ? CuColors.primary
                        : context.cuBorder,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// Barre de navigation bas d'écran : Précédent / Suivant / Enregistrer.
  Widget _buildWizardNav(bool isEdit) {
    final estDerniere = _step == _nbSteps - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: context.cuBorder)),
      ),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              child: CuButton(
                label: 'Précédent',
                icon: Icons.arrow_back,
                variant: CuButtonVariant.ghost,
                size: CuButtonSize.lg,
                onPressed: _saving ? null : _precedent,
              ),
            ),
          if (_step > 0) const SizedBox(width: 12),
          Expanded(
            flex: _step > 0 ? 1 : 2,
            child: CuButton(
              label: estDerniere
                  ? (isEdit ? 'Enregistrer' : 'Créer le lapin')
                  : 'Suivant',
              icon: estDerniere
                  ? (isEdit ? Icons.save : Icons.check)
                  : Icons.arrow_forward,
              variant: CuButtonVariant.primary,
              size: CuButtonSize.lg,
              fullWidth: true,
              loading: _saving,
              onPressed: _saving ? null : _suivant,
            ),
          ),
        ],
      ),
    );
  }

  // ── Sections du formulaire ──

  Widget _buildPhotoSection() {
    return Semantics(
      button: true,
      label: _photoPath != null
          ? 'Photo du lapin — appuyer pour changer'
          : 'Ajouter une photo du lapin',
      child: GestureDetector(
      onTap: _pickPhoto,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 130, height: 130,
            decoration: BoxDecoration(
              color: context.cuRaised, shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primary, width: 2),
              image: _photoPath != null && File(_photoPath!).existsSync()
                  ? DecorationImage(image: FileImage(File(_photoPath!)), fit: BoxFit.cover)
                  : null,
            ),
            child: _photoPath == null
                ? Icon(Icons.pets, color: context.cuTextSecondary, size: 60)
                : null,
          ),
          Container(
            decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
            padding: const EdgeInsets.all(8),
            child: Icon(_photoPath != null ? Icons.edit : Icons.add_a_photo,
                color: Colors.white, size: 18),
          ),
        ],
      ),
    ),
    );
  }

  List<Widget> _buildIdentificationSection() => [
    _sectionTitle('Identification'),
    TextFormField(
      controller: _bague,
      decoration: InputDecoration(
        labelText: 'Numéro de bague *',
        helperText: widget.lapin == null
            ? 'Auto-généré (modifiable). Touche 🔄 pour régénérer.'
            : 'Identifiant unique (tatouage)',
        helperMaxLines: 2,
        prefixIcon: const Icon(Icons.tag),
        suffixIcon: widget.lapin == null
            ? IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Régénérer un nouvel ID',
                onPressed: _regenererBague)
            : null,
      ),
      validator: (v) => v == null || v.trim().isEmpty ? 'Obligatoire' : null,
    ),
    const SizedBox(height: 12),
    TextFormField(
      controller: _nom,
      decoration: const InputDecoration(
          labelText: 'Nom (optionnel)', prefixIcon: Icon(Icons.badge)),
    ),
    const SizedBox(height: 12),
    // V2.5 — UX Sprint 1 : sexe = champ OBLIGATOIRE sans défaut.
    // Anti-corruption silencieuse : éviter qu'un mâle soit enregistré
    // par défaut "femelle" en cas de clic rapide.
    FormField<String>(
      initialValue: _sexe,
      validator: (v) => v == null ? 'Sexe obligatoire' : null,
      builder: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Sexe * :',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 16),
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'male',
                        label: Text('♂ Mâle'),
                        icon: Icon(Icons.male)),
                    ButtonSegment(
                        value: 'femelle',
                        label: Text('♀ Femelle'),
                        icon: Icon(Icons.female)),
                  ],
                  selected: _sexe == null ? <String>{} : {_sexe!},
                  emptySelectionAllowed: true,
                  onSelectionChanged: (s) {
                    setState(() => _sexe = s.isEmpty ? null : s.first);
                    state.didChange(_sexe);
                  },
                ),
              ),
            ],
          ),
          if (state.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 12),
              child: Text(
                state.errorText!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error, fontSize: 12),
              ),
            ),
        ],
      ),
    ),
    const SizedBox(height: 12),
    Autocomplete<String>(
      initialValue: TextEditingValue(text: _race.text),
      optionsBuilder: (v) => CunicoleRef.races.where((r) => r.toLowerCase().contains(v.text.toLowerCase())),
      onSelected: (v) => _race.text = v,
      fieldViewBuilder: (_, ctrl, focus, onSubmit) => TextFormField(
        controller: ctrl, focusNode: focus,
        onEditingComplete: onSubmit, onChanged: (v) => _race.text = v,
        decoration: const InputDecoration(labelText: 'Race', prefixIcon: Icon(Icons.category)),
      ),
    ),
    const SizedBox(height: 12),
  ];

  List<Widget> _buildCaracteristiquesSection() => [
    _sectionTitle('Caractéristiques'),
    Autocomplete<String>(
      initialValue: TextEditingValue(text: _couleur.text),
      optionsBuilder: (v) => CunicoleRef.couleurs.where((c) => c.toLowerCase().contains(v.text.toLowerCase())),
      onSelected: (v) => _couleur.text = v,
      fieldViewBuilder: (_, ctrl, focus, onSubmit) => TextFormField(
        controller: ctrl, focusNode: focus,
        onEditingComplete: onSubmit, onChanged: (v) => _couleur.text = v,
        decoration: const InputDecoration(labelText: 'Couleur', prefixIcon: Icon(Icons.palette)),
      ),
    ),
    const SizedBox(height: 12),
    TextFormField(
      controller: _poids,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
          labelText: 'Poids (kg)',
          prefixIcon: Icon(Icons.monitor_weight),
          suffixText: 'kg'),
      // Bornes : 10 g à 12 kg (race géante). Bloque négatifs et aberrations.
      validator: Validators.poidsLapin,
    ),
    const SizedBox(height: 12),
    InkWell(
      onTap: _pickCage,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Cage',
          prefixIcon: const Icon(Icons.grid_view),
          suffixIcon: _cageId == null
              ? const Icon(Icons.chevron_right)
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  tooltip: 'Retirer la cage',
                  onPressed: () => setState(() { _cageId = null; _cageLabel = null; }),
                ),
        ),
        child: Text(_cageLabel ?? 'Aucune cage assignée',
            style: TextStyle(
                color: _cageLabel != null
                    ? context.cuTextPrimary
                    : context.cuTextSecondary)),
      ),
    ),
    const SizedBox(height: 12),
    InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _dateNaissance != null
              ? DateTime.tryParse(_dateNaissance!) ?? DateTime.now()
              : DateTime.now(),
          firstDate: DateTime(2015), lastDate: DateTime.now(),
        );
        if (picked != null) {
          setState(() => _dateNaissance = picked.toIso8601String().substring(0, 10));
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date de naissance',
          prefixIcon: const Icon(Icons.cake),
          // V2.5 — Sprint 3 : âge auto-calculé sous le champ.
          helperText: _ageAutoCalcule(),
          helperMaxLines: 1,
        ),
        child: Text(
          _dateNaissance != null ? formatDate(_dateNaissance) : 'Sélectionner',
          style: TextStyle(
              color: _dateNaissance != null
                  ? context.cuTextPrimary
                  : context.cuTextSecondary),
        ),
      ),
    ),
    const SizedBox(height: 12),
  ];

  /// V2.5 — Sprint 3 : âge lisible (ex: "2 ans 3 mois", "45 jours").
  String? _ageAutoCalcule() {
    if (_dateNaissance == null) return null;
    final dn = DateTime.tryParse(_dateNaissance!);
    if (dn == null) return null;
    final now = DateTime.now();
    final jours = now.difference(dn).inDays;
    if (jours < 0) return null;
    if (jours < 60) return 'Âge : $jours jours';
    final mois = ((jours / 30.44).floor());
    if (mois < 12) return 'Âge : $mois mois';
    final ans = mois ~/ 12;
    final moisRest = mois % 12;
    return moisRest > 0
        ? 'Âge : $ans an${ans > 1 ? "s" : ""} $moisRest mois'
        : 'Âge : $ans an${ans > 1 ? "s" : ""}';
  }

  List<Widget> _buildGenealogieSection() => [
    _sectionTitle('Généalogie (optionnel)'),
    Text(
      'Renseigner les parents permet la détection automatique de consanguinité lors des saillies.',
      style: TextStyle(
          fontSize: 12,
          color: context.cuTextSecondary,
          fontStyle: FontStyle.italic),
    ),
    const SizedBox(height: 8),
    if (_loadingParents)
      const Padding(
          padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator())
    else ...[
      DropdownButtonFormField<int?>(
        initialValue: _pereId, isExpanded: true,
        decoration: const InputDecoration(
            labelText: 'Père (mâle)',
            prefixIcon: Icon(Icons.male, color: CuColors.sexeMale)),
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('— Inconnu —')),
          ..._peresPossibles.map((l) => DropdownMenuItem<int?>(
                value: l.id,
                child: Text('${l.displayName} (${l.numeroBague})',
                    overflow: TextOverflow.ellipsis))),
        ],
        onChanged: (v) => setState(() => _pereId = v),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<int?>(
        initialValue: _mereId, isExpanded: true,
        decoration: const InputDecoration(
            labelText: 'Mère (femelle)',
            prefixIcon: Icon(Icons.female, color: CuColors.sexeFemelle)),
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('— Inconnue —')),
          ..._meresPossibles.map((l) => DropdownMenuItem<int?>(
                value: l.id,
                child: Text('${l.displayName} (${l.numeroBague})',
                    overflow: TextOverflow.ellipsis))),
        ],
        onChanged: (v) => setState(() => _mereId = v),
      ),
    ],
    const SizedBox(height: 12),
  ];

  List<Widget> _buildStatutSection() => [
    _sectionTitle('Statut'),
    DropdownButtonFormField<String>(
      initialValue: _statut,
      decoration: const InputDecoration(labelText: 'Statut', prefixIcon: Icon(Icons.info)),
      items: const [
        DropdownMenuItem(value: 'actif', child: Text('Actif')),
        DropdownMenuItem(value: 'sevrage', child: Text('Sevrage')),
        DropdownMenuItem(value: 'quarantaine', child: Text('Quarantaine')),
        DropdownMenuItem(value: 'vendu', child: Text('Vendu')),
        DropdownMenuItem(value: 'mort', child: Text('Mort')),
      ],
      onChanged: (v) => setState(() {
        _statut = v!;
        // V2.5 — réinitialiser la cause si on quitte le statut "mort"
        if (_statut != 'mort') _causeMortalite = null;
      }),
    ),
    const SizedBox(height: 12),
    // V16 — cause de mortalité OBLIGATOIRE quand statut='mort'
    if (_statut == 'mort') ...[
      DropdownButtonFormField<String>(
        initialValue: _causeMortalite,
        decoration: const InputDecoration(
          labelText: 'Cause de mortalité *',
          prefixIcon: Icon(Icons.warning_amber, color: CuColors.danger),
          helperText: 'Donnée sanitaire essentielle pour vos statistiques',
          helperMaxLines: 2,
        ),
        validator: (v) =>
            (v == null || v.isEmpty) ? 'Cause obligatoire' : null,
        items: Lapin.causesMortalite.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: (v) => setState(() => _causeMortalite = v),
      ),
      const SizedBox(height: 12),
    ],
    _sectionTitle('Sortie de ferme (optionnel)'),
    DropdownButtonFormField<String?>(
      initialValue: _destination,
      decoration: const InputDecoration(
        labelText: 'Destination',
        helperText: 'À renseigner à J+90 (sortie de ferme) ou au sexage si reproducteur sélectionné',
        helperMaxLines: 2,
        prefixIcon: Icon(Icons.outbond),
      ),
      items: const [
        DropdownMenuItem<String?>(value: null, child: Text('— Aucune —')),
        DropdownMenuItem(value: 'vendu', child: Text('💰 Vendu')),
        DropdownMenuItem(value: 'consomme', child: Text('🍴 Auto-consommé')),
        DropdownMenuItem(value: 'reproducteur', child: Text('⭐ Reproducteur sélectionné')),
        DropdownMenuItem(value: 'autre', child: Text('📦 Autre')),
      ],
      onChanged: (v) => setState(() => _destination = v),
    ),
    const SizedBox(height: 12),
  ];

  List<Widget> _buildAchatSection() => [
    _sectionTitle('Achat (optionnel)'),
    TextFormField(
      controller: _prixAchat,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Prix d\'achat (${AppTheme.devise})',
        prefixIcon: const Icon(Icons.payments),
        helperText: 'À renseigner pour les reproducteurs achetés (sert au calcul de rentabilité).',
        helperMaxLines: 2,
      ),
      // Prix optionnel — mais si saisi, doit être > 0 (anti-erreur signe).
      validator: (v) => Validators.prix(v, requisField: false),
    ),
    const SizedBox(height: 12),
  ];

  List<Widget> _buildNotesSection() => [
    _sectionTitle('Notes'),
    TextFormField(
      controller: _notes, maxLines: 3,
      decoration: const InputDecoration(
          labelText: 'Notes libres', prefixIcon: Icon(Icons.notes)),
    ),
    const SizedBox(height: 24),
  ];


  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(title,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
              color: context.cuTextPrimary)),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Bottom-sheet : sélection hiérarchique d'une cage
// ──────────────────────────────────────────────────────────────

class _CagePickResult {
  final int cageId;
  final String label;
  _CagePickResult(this.cageId, this.label);
}

class _CagePickerSheet extends StatefulWidget {
  final int? currentCageId;
  const _CagePickerSheet({this.currentCageId});

  @override
  State<_CagePickerSheet> createState() => _CagePickerSheetState();
}

class _CagePickerSheetState extends State<_CagePickerSheet> {
  bool _loading = true;
  List<Batiment> _batiments = [];
  Map<int, List<Clapier>> _clapiersByBat = {};
  Map<int, List<Cage>> _cagesByClapier = {};
  Map<int, int> _occByCage = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = await DBHelper.instance.cages;
    final bs = await repo.getAllBatiments();
    final clapiersByBat = <int, List<Clapier>>{};
    final cagesByClapier = <int, List<Cage>>{};
    for (final b in bs) {
      if (b.id == null) continue;
      final cls = await repo.getClapiersByBatiment(b.id!);
      clapiersByBat[b.id!] = cls;
      for (final cl in cls) {
        if (cl.id == null) continue;
        cagesByClapier[cl.id!] = await repo.getCagesByClapier(cl.id!);
      }
    }
    final occ = await repo.countOccupantsByCage();
    if (!mounted) return;
    setState(() {
      _batiments = bs;
      _clapiersByBat = clapiersByBat;
      _cagesByClapier = cagesByClapier;
      _occByCage = occ;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, scroll) => Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.cuTextDisabled,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),
            const Text('Sélectionner une cage',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _batiments.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Aucune cage configurée.\nCréez d\'abord un bâtiment, un clapier et des cages depuis le module Cages.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: context.cuTextSecondary),
                            ),
                          ),
                        )
                      : ListView(
                          controller: scroll,
                          children: _batiments.map(_buildBatimentTile).toList(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatimentTile(Batiment b) {
    final clapiers = _clapiersByBat[b.id] ?? [];
    return ExpansionTile(
      initiallyExpanded: true,
      leading: const Icon(Icons.home_work, color: AppTheme.primary),
      title:
          Text(b.nom, style: const TextStyle(fontWeight: FontWeight.bold)),
      children: clapiers.map((cl) => _buildClapierTile(b, cl)).toList(),
    );
  }

  Widget _buildClapierTile(Batiment b, Clapier cl) {
    final cages = _cagesByClapier[cl.id] ?? [];
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.shelves, color: CuColors.accentTools, size: 20),
        title: Text(cl.nom, style: const TextStyle(fontSize: 14)),
        children: cages.map((cg) => _buildCageTile(b, cl, cg)).toList(),
      ),
    );
  }

  Widget _buildCageTile(Batiment b, Clapier cl, Cage cg) {
    final occ = _occByCage[cg.id] ?? 0;
    final cap = cg.capaciteMax;
    final pleine = occ >= cap && cg.id != widget.currentCageId;
    final isCurrent = cg.id == widget.currentCageId;
    final color = cageStatutColor(cg.statut);
    return ListTile(
      enabled: !pleine,
      leading: Icon(cageStatutIcon(cg.statut), color: color),
      title: Text(cg.numero,
          style: TextStyle(
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
      subtitle: Text('${cg.statutLabel} • $occ/$cap'),
      trailing: pleine
          ? const Icon(Icons.lock, color: CuColors.danger, size: 18)
          : (isCurrent
              ? const Icon(Icons.check_circle, color: CuColors.success)
              : const Icon(Icons.chevron_right)),
      onTap: pleine
          ? null
          : () => Navigator.pop(
              context,
              _CagePickResult(
                  cg.id!, '${b.nom} • ${cl.nom} • ${cg.numero}')),
    );
  }
}
