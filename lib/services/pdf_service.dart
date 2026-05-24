// ──────────────────────────────────────────────────────────────
// Service : Export PDF (rapports)
// ──────────────────────────────────────────────────────────────
// Génère deux types de rapport :
// - RAPPORT MENSUEL : KPI du mois (saillies, naissances, ventes,
//   soins, charges)
// - BILAN ANNUEL : récap complet de l'année
//
// Le PDF est créé en mémoire puis :
// - prévisualisable (printing.layoutPdf)
// - partageable (Share.shareXFiles)
// - imprimable directement sur imprimante réseau
// ──────────────────────────────────────────────────────────────

import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../database/db_helper.dart';
import '../models/batiment.dart';
import '../models/cage.dart';
import '../models/clapier.dart';
import '../models/lapin.dart';
import '../utils/theme.dart';

class PdfService {
  static final PdfService instance = PdfService._();
  PdfService._();

  /// Génère le PDF du rapport mensuel
  Future<Uint8List> genererRapportMensuel(DateTime mois) async {
    final db = DBHelper.instance;
    final moisStr = '${mois.year}-${mois.month.toString().padLeft(2, '0')}';

    // ── Récupération des données ──
    final database = await db.database;

    final ventesRows = await database.rawQuery(
      'SELECT COUNT(*) as nb, COALESCE(SUM(prix_vente), 0) as ca FROM ventes WHERE date_vente LIKE ?',
      ['$moisStr%'],
    );
    final saillies = await database.rawQuery(
      'SELECT COUNT(*) as nb FROM saillies WHERE date_saillie LIKE ?',
      ['$moisStr%'],
    );
    final naissances = await database.rawQuery(
      'SELECT COUNT(*) as nb_portees, COALESCE(SUM(nb_vivants), 0) as nb_vivants, COALESCE(SUM(nb_morts), 0) as nb_morts FROM saillies WHERE date_mise_bas_reelle LIKE ?',
      ['$moisStr%'],
    );
    final soinsRows = await database.rawQuery(
      'SELECT COUNT(*) as nb, COALESCE(SUM(cout), 0) as cout FROM soins WHERE date_soin LIKE ?',
      ['$moisStr%'],
    );
    final stats = await (await db.lapins).getStatistiquesLapins();
    final repro = await (await db.saillies).getStatistiquesReproduction();

    // ── Construction du PDF ──
    final doc = pw.Document(
      title: 'Rapport CuniGest $moisStr',
      author: 'CuniGest',
    );

    final couleurPrimaire = PdfColor.fromInt(AppTheme.primary.toARGB32());
    final couleurAccent = PdfColor.fromInt(AppTheme.accent.toARGB32());

    final moisLabel = _moisFr(mois.month);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _header(couleurPrimaire, 'Rapport mensuel — $moisLabel ${mois.year}'),
        footer: (ctx) => _footer(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 12),

          // ── Bloc cheptel ──
          _section('🐇 Cheptel actuel', couleurPrimaire),
          _kpiTable([
            ['Total lapins enregistrés', '${stats['total']}'],
            ['Lapins actifs', '${stats['actifs']}'],
            ['Mâles actifs', '${stats['males']}'],
            ['Femelles actives', '${stats['femelles']}'],
          ]),
          pw.SizedBox(height: 16),

          // ── Bloc reproduction ──
          _section('❤️ Reproduction du mois', couleurPrimaire),
          _kpiTable([
            ['Saillies enregistrées', '${saillies.first['nb']}'],
            ['Mises bas du mois', '${naissances.first['nb_portees']}'],
            ['Lapereaux nés vivants', '${naissances.first['nb_vivants']}'],
            ['Morts-nés', '${naissances.first['nb_morts']}'],
          ]),
          pw.SizedBox(height: 16),

          // ── Bloc reproduction globale ──
          _section('📊 Indicateurs globaux', couleurPrimaire),
          _kpiTable([
            [
              'Taux de fertilité',
              repro['taux_fertilite_pct'] != null
                  ? '${(repro['taux_fertilite_pct'] as double).toStringAsFixed(1)} %'
                  : '—'
            ],
            [
              'Prolificité moyenne',
              repro['prolificite_moyenne'] != null
                  ? '${(repro['prolificite_moyenne'] as double).toStringAsFixed(1)} vivants/portée'
                  : '—'
            ],
            [
              'Mortalité pré-sevrage',
              repro['taux_mortalite_pre_sevrage_pct'] != null
                  ? '${(repro['taux_mortalite_pre_sevrage_pct'] as double).toStringAsFixed(1)} %'
                  : '—'
            ],
          ]),
          pw.SizedBox(height: 16),

          // ── Bloc santé ──
          _section('💉 Santé du mois', couleurPrimaire),
          _kpiTable([
            ['Soins enregistrés', '${soinsRows.first['nb']}'],
            [
              'Coût total des soins',
              '${(soinsRows.first['cout'] as num).toStringAsFixed(2)} €'
            ],
          ]),
          pw.SizedBox(height: 16),

          // ── Bloc finances ──
          _section('💰 Ventes du mois', couleurAccent),
          _kpiTable([
            ['Nombre de ventes', '${ventesRows.first['nb']}'],
            [
              'Chiffre d\'affaires',
              '${(ventesRows.first['ca'] as num).toStringAsFixed(2)} €'
            ],
            [
              'Coût des soins',
              '- ${(soinsRows.first['cout'] as num).toStringAsFixed(2)} €'
            ],
            [
              'Solde brut (CA - soins)',
              '${((ventesRows.first['ca'] as num) - (soinsRows.first['cout'] as num)).toStringAsFixed(2)} €'
            ],
          ]),
          pw.SizedBox(height: 24),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              'Le solde brut ne tient pas compte des charges fixes (aliment, énergie, '
              'amortissements). Pour un bilan complet, utilisez votre comptabilité.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  /// Génère le PDF du bilan annuel
  Future<Uint8List> genererBilanAnnuel(int annee) async {
    final db = DBHelper.instance;
    final database = await db.database;

    final ventesRows = await database.rawQuery(
      'SELECT COUNT(*) as nb, COALESCE(SUM(prix_vente), 0) as ca, COALESCE(SUM(poids), 0) as poids FROM ventes WHERE date_vente LIKE ?',
      ['$annee%'],
    );
    final naissances = await database.rawQuery(
      'SELECT COUNT(*) as nb_portees, COALESCE(SUM(nb_vivants), 0) as nb_vivants, COALESCE(SUM(nb_sevres), 0) as nb_sevres FROM saillies WHERE date_mise_bas_reelle LIKE ?',
      ['$annee%'],
    );
    final soinsRows = await database.rawQuery(
      'SELECT COUNT(*) as nb, COALESCE(SUM(cout), 0) as cout FROM soins WHERE date_soin LIKE ?',
      ['$annee%'],
    );
    final ventesParMois = await database.rawQuery(
      'SELECT substr(date_vente, 1, 7) as mois, COUNT(*) as nb, SUM(prix_vente) as ca '
      'FROM ventes WHERE date_vente LIKE ? GROUP BY mois ORDER BY mois',
      ['$annee%'],
    );

    final doc = pw.Document(title: 'Bilan annuel CuniGest $annee');
    final couleurPrimaire = PdfColor.fromInt(AppTheme.primary.toARGB32());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _header(couleurPrimaire, 'Bilan annuel $annee'),
        footer: (ctx) => _footer(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 12),
          _section('📊 Vue d\'ensemble', couleurPrimaire),
          _kpiTable([
            ['Mises bas dans l\'année', '${naissances.first['nb_portees']}'],
            ['Lapereaux nés vivants', '${naissances.first['nb_vivants']}'],
            ['Lapereaux sevrés', '${naissances.first['nb_sevres']}'],
            ['Ventes', '${ventesRows.first['nb']}'],
            ['CA total', '${(ventesRows.first['ca'] as num).toStringAsFixed(2)} €'],
            ['Poids vif vendu', '${(ventesRows.first['poids'] as num).toStringAsFixed(1)} kg'],
            ['Coût des soins', '${(soinsRows.first['cout'] as num).toStringAsFixed(2)} €'],
          ]),
          pw.SizedBox(height: 24),
          _section('📅 Détail mensuel', couleurPrimaire),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: couleurPrimaire),
            cellAlignment: pw.Alignment.centerLeft,
            headers: const ['Mois', 'Ventes', 'Chiffre d\'affaires'],
            data: ventesParMois.map((r) {
              final mois = r['mois']?.toString() ?? '';
              return [
                mois,
                '${r['nb']}',
                '${(r['ca'] as num? ?? 0).toStringAsFixed(2)} €',
              ];
            }).toList(),
          ),
        ],
      ),
    );

    return doc.save();
  }

  /// V2.2 — Génère un PDF d'étiquettes de cages avec QR (8 par page A4).
  /// Chaque étiquette : numéro de cage en gros, QR au milieu, bâtiment + clapier en bas.
  /// L'éleveur peut imprimer puis coller physiquement sur chaque cage.
  Future<Uint8List> genererCartesCagesPDF({
    required List<Cage> cages,
    required Map<int, Clapier> clapiersById,
    required Map<int, Batiment> batimentsById,
  }) async {
    final pdf = pw.Document();
    const couleur = PdfColor.fromInt(0xFF1D9E75);

    // 8 étiquettes par page : 2 colonnes × 4 lignes
    const cellesParPage = 8;
    final pages = (cages.length / cellesParPage).ceil();

    for (var page = 0; page < pages; page++) {
      final start = page * cellesParPage;
      final end = (start + cellesParPage).clamp(0, cages.length);
      final lot = cages.sublist(start, end);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (context) {
            return pw.GridView(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
              children: lot.map((cage) {
                final clapier = clapiersById[cage.clapierId];
                final batiment = clapier != null
                    ? batimentsById[clapier.batimentId]
                    : null;
                return _etiquetteCage(cage, clapier, batiment, couleur);
              }).toList(),
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  pw.Widget _etiquetteCage(
      Cage cage, Clapier? clapier, Batiment? batiment, PdfColor couleur) {
    return pw.Container(
      margin: const pw.EdgeInsets.all(6),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: couleur, width: 1.5),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text('CuniGest',
              style: pw.TextStyle(
                  fontSize: 9,
                  color: couleur,
                  fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(
            cage.numero,
            style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: couleur),
          ),
          pw.SizedBox(height: 6),
          if (cage.qrPayload() != null)
            pw.BarcodeWidget(
              data: cage.qrPayload()!,
              barcode: pw.Barcode.qrCode(),
              width: 90,
              height: 90,
              drawText: false,
            ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Capacité ${cage.capaciteMax} • ${cage.statutLabel}',
            style: const pw.TextStyle(fontSize: 8),
          ),
          if (batiment != null && clapier != null)
            pw.Text(
              '${batiment.nom} • ${clapier.nom}',
              style: const pw.TextStyle(fontSize: 8),
              textAlign: pw.TextAlign.center,
              maxLines: 2,
            ),
        ],
      ),
    );
  }

  /// Génère le pedigree PDF d'un lapin sur 4 générations (V2.4 — Phase 4).
  /// Construit récursivement l'arbre via DBHelper.getLapinById(pere/mere).
  Future<Uint8List> genererPedigreePDF(Lapin lapin) async {
    final lapinsRepo = await DBHelper.instance.lapins;
    const color = PdfColor.fromInt(0xFF1D9E75);

    // Charge récursivement les ancêtres jusqu'à 4 générations
    Future<_PedigreeNode> build(int? id, int depth) async {
      if (id == null || depth > 4) return _PedigreeNode(null);
      final l = await lapinsRepo.getLapinById(id);
      if (l == null) return _PedigreeNode(null);
      final pere = await build(l.pereId, depth + 1);
      final mere = await build(l.mereId, depth + 1);
      return _PedigreeNode(l, pere: pere, mere: mere);
    }

    final root = _PedigreeNode(
      lapin,
      pere: await build(lapin.pereId, 1),
      mere: await build(lapin.mereId, 1),
    );

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _header(color, 'Pedigree — ${lapin.displayName} (4 générations)'),
            pw.SizedBox(height: 12),
            pw.Expanded(child: _pedigreeColumns(root)),
            pw.SizedBox(height: 8),
            _footer(ctx),
          ],
        ),
      ),
    );
    return doc.save();
  }

  /// Construit l'affichage en 5 colonnes (sujet + 4 générations).
  pw.Widget _pedigreeColumns(_PedigreeNode root) {
    // Aplatissement par niveau (16 cases en gen 4, 8 en gen 3, 4 en 2, 2 en 1, 1 racine)
    List<_PedigreeNode> level(_PedigreeNode n, int depth) {
      if (depth == 0) return [n];
      final prev = level(n, depth - 1);
      return [
        for (final p in prev) ...[
          p.pere ?? _PedigreeNode(null),
          p.mere ?? _PedigreeNode(null),
        ],
      ];
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: List.generate(5, (col) {
        final nodes = level(root, col);
        return pw.Expanded(
          child: pw.Column(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Text(
                  col == 0 ? 'Sujet' : 'Gén. $col',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700),
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                  children: nodes.map(_pedigreeCell).toList(),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  pw.Widget _pedigreeCell(_PedigreeNode n) {
    final l = n.lapin;
    final isMale = l?.sexe == 'male';
    final bg = l == null
        ? PdfColors.grey200
        : isMale
            ? const PdfColor.fromInt(0xFFE3F2FD)
            : const PdfColor.fromInt(0xFFFCE4EC);
    final border = l == null
        ? PdfColors.grey400
        : isMale
            ? const PdfColor.fromInt(0xFF1976D2)
            : const PdfColor.fromInt(0xFFC2185B);

    return pw.Container(
      margin: const pw.EdgeInsets.all(2),
      padding: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(
        color: bg,
        border: pw.Border.all(color: border, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: l == null
            ? [
                pw.Text('—',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey500))
              ]
            : [
                pw.Text(
                  '${isMale ? '♂' : '♀'} ${l.numeroBague}',
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold),
                  maxLines: 1,
                ),
                if (l.nom != null && l.nom!.isNotEmpty)
                  pw.Text(l.nom!,
                      style: const pw.TextStyle(fontSize: 7),
                      maxLines: 1),
                if (l.race != null && l.race!.isNotEmpty)
                  pw.Text(l.race!,
                      style: const pw.TextStyle(
                          fontSize: 6, color: PdfColors.grey700),
                      maxLines: 1),
              ],
      ),
    );
  }

  /// Affiche le preview PDF (impression possible depuis le viewer)
  Future<void> previsualiser(Uint8List bytes, {String? title}) async {
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: title ?? 'CuniGest',
    );
  }

  /// Sauvegarde le PDF dans Documents/cunigest_reports/ et propose le partage
  Future<String> sauvegarderEtPartager(Uint8List bytes, String nomFichier) async {
    final dir = await getApplicationDocumentsDirectory();
    final reportsDir = Directory(p.join(dir.path, 'cunigest_reports'));
    if (!await reportsDir.exists()) await reportsDir.create(recursive: true);
    final file = File(p.join(reportsDir.path, nomFichier));
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)],
        subject: 'Rapport CuniGest', text: nomFichier);
    return file.path;
  }

  // ── Helpers PDF ──

  pw.Widget _header(PdfColor color, String titre) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: color, width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('CuniGest',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold, color: color)),
              pw.Text(titre,
                  style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            ],
          ),
          pw.Text('🐇', style: const pw.TextStyle(fontSize: 24)),
        ],
      ),
    );
  }

  pw.Widget _footer(pw.Context ctx) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Text(
        'Page ${ctx.pageNumber} / ${ctx.pagesCount} — Généré le ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
      ),
    );
  }

  pw.Widget _section(String titre, PdfColor color) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 8),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: PdfColor(color.red, color.green, color.blue, 0.1),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(titre,
          style: pw.TextStyle(
              fontSize: 13, fontWeight: pw.FontWeight.bold, color: color)),
    );
  }

  pw.Widget _kpiTable(List<List<String>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(1),
      },
      children: rows
          .map((r) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(r[0], style: const pw.TextStyle(fontSize: 11)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(r[1],
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ))
          .toList(),
    );
  }

  String _moisFr(int m) {
    const moisFr = [
      '',
      'Janvier',
      'Février',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Août',
      'Septembre',
      'Octobre',
      'Novembre',
      'Décembre'
    ];
    return moisFr[m];
  }
}

/// Nœud d'un arbre généalogique (V2.4 — pedigree PDF).
class _PedigreeNode {
  final Lapin? lapin;
  final _PedigreeNode? pere;
  final _PedigreeNode? mere;
  _PedigreeNode(this.lapin, {this.pere, this.mere});
}
