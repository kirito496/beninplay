# 🚀 Instructions d'installation BeninPlay

## Étape 1 — Copier les fichiers

Copie tout le contenu du dossier `lib/` dans :
```
C:\Users\GBETOHO\StudioProjects\beninplay\lib\
```

## Étape 2 — Remplacer pubspec.yaml

Copie `pubspec.yaml` dans :
```
C:\Users\GBETOHO\StudioProjects\beninplay\pubspec.yaml
```

## Étape 3 — Ouvrir PowerShell et exécuter

```powershell
cd C:\Users\GBETOHO\StudioProjects\beninplay

# Installer les dépendances
flutter pub get

# Lancer sur téléphone (TECNO KI5k branché)
flutter run
```

## Étape 4 — Code de test OTP

Pour tester la connexion sans vrai SMS :
- Téléphone : n'importe quel numéro à 8 chiffres
- Code OTP : **123456**

## Structure des écrans

```
LoginScreen → OtpScreen → HomeScreen
                              ├── VideoFeedScreen (Zone Normal)
                              ├── DiscoverScreen
                              ├── WalletScreen
                              ├── ProfileScreen
                              └── DarkGateScreen (+18)
                                    ├── KYC (photo CIP)
                                    ├── Paiement (MTN/Moov)
                                    └── VideoFeedScreen (Zone Dark)
```
