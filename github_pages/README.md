# CuniGest — Landing page

Site web statique pour l'application mobile **CuniGest** (gestion d'élevage cunicole).

## Structure

```
.
├── index.html              # Landing page principale
├── mockups/                # Maquettes V3.1 (iframes embarqués dans la landing)
│   ├── render.html         # Render unitaire d'un écran (param ?screen=…)
│   └── *.jsx               # Composants React des écrans
├── cunigest-privacy/       # Politique de confidentialité
├── assets/                 # Logos, icônes
└── .nojekyll               # Désactive le pré-traitement Jekyll GitHub Pages
```

## Déploiement GitHub Pages

1. Pousser ce dossier sur la branche `main` de votre repo GitHub
   ```bash
   git add .
   git commit -m "Landing page CuniGest"
   git push origin main
   ```
2. **Settings → Pages** → Source: *Deploy from a branch* → `main` / `/ (root)` → Save
3. Le site sera disponible à `https://<utilisateur>.github.io/<repo>/` en 1-2 minutes

### Domaine personnalisé (optionnel)
- Créer un fichier `CNAME` à la racine contenant votre domaine (`cunigest.com`)
- Configurer un enregistrement DNS `A` vers les IPs GitHub Pages
- Cocher *Enforce HTTPS* dans Settings → Pages

## Stack

- HTML5 sémantique + Tailwind CSS (via CDN — aucun build)
- Inter (corps) + Instrument Serif (accents éditoriaux)
- IntersectionObserver pour scroll-reveal
- Maquettes React + Babel transpilé côté client
- 100% statique, aucun backend requis

## Design system

Palette **V3 Field-Premium** (alignée sur `lib/ui/tokens/colors.dart`) :
- Primary jade `#0F8C66`
- Background paper `#FAF9F5`
- Ink `#1A1F1B`
- Accents par module : Repro `#7C5CDB`, Santé `#E24B4A`, Aliment `#D85A30`, Finance `#B47416`, Outils `#1565C0`
