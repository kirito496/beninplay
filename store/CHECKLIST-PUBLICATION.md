# Checklist de publication — BeninPlay sur Google Play

## A. Avant de commencer
- [ ] Compte **Google Play Console** créé (frais unique de 25 $ US, à vie).
- [ ] Nom de package **définitif** : `bj.beninplay.app` (⚠️ non modifiable après publication).
- [ ] Logo/icône 512×512 prête.

## B. Signer l'application (obligatoire)
- [ ] Générer une clé de signature (keystore) :
  ```
  keytool -genkey -v -keystore beninplay.keystore -alias beninplay \
    -keyalg RSA -keysize 2048 -validity 10000
  ```
- [ ] ⚠️ **Sauvegarder ce keystore + le mot de passe** dans un endroit sûr.
      Si tu le perds, tu ne pourras **plus jamais** mettre à jour l'appli.
- [ ] Configurer la signature dans `android/app/build.gradle` (bloc `signingConfigs`).

## C. Construire le fichier à envoyer
- [ ] `flutter pub get`
- [ ] `flutter build appbundle --release`  → produit un `.aab` (format exigé par Google).
- [ ] Le fichier est dans `build/app/outputs/bundle/release/app-release.aab`.

## D. Dans la Play Console
- [ ] Créer l'application → remplir la **fiche du store** (voir `google-play-listing.md`).
- [ ] Héberger la **politique de confidentialité** (`privacy-policy.html`) et coller l'URL.
- [ ] Remplir le **questionnaire sur la sécurité des données** (Data safety) :
      déclarer la collecte de compte, contenu, localisation, paiements, push.
- [ ] Remplir la **classification du contenu** (questionnaire IARC).
- [ ] Déclarer l'**audience cible** (13 ans et +).
- [ ] Envoyer le `.aab` sur une piste **Test interne** d'abord (recommandé), puis **Production**.

## E. Points de conformité à ne pas oublier
- [ ] L'appli manipule de l'**argent réel** → prépare des **conditions d'utilisation**
      claires (gains, retraits Mobile Money, règles des défis).
- [ ] **Modération** : un moyen de signaler un contenu et de bloquer un utilisateur
      (exigé pour les apps sociales).
- [ ] Vérifier que la **caméra**, le **micro** et la **localisation** ne sont demandés
      qu'au moment utile (déjà le cas dans le code).

## F. Après publication
- [ ] La première revue Google prend en général de quelques heures à 3 jours.
- [ ] Prévois `FCM_SERVICE_ACCOUNT` sur Azure pour activer les notifications push.
