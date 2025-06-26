# Guide d'Installation et d'Utilisation - MediSense Pro

## Prérequis
- Python 3.x installé sur votre ordinateur
- Un navigateur web (Chrome, Firefox, Edge, etc.)

## Installation

1. **Récupération du projet**
   - Ouvrez un terminal (ou invite de commande)
   - Exécutez la commande :
   ```bash
   git clone https://github.com/joelkemkeng/MediSense-jk.git
   ```
   - Les fichiers se trouveront directement dans le dossier `MediSense-jk`
   - puis placez-vous dans le dossier projet :
   ```bash
   cd MediSense-jk
   ```

2. **Installation des dépendances Python**
   - Ouvrez un terminal (ou invite de commande)
   - Copiez et collez cette commande :
   ```bash
   pip install pyserial websockets
   ```
   - ou encore 
   ```bash
   pip3 install pyserial websockets
   ```

## Démarrage du système

### Étape 1 : Démarrer le serveur
1. Ouvrez un terminal (ou invite de commande)
2. Naviguez jusqu'au dossier `MediSense-jk`
3. Exécutez la commande :
   ```bash
   python mesure_server.py
   ```
4. Vous devriez voir des messages de log dans le terminal et un fichier `medisense.log` sera créé pour le suivi.
5. **IMPORTANT** : Gardez cette fenêtre ouverte tant que vous utilisez l'interface.
6. Si aucun capteur n'est connecté, le serveur démarre en mode simulation (données fictives).

### Étape 2 : Ouvrir l'interface
1. Ouvrez votre navigateur web
2. Appuyez sur `Ctrl + O` (ou `Cmd + O` sur Mac)
3. Naviguez jusqu'au dossier `MediSense-jk`
4. Sélectionnez `medical_iot_dashboard.html`
5. Cliquez sur "Ouvrir"

## Utilisation

- L'interface affichera automatiquement les données des capteurs (ou des données simulées si aucun capteur n'est branché)
- Les données se mettent à jour toutes les 2 secondes
- Vous pouvez cliquer sur chaque carte pour forcer une mise à jour
- Cliquez sur le statut de connexion pour tenter une reconnexion manuelle
- Raccourcis clavier :
  - `Ctrl+R` : Reconnexion WebSocket
  - `Ctrl+U` : Mise à jour manuelle de toutes les mesures

## En cas de problème

### Si l'interface ne se connecte pas :
1. Vérifiez que le serveur Python est bien en cours d'exécution (`mesure_server.py`)
2. Rafraîchissez la page du navigateur
3. Vérifiez que tous les fichiers sont dans le même dossier

### Si vous voyez "Déconnecté" :
1. Vérifiez que le serveur Python est toujours en cours d'exécution
2. Attendez quelques secondes, la reconnexion est automatique
3. Si le problème persiste, redémarrez le serveur Python

## Arrêt du système

1. Fermez la page du navigateur
2. Dans le terminal, appuyez sur `Ctrl + C` pour arrêter le serveur Python

## Support

Si vous rencontrez des problèmes :
1. Vérifiez que tous les fichiers sont présents
2. Assurez-vous que Python est correctement installé
3. Vérifiez que les ports série sont correctement connectés (si vous utilisez des capteurs réels)

## Structure des fichiers
```
MediSense-jk/
│
├── mesure_server.py           # Serveur Python principal (WebSocket)
├── medical_iot_dashboard.html # Interface utilisateur
└── script-param2.js           # Script de communication côté client
```

## Notes importantes
- Ne fermez pas le terminal tant que vous utilisez l'interface
- Gardez tous les fichiers dans le même dossier
- Assurez-vous que les capteurs sont correctement connectés avant de démarrer (sinon, le mode simulation sera activé)
- Un fichier `medisense.log` est généré pour le suivi et le débogage
- Après le clone, tous les fichiers se trouvent directement dans le dossier `MediSense-jk`

