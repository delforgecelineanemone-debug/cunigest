// ──────────────────────────────────────────────────────────────
// CsvService — Export CSV (V2.4 — Phase 4 — Outils)
// ──────────────────────────────────────────────────────────────
// Génère et partage des fichiers CSV pour :
//   • Lapins (cheptel complet)
//   • Ventes
//   • Soins / vaccinations
//   • Dépenses
// Pas de dépendance externe : encodage RFC 4180 maison.
// Partage via share_plus (Android intent chooser).
// ──────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/db_helper.dart';
import '../models/depense.dart';

/// Singleton exposant les 4 exports CSV de l'application.
class CsvService {
  CsvService._();
  static final CsvService instance = CsvService._();

  // ─────────────────────────────────────────────
  // API publique
  // ─────────────────────────────────────────────

  /// Exporte le cheptel complet.
  Future<void> exporterLapins(BuildContext context) async {
    final db = DBHelper.instance;
    final lapins = await db.getAllLapins();

    final rows = <List<String>>[
      [
        'ID', 'Bague', 'Nom', 'Sexe', 'Race', 'Statut',
        'Poids (kg)', 'Couleur', 'Date naissance', 'Date création',
        'Cage ID', 'Pere ID', 'Mere ID', 'Notes',
      ],
    ];
    for (final l in lapins) {
      rows.add([
        '${l.id ?? ""}', l.numeroBague, l.nom ?? '', l.sexe,
        l.race ?? '', l.statut,
        l.poids != null ? l.poids!.toStringAsFixed(3) : '',
        l.couleur ?? '', l.dateNaissance ?? '', l.dateCreation,
        '${l.cageId ?? ""}', '${l.pereId ?? ""}', '${l.mereId ?? ""}',
        l.notes ?? '',
      ]);
    }

    await _partager(rows, 'lapins');
  }

  /// Exporte toutes les ventes.
  Future<void> exporterVentes(BuildContext context) async {
    final db = DBHelper.instance;
    final ventes = await db.getAllVentes();
    final devise = await _devise();

    final rows = <List<String>>[
      [
        'ID', 'Lapin ID', 'Date vente', 'Type', 'Acheteur',
        'Prix ($devise)', 'Poids (kg)', 'Quantité', 'Notes',
      ],
    ];
    for (final v in ventes) {
      rows.add([
        '${v.id ?? ""}', '${v.lapinId ?? ""}', v.dateVente, v.typeVente,
        v.acheteur ?? '', v.prixVente.toStringAsFixed(2),
        v.poids != null ? v.poids!.toStringAsFixed(3) : '',
        '${v.quantite}', v.notes ?? '',
      ]);
    }

    await _partager(rows, 'ventes');
  }

  /// Exporte tous les soins / vaccinations.
  Future<void> exporterSoins(BuildContext context) async {
    final db = DBHelper.instance;
    final soins = await db.getAllSoins();
    final devise = await _devise();

    final rows = <List<String>>[
      [
        'ID', 'Lapin ID', 'Type soin', 'Date soin', 'Date rappel',
        'Produit', 'Dose', 'Vétérinaire',
        'Coût ($devise)', 'Délai attente (j)', 'Notes',
      ],
    ];
    for (final s in soins) {
      rows.add([
        '${s.id ?? ""}', '${s.lapinId ?? ""}', s.typeSoin, s.dateSoin,
        s.dateRappel ?? '', s.produit ?? '', s.dose ?? '',
        s.veterinaire ?? '',
        s.cout != null ? s.cout!.toStringAsFixed(2) : '',
        '${s.delaiAttenteJours ?? ""}', s.notes ?? '',
      ]);
    }

    await _partager(rows, 'soins');
  }

  /// Exporte toutes les dépenses.
  Future<void> exporterDepenses(BuildContext context) async {
    final repo = await DBHelper.instance.depenses;
    final depenses = await repo.getAll();
    final devise = await _devise();

    final rows = <List<String>>[
      [
        'ID', 'Date', 'Catégorie', 'Montant ($devise)',
        'Description', 'Notes',
      ],
    ];
    for (final d in depenses) {
      rows.add([
        '${d.id ?? ""}', d.dateDepense,
        depenseCategorieLabel(d.categorie),
        d.montant.toStringAsFixed(2),
        d.description ?? '', d.notes ?? '',
      ]);
    }

    await _partager(rows, 'depenses');
  }

  // ─────────────────────────────────────────────
  // Helpers privés
  // ─────────────────────────────────────────────

  Future<String> _devise() async {
    try {
      return (await DBHelper.instance.getReglages()).devise;
    } catch (_) {
      return '€';
    }
  }

  /// Encode une ligne CSV selon RFC 4180 (guillemets si nécessaire).
  String _encodeLigne(List<String> champs) {
    return champs.map((c) {
      final doit = c.contains(',') || c.contains('"') || c.contains('\n');
      if (doit) return '"${c.replaceAll('"', '""')}"';
      return c;
    }).join(',');
  }

  /// Construit le contenu CSV complet, avec BOM UTF-8 pour Excel.
  String _buildCsv(List<List<String>> rows) {
    const bom = '﻿'; // BOM UTF-8 → Excel reconnaît l'encodage
    final lignes = rows.map(_encodeLigne).join('\r\n');
    return '$bom$lignes\r\n';
  }

  /// Écrit le CSV dans un fichier temporaire et ouvre l'intent de partage.
  /// Share.shareXFiles n'a pas besoin du BuildContext — pas d'async-gap lint.
  Future<void> _partager(List<List<String>> rows, String nom) async {
    final contenu = _buildCsv(rows);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final fileName = 'cunigest_${nom}_$today.csv';

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(contenu, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'CuniGest — Export $nom ($today)',
    );
  }
}
