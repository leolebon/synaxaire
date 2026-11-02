# Synaxaire — calendrier orthodoxe (tradition grecque) pour iPhone et Android

Une application native par plateforme, chacune avec ses widgets :
- **iPhone** : SwiftUI, widgets pour l'écran d'accueil et l'écran verrouillé ;
- **Android** : Kotlin et Jetpack Compose, widgets Glance.

Les deux applications partagent les mêmes données : le synaxaire (`Shared/synaxaire.json`) et les traductions (`Shared/i18n.json`). Leurs moteurs liturgiques sont identiques et testés ligne à ligne.

## Ce que fait l'application

- **Six langues** : français (par défaut), anglais, grec, russe, roumain et arabe, avec affichage de droite à gauche pour l'arabe. La langue se choisit dans Réglages.
- **Aujourd'hui** :
  - les icônes de tous les saints du jour, côte à côte jusqu'à 3 saints, dans un bandeau qui défile lentement de droite à gauche au-delà ;
  - en touchant une icône, on ouvre la fiche du saint ;
  - puis la fête du jour, le jeûne avec les aliments permis et interdits, et la liste des saints ;
  - les vies des saints d'orthocal.info, traduites sur l'appareil.
- **Icônes** : c'est l'image principale de l'article Wikipédia du saint. L'article n'est retenu que s'il est identifié avec certitude (titre exact, page qui n'est pas une page d'homonymie, texte qui parle d'un saint). Sinon, un motif doré s'affiche : pas d'image plutôt qu'une image hors sujet. Les icônes ont une taille fixe et ne débordent plus sur la date.
- **Calendrier** : une vue par mois, avec la date de Pâques (« Pâques 2026 », et non plus « 2 026 »).
- **Carêmes** : toucher la bulle du haut fait défiler l'écran jusqu'au carême en cours ou au prochain, avec ses règles et recommandations dépliées.
- **Réglages** :
  - langue et calendrier (nouveau ou ancien) ;
  - traduction automatique ;
  - sources cliquables, qui s'ouvrent dans le navigateur par défaut.
- **Widgets** :
  - « Synaxaire » : petit, moyen et grand ;
  - « Saints du jour » : mosaïque d'icônes, moyenne ou grande ;
  - sur iPhone, des widgets pour l'écran verrouillé.

Le jeûne suit le Typikon de la Grande Église. Il est identique jour pour jour au calendrier de l'Archevêché grec-orthodoxe (goarch.org) sur 3 681 des 3 683 jours de 2025 à 2035.

---

## Mettre le projet sur GitHub (une seule fois)

1. Créez un compte gratuit sur <https://github.com>.
2. Cliquez sur **+** › **New repository**, nommez-le `synaxaire` et choisissez **Public** (les minutes de compilation sont alors illimitées).
3. Sur la page du dépôt, cliquez sur **uploading an existing file**. Décompressez `Synaxaire.zip`, ouvrez le dossier `OrthodoxCalendar`, puis **glissez tout son contenu**, y compris les dossiers `.github` et `android`. Cliquez sur **Commit changes**.
   > **Mise à jour d'un dépôt existant :** glissez de nouveau tout le contenu ; GitHub remplace les fichiers modifiés.
4. Ouvrez l'onglet **Actions**. Deux compilations démarrent toutes seules :
   - **Construire l'application iPhone (IPA)** : environ 10 minutes, artefact **Synaxaire-ipa** ;
   - **Construire l'application Android (APK)** : environ 8 minutes, artefact **Synaxaire-apk**.
5. Quand une compilation est verte ✅, cliquez dessus et téléchargez son artefact en bas de la page, dans **Artifacts**. Décompressez-le.

> Si une compilation est rouge ❌, téléchargez l'artefact **journal-compilation** (iPhone) ou **journal-compilation-android**, et envoyez-le-moi.

## Installer sur iPhone (depuis Windows, avec Sideloadly)

1. Installez **iTunes** et **iCloud** dans leurs versions « web », pas celles du Microsoft Store :
   - iTunes : <https://www.apple.com/itunes/download/win64>
   - iCloud : <https://updates.cdn-apple.com/2020/windows/001-39935-20200911-1A70AA56-F448-11EA-8CC0-99D41950005E/iCloudSetup.exe>
2. Installez **Sideloadly** : <https://sideloadly.io>.
3. Branchez l'iPhone en USB et touchez **Se fier à cet ordinateur**.
4. Glissez `Synaxaire.ipa` dans Sideloadly, saisissez votre identifiant Apple, puis cliquez sur **Start**.
5. Sur l'iPhone, activez **Réglages › Confidentialité et sécurité › Mode développeur**, puis redémarrez. Ensuite, dans **Réglages › Général › VPN et gestion de l'appareil**, faites confiance à votre identifiant.
6. Avec un identifiant Apple gratuit, il faut réinstaller l'app **tous les 7 jours** avec Sideloadly.

**Widgets iPhone :** touchez longuement l'écran d'accueil › **Modifier** › **Ajouter un widget**, puis cherchez « Synaxaire » ou « Saints du jour ». Pour changer la langue ou le calendrier d'un widget, touchez-le longuement › **Modifier le widget**.

## Installer sur Android

1. Copiez `Synaxaire.apk` sur le téléphone, par câble USB, Google Drive ou e-mail.
2. Ouvrez le fichier sur le téléphone. Android demande d'**autoriser l'installation d'applications inconnues** pour l'application qui ouvre le fichier (Fichiers, Chrome, Drive…) : acceptez.
3. Si Play Protect affiche un avertissement : **Plus de détails › Installer quand même**. L'app n'est pas sur le Play Store, d'où cet avertissement.
4. Les mises à jour s'installent par-dessus l'ancienne version, car le projet fournit toujours la même clé de signature.

**Widgets Android :** touchez longuement l'écran d'accueil › **Widgets** › **Synaxaire**. Agrandissez ou réduisez le widget : il passe du petit au grand format. « Saints du jour » affiche la mosaïque d'icônes. Les widgets suivent la langue et le calendrier choisis dans l'application.

---

## Pourquoi pas les images du compte Instagram apostle_icons ?

Instagram n'offre aucun accès public à ses images : il faut se connecter, et la récupération automatique est interdite par ses conditions d'utilisation. L'application utilise donc l'image principale de la page Wikipédia du saint, comme convenu.

## Organisation du code

| Dossier | Contenu |
|---|---|
| `Shared/` | Le moteur iPhone (Swift, sans interface) et les **données communes** : `synaxaire.json`, `i18n.json` |
| `SharedUI/`, `App/`, `Widget/` | L'interface iPhone, l'app et les widgets |
| `android/` | Le projet Android : `engine/` (le moteur, porté en Kotlin), `data/`, `ui/`, `widget/` |
| `Tests/` | Le test du jeûne contre le calendrier GOARCH 2025-2035 |

## Sources et licences

- **Ménologe :** projet orthocal (licence MIT), traduit en français.
- **Vies des saints :** API orthocal.info.
- **Icônes et biographies :** Wikipédia et Wikimedia Commons (CC BY-SA).
- **Jeûne :** Typikon, calendrier de l'Archevêché grec-orthodoxe. Les usages varient selon les paroisses : en cas de doute, suivez votre père spirituel.
