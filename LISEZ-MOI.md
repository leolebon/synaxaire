# Synaxaire — calendrier orthodoxe (tradition grecque) pour iPhone

Application iOS native (SwiftUI) avec widget pour l'écran d'accueil et l'écran verrouillé.

**Ce qu'elle affiche chaque jour**

- La fête du jour : les 12 grandes fêtes, le cycle de Pâques (Triode, Pentecostaire) et les dimanches des Pères des conciles. Elle suit le calendrier des 7 conciles œcuméniques.
- Les saints du jour : environ 1 560 commémorations sur 366 jours, traduites en français.
- L'icône du saint ou de la fête, avec sa biographie (Wikipédia, en français quand l'article existe).
- Les vies des saints du synaxaire grec (orthocal.info), traduites automatiquement en français sur iOS 18 et plus.
- Le jeûne du jour, avec les aliments permis et interdits (viande, laitages, œufs, poisson, huile, vin).
- Les carêmes de l'année (Grand Carême, Apôtres, Dormition, Nativité), les semaines sans jeûne et des recommandations pour chaque période.
- Le choix entre le **nouveau calendrier** et l'**ancien calendrier**, dans l'app comme dans le widget.

Les règles de jeûne suivent le Typikon de la Grande Église. Elles ont été comparées jour par jour au calendrier officiel de l'Archevêché grec-orthodoxe (goarch.org) : **3 681 jours identiques sur 3 683** entre décembre 2025 et décembre 2035.

---

## Installer l'app sur votre iPhone depuis Windows

Une app iPhone se compile normalement sur un Mac. Ici, c'est GitHub qui la compile gratuitement sur un Mac dans le cloud. Ensuite, Sideloadly l'installe sur l'iPhone depuis votre PC avec votre identifiant Apple.

### Étape 1 — Faire compiler l'app par GitHub (une seule fois, environ 10 minutes)

1. Créez un compte gratuit sur <https://github.com>.
2. Cliquez sur **+** › **New repository**. Donnez-lui un nom (par exemple `synaxaire`) et choisissez **Public**.
   > Un dépôt public dispose de minutes de compilation illimitées. Un dépôt privé fonctionne aussi : le quota gratuit permet une vingtaine de compilations par mois.
3. Sur la page du dépôt vide, cliquez sur **uploading an existing file**.
4. Décompressez `Synaxaire.zip` sur votre PC. Ouvrez le dossier `OrthodoxCalendar` et **glissez tout son contenu** dans la page GitHub, y compris le dossier `.github`. Cliquez ensuite sur **Commit changes**.
   > Si le dossier `.github` n'a pas été envoyé, allez dans l'onglet **Actions** › **set up a workflow yourself**. Collez-y le contenu du fichier `.github/workflows/build-ipa.yml` et validez.
5. Ouvrez l'onglet **Actions**. La compilation « Construire l'application (IPA) » démarre toute seule et dure 5 à 10 minutes.
6. Quand elle est verte ✅, cliquez dessus. En bas de la page, dans **Artifacts**, téléchargez **Synaxaire-ipa**. Décompressez le fichier téléchargé pour obtenir `Synaxaire.ipa`.

> Si la compilation est rouge ❌, téléchargez l'artefact **journal-compilation** et envoyez-le-moi : je corrigerai le code.

### Étape 2 — Installer sur l'iPhone avec Sideloadly (gratuit)

1. Sur le PC, installez **iTunes** et **iCloud** depuis le site d'Apple, et non depuis le Microsoft Store : Sideloadly a besoin des versions « web ».
   - iTunes (64 bits) : <https://www.apple.com/itunes/download/win64>
   - iCloud (version hors Microsoft Store) : <https://updates.cdn-apple.com/2020/windows/001-39935-20200911-1A70AA56-F448-11EA-8CC0-99D41950005E/iCloudSetup.exe>
   > Ces liens sont ceux recommandés par les guides d'AltStore et de Sideloadly. Si iTunes du Microsoft Store est déjà installé, désinstallez-le d'abord.
2. Installez **Sideloadly** : <https://sideloadly.io>.
3. Branchez l'iPhone en USB, déverrouillez-le et touchez **Se fier à cet ordinateur**.
4. Dans Sideloadly, glissez `Synaxaire.ipa`, saisissez votre **identifiant Apple**, puis cliquez sur **Start**. Le mot de passe est envoyé à Apple uniquement. Un identifiant secondaire est possible.
5. Sur l'iPhone :
   - **Réglages › Confidentialité et sécurité › Mode développeur** : activez-le, puis redémarrez l'iPhone (iOS 16 et plus).
   - **Réglages › Général › VPN et gestion de l'appareil** : touchez votre identifiant Apple, puis **Faire confiance**.
6. Ouvrez **Synaxaire**. 🎉

**À savoir :** avec un identifiant Apple gratuit, l'app doit être réinstallée **tous les 7 jours**. Il suffit de relancer Sideloadly ; ses options proposent aussi un rafraîchissement automatique par Wi-Fi. Avec un compte Apple Developer (99 €/an), l'app reste valable un an.

### Étape 3 — Ajouter le widget

1. Sur l'écran d'accueil, touchez longuement un espace vide › **Modifier** › **Ajouter un widget**.
2. Cherchez **Synaxaire**, puis choisissez **petit**, **moyen** ou **grand**.
3. Pour choisir le calendrier ou masquer l'icône, touchez longuement le widget › **Modifier le widget**.
4. Écran verrouillé : touchez-le longuement › **Personnaliser** › **Écran verrouillé** › ajoutez Synaxaire.

Le widget change de jour à minuit. L'icône est téléchargée une fois, puis conservée en mémoire.

---

## Si vous avez un Mac

Ouvrez `Synaxaire.xcodeproj` dans Xcode 16 ou plus récent. Choisissez votre équipe dans **Signing & Capabilities** pour les deux cibles, l'app et le widget. Branchez l'iPhone, puis lancez avec ▶︎.

## Organisation du code

| Dossier | Contenu |
|---|---|
| `Shared/` | Le moteur, sans interface : dates, Pâques, fêtes, règles de jeûne, synaxaire (`synaxaire.json`), services Wikipédia et orthocal.info |
| `SharedUI/` | Le thème (bordeaux, or, parchemin) et les composants communs à l'app et au widget |
| `App/` | Les écrans : Aujourd'hui, Calendrier, Carêmes, Réglages, fiche d'un saint, vie d'un saint |
| `Widget/` | Le widget WidgetKit : petit, moyen, grand, écran verrouillé |
| `Tests/` | Le test du moteur de jeûne contre le calendrier GOARCH 2025-2035 (exécuté à chaque compilation) |

## Sources et licences

- **Ménologe** : commémorations de la tradition grecque/antiochienne d'après le projet orthocal.info (licence MIT), traduites en français pour cette app.
- **Vies des saints** : API publique orthocal.info (tradition grecque), chargées à la demande.
- **Icônes et biographies** : Wikipédia et Wikimedia Commons (CC BY-SA). La recherche est automatique : pour les saints peu connus, l'article trouvé peut être celui d'un homonyme.
- **Jeûne** : le Typikon et le calendrier publié par l'Archevêché grec-orthodoxe d'Amérique. Les usages varient selon les paroisses : en cas de doute, suivez votre père spirituel.
