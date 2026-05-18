// ──────────────────────────────────────────────────────────────
// Écran : À propos (V2.5 — Phase 5)
// ──────────────────────────────────────────────────────────────
// Affiche :
//   - Version de l'app
//   - Description / mission
//   - Politique de confidentialité (inline)
//   - Licences open source (licence Flutter standard)
//   - Contact développeur
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/app_config.dart';
import '../../utils/theme.dart';
import '../../ui/cu_ui.dart';

const _kPrivacyUrl = 'https://titanddev-cmd.github.io/cunigest-privacy';

class AProposScreen extends StatelessWidget {
  const AProposScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CuAppBar(title: 'À propos', showActions: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Logo + nom + version ──────────────────────────
          Center(
            child: Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.pets,
                      size: 56, color: AppTheme.primary),
                ),
                const SizedBox(height: 12),
                const Text(
                  AppConfig.appName,
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version ${AppConfig.appVersion}',
                  style: TextStyle(
                      fontSize: 13, color: context.cuTextSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Gestion professionnelle d\'élevage cunicole',
                  style: TextStyle(
                      fontSize: 13, color: context.cuTextSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Mission ───────────────────────────────────────
          const _Section(
            titre: '🐇 Notre mission',
            contenu:
                'CuniGest aide les éleveurs cunicoles à gérer leur cheptel '
                'de façon professionnelle : suivi des lapins, reproduction, '
                'santé, alimentation, finances et bien plus — 100% offline, '
                'vos données restent sur votre téléphone.',
          ),

          // ── Politique de confidentialité ──────────────────
          const _Section(
            titre: '🔒 Politique de confidentialité',
            contenu:
                'CuniGest respecte votre vie privée :\n\n'
                '• Toutes vos données d\'élevage sont stockées localement '
                'sur votre appareil, chiffrées (AES-256).\n\n'
                '• Aucune donnée personnelle n\'est collectée ou transmise '
                'sans votre accord explicite.\n\n'
                '• La synchronisation cloud (Supabase) est optionnelle. '
                'Quand elle est activée, vos données sont transmises de '
                'façon chiffrée (TLS) vers votre propre espace cloud '
                'protégé par vos identifiants.\n\n'
                '• L\'application ne contient aucune publicité et ne '
                'partage aucune donnée avec des tiers.\n\n'
                '• Vous pouvez supprimer toutes vos données à tout moment '
                'en désinstallant l\'application ou en effectuant une '
                'réinitialisation depuis les réglages de votre appareil.',
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(_kPrivacyUrl),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Voir la politique complète en ligne'),
            ),
          ),

          // ── Droits et effacement ──────────────────────────
          const _Section(
            titre: '📋 Vos droits (RGPD)',
            contenu:
                '• Droit d\'accès : toutes vos données sont visibles '
                'directement dans l\'app.\n\n'
                '• Droit de suppression : désinstallez l\'app ou effacez '
                'les données dans les paramètres Android de l\'app.\n\n'
                '• Droit à la portabilité : utilisez la fonction "Export CSV" '
                'pour télécharger toutes vos données.\n\n'
                '• Droit de rectification : modifiez directement dans l\'app.',
          ),

          // ── Open source ───────────────────────────────────
          const _Section(
            titre: '📦 Licences open source',
            contenu:
                'CuniGest est construit avec Flutter et des packages open '
                'source. Consultez les licences complètes via le bouton '
                'ci-dessous.',
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: OutlinedButton.icon(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: AppConfig.appName,
                applicationVersion: AppConfig.appVersion,
                applicationLegalese:
                    '© ${DateTime.now().year} — Tous droits réservés',
              ),
              icon: const Icon(Icons.description_outlined),
              label: const Text('Voir les licences open source'),
            ),
          ),

          // ── Copyright ─────────────────────────────────────
          Center(
            child: Text(
              '© ${DateTime.now().year} ${AppConfig.appName}\n'
              'Fait avec ❤️ pour les éleveurs cunicoles',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 11, color: context.cuTextSecondary),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ).responsive(),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.titre, required this.contenu});
  final String titre;
  final String contenu;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titre,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Text(contenu,
                style: const TextStyle(fontSize: 13, height: 1.5)),
          ],
        ),
      ),
    );
  }
}
