


# 🏥 Guide Complet d'Installation MediSense Pro

**Version : 2.0 - Installation Automatique**  
**Dernière mise à jour : 26 juin 2026**


## Auteur

### Informations Personnelles
- **Nom complet** : KEMKENG NGOUZA KEDI JOEL
- **Nom court** : Joel Kemkeng
- **Entreprise** : HasDigit (@HasDigit)

### Contact
- **Email personnel** : kedikemkeng@gmail.com
- **Email professionnel** : kedikemkenh@hasdigit.com
- **Téléphone** : +33 7 51 54 27 74
- **Téléphone alternatif** : +237659403009

### Réseaux Sociaux
- **YouTube** : [HasDigit](https://youtube.com/@hasdigit)
- **LinkedIn** : [Joel Kemkeng](https://linkedin.com/in/joelkemkeng)


---

## 📋 Table des Matières

1. [Introduction](#-introduction)
2. [Matériel Requis](#-matériel-requis)
3. [Préparation du Raspberry Pi](#-préparation-du-raspberry-pi)
4. [Téléchargement et Installation](#-téléchargement-et-installation)
5. [Installation Automatique](#-installation-automatique)
6. [Utilisation du Système](#-utilisation-du-système)
7. [Dépannage](#-dépannage)
8. [Maintenance](#-maintenance)
9. [Support](#-support)

---

## 🎯 Introduction

**MediSense Pro** est un système de monitoring médical en temps réel qui collecte automatiquement :
- 📏 **Poids corporel** (balance connectée)
- 🌡️ **Température** (thermomètre digital)
- 📐 **Taille** (capteur ultrasonique)
- ✅ **Validation** (système de sécurité)

Ce guide vous accompagne **étape par étape** pour installer le système sur un Raspberry Pi, même si vous n'avez **aucune expérience technique**.

---

## 💻 Matériel Requis

### **Obligatoire :**
- 🖥️ **Raspberry Pi** (modèle 3, 4 ou plus récent)
- 💾 **Carte SD** (16 GB minimum, Classe 10 recommandée)
- ⚡ **Alimentation** pour Raspberry Pi (officielle recommandée)
- 🌐 **Connexion Internet** (WiFi ou Ethernet)
- 💻 **Ordinateur** avec lecteur de carte SD

### **Optionnel (pour capteurs réels) :**
- ⚖️ **Balance connectée** (port série USB)
- 🌡️ **Thermomètre digital** (port série USB)
- 📐 **Capteur ultrasonique** (Arduino/microcontrôleur)
- 🔌 **Câbles USB/série** pour connexions

---

## 🔧 Préparation du Raspberry Pi

### **Étape 1 : Installation du Système d'Exploitation**

#### **Option A : Raspberry Pi Imager (RECOMMANDÉE)**

1. **Télécharger Raspberry Pi Imager** :
   - Allez sur : https://www.raspberrypi.org/software/
   - Téléchargez et installez **Raspberry Pi Imager**

2. **Préparer la carte SD** :
   - Insérez votre carte SD dans votre ordinateur
   - Ouvrez **Raspberry Pi Imager**
   - Cliquez sur **"CHOOSE OS"**
   - Sélectionnez **"Raspberry Pi OS (32-bit)"** ou **"Raspberry Pi OS (64-bit)"**

3. **Configuration avancée** :
   - Cliquez sur l'icône **⚙️ (roue dentée)** en bas à droite
   - **Activez SSH** : Cochez "Enable SSH"
   - **Configurez WiFi** : Entrez votre nom de réseau et mot de passe
   - **Créez un utilisateur** : 
     - Nom d'utilisateur : `pi`
     - Mot de passe : (choisissez un mot de passe sécurisé)
   - Cliquez **"SAVE"**

4. **Installation** :
   - Sélectionnez votre carte SD
   - Cliquez **"WRITE"**
   - Attendez la fin de l'installation (10-20 minutes)

#### **Option B : Image Préconfigurée**

Si vous avez une image préconfigurée :
1. Utilisez **Win32DiskImager** (Windows) ou **dd** (Linux/Mac)
2. Gravez l'image sur la carte SD
3. Passez à l'étape suivante

### **Étape 2 : Premier Démarrage**

1. **Insérer la carte SD** dans le Raspberry Pi
2. **Connecter** l'alimentation
3. **Attendre 2-3 minutes** le premier démarrage
4. **Se connecter** :
   - **Écran + clavier** : Interface graphique directe
   - **SSH** : Depuis un autre ordinateur (voir section SSH ci-dessous)

#### **Connexion SSH (Optionnel)**

Si vous utilisez SSH depuis un autre ordinateur :

**Windows** :
```cmd
# Ouvrir l'invite de commande (Cmd)
ssh pi@adresse_ip_du_raspberry
```

**Mac/Linux** :
```bash
# Ouvrir le terminal
ssh pi@adresse_ip_du_raspberry
```

*Pour trouver l'adresse IP : vérifiez sur votre routeur ou utilisez un scanner réseau.*

### **Étape 3 : Mise à Jour du Système**

```bash
# Mettre à jour la liste des paquets
sudo apt update

# Mettre à jour le système
sudo apt upgrade -y

# Redémarrer (recommandé)
sudo reboot
```

*Attendez 5-10 minutes pour la mise à jour complète.*

---

## 📥 Téléchargement et Installation

### **Méthode 1 : Téléchargement GitHub (RECOMMANDÉE)**

#### **Étape 1 : Ouvrir le Terminal**
- **Interface graphique** : Menu → Accessoires → Terminal
- **SSH** : Vous êtes déjà dans le terminal

#### **Étape 2 : Télécharger le Projet**
```bash
# Aller dans le répertoire home
cd ~

# Télécharger le projet MediSense
git clone https://github.com/joelkemkeng/MediSense-jk.git

# Vérifier le téléchargement
ls -la MediSense-jk/
```

**Si git n'est pas installé :**
```bash
# Installer git
sudo apt install git -y

# Puis refaire la commande clone
git clone https://github.com/joelkemkeng/MediSense-jk.git
```

#### **Étape 3 : Vérifier les Fichiers**
```bash
# Entrer dans le dossier
cd MediSense-jk

# Lister tous les fichiers
ls -la

# Vous devriez voir :
# - mesure_server.py
# - medical_iot_dashboard.html
# - script-param2.js
# - install_medisense_service.sh
# - README.md
```

### **Méthode 2 : Téléchargement Manuel**

Si vous avez les fichiers sur une clé USB :

```bash
# Créer le dossier
mkdir ~/MediSense-jk
cd ~/MediSense-jk

# Copier depuis la clé USB (adapter le chemin)
cp /media/pi/USB_NAME/* .

# Vérifier
ls -la
```

---

## 🚀 Installation Automatique

### **Étape 1 : Préparer le Script d'Installation**

```bash
# Aller dans le dossier du projet
cd ~/MediSense-jk

# Vérifier que le script est présent
ls -la install_medisense_service.sh

# Rendre le script exécutable
chmod +x install_medisense_service.sh
```

### **Étape 2 : Lancer l'Installation Automatique**

```bash
# Exécuter le script d'installation
bash install_medisense_service.sh
```

**⏳ L'installation prend 2-5 minutes. Voici ce qui va se passer :**

1. **🔍 Vérifications** : Le script vérifie que tout est en ordre
2. **📦 Dépendances** : Installation automatique de Python et modules
3. **🧪 Tests** : Validation du code Python
4. **⚙️ Service** : Création du service automatique
5. **🚀 Démarrage** : Lancement immédiat du système
6. **✅ Validation** : Tests finaux de fonctionnement

### **Étape 3 : Vérifier l'Installation**

À la fin de l'installation, vous devriez voir :

```
🎉 =============================================
🎯 INSTALLATION TERMINÉE AVEC SUCCÈS!
=============================================

📊 Résumé de l'installation:
   📁 Répertoire projet: /home/pi/MediSense-jk
   🐍 Python utilisé: /usr/bin/python3
   👤 Utilisateur: pi
   🔧 Service: medisense.service
   🌐 WebSocket: ws://127.0.0.1:8765

🚀 VOTRE RASPBERRY PI EST MAINTENANT CONFIGURÉ!
```

### **Étape 4 : Redémarrage (Important)**

```bash
# Redémarrer pour appliquer toutes les configurations
sudo reboot
```

**Attendez 2-3 minutes que le Raspberry Pi redémarre complètement.**

---

## 🎮 Utilisation du Système

### **Étape 1 : Vérifier que le Service Fonctionne**

Après le redémarrage :

```bash
# Vérifier le statut du service
sudo systemctl status medisense

# Vous devriez voir "active (running)"
```

**Exemple de sortie correcte :**
```
● medisense.service - MediSense Pro IoT Server
   Loaded: loaded (/etc/systemd/system/medisense.service; enabled)
   Active: active (running) since [date]
   ...
```

### **Étape 2 : Ouvrir l'Interface Web**

#### **Option A : Depuis le Raspberry Pi (Interface Graphique)**

1. **Ouvrir le navigateur** (Chromium)
2. **Appuyer sur Ctrl + O** (ou Menu → Ouvrir un fichier)
3. **Naviguer vers** : `/home/pi/MediSense-jk/`
4. **Sélectionner** : `medical_iot_dashboard.html`
5. **Cliquer** : "Ouvrir"

#### **Option B : Depuis un Autre Ordinateur**

1. **Copier** le fichier `medical_iot_dashboard.html` sur votre ordinateur
2. **Modifier** dans `script-param2.js` :
   ```javascript
   // Remplacer cette ligne :
   const ipAddress = "127.0.0.1";
   // Par l'IP de votre Raspberry Pi :
   const ipAddress = "192.168.1.XXX";
   ```
3. **Ouvrir** le fichier HTML dans votre navigateur

#### **Option C : Serveur Web (Avancé)**

```bash
# Installer un serveur web simple
sudo apt install nginx -y

# Copier les fichiers web
sudo cp ~/MediSense-jk/medical_iot_dashboard.html /var/www/html/
sudo cp ~/MediSense-jk/script-param2.js /var/www/html/

# Accéder via : http://adresse_ip_raspberry
```

### **Étape 3 : Interface Utilisateur**

Une fois l'interface ouverte, vous verrez :

- **🟢 Statut de connexion** : "Connecté au serveur IoT"
- **📊 4 cartes de données** :
  - ⚖️ **Poids Corporel** (kg)
  - 🌡️ **Température** (°C)
  - 📐 **Taille** (m)
  - ✅ **Validation** (statut)

#### **Fonctionnalités Interactives :**

- **🖱️ Clic sur les cartes** : Mise à jour manuelle
- **🔄 Mise à jour automatique** : Toutes les 2 secondes
- **⌨️ Raccourcis clavier** :
  - `Ctrl + R` : Reconnexion WebSocket
  - `Ctrl + U` : Mise à jour manuelle

---

## 🔧 Dépannage

### **Problème 1 : Service Non Démarré**

**Symptômes :**
- Interface affiche "Déconnecté"
- Pas de données affichées

**Solutions :**

```bash
# Vérifier le statut
sudo systemctl status medisense

# Si inactif, redémarrer
sudo systemctl restart medisense

# Voir les logs d'erreur
sudo journalctl -u medisense -f
```

### **Problème 2 : Erreur d'Installation**

**Symptômes :**
- Script d'installation s'arrête avec une erreur
- Messages d'erreur Python

**Solutions :**

```bash
# Mise à jour forcée du système
sudo apt update && sudo apt upgrade -y

# Installation manuelle des dépendances
sudo apt install python3 python3-pip -y
pip3 install pyserial websockets

# Relancer l'installation
cd ~/MediSense-jk
bash install_medisense_service.sh
```

### **Problème 3 : Ports Série Non Accessibles**

**Symptômes :**
- Données en mode simulation uniquement
- Erreurs de permission sur /dev/ttyUSB

**Solutions :**

```bash
# Ajouter l'utilisateur aux bons groupes
sudo usermod -a -G dialout,tty pi

# Vérifier les ports série
ls -la /dev/ttyUSB* /dev/ttyACM*

# Redémarrer
sudo reboot
```

### **Problème 4 : Interface Web Ne Se Connecte Pas**

**Symptômes :**
- "Connexion WebSocket fermée"
- Statut rouge en permanence

**Solutions :**

```bash
# Vérifier que le port 8765 est ouvert
sudo netstat -tlnp | grep 8765

# Vérifier le firewall (si activé)
sudo ufw status

# Redémarrer le service
sudo systemctl restart medisense
```

### **Problème 5 : Erreurs de Permissions**

**Solutions :**

```bash
# Corriger les permissions du dossier
sudo chown -R pi:pi ~/MediSense-jk
chmod +x ~/MediSense-jk/install_medisense_service.sh

# Relancer l'installation
cd ~/MediSense-jk
bash install_medisense_service.sh
```

---

## 🛠️ Maintenance

### **Commandes Utiles**

```bash
# État du service
sudo systemctl status medisense

# Redémarrer le service
sudo systemctl restart medisense

# Voir les logs en temps réel
sudo journalctl -u medisense -f

# Voir les 50 dernières lignes de log
sudo journalctl -u medisense -n 50

# Arrêter le service
sudo systemctl stop medisense

# Démarrer le service
sudo systemctl start medisense

# Désactiver le démarrage automatique
sudo systemctl disable medisense
```

### **Surveillance du Système**

```bash
# Utilisation du CPU et mémoire
htop

# Espace disque
df -h

# Température du Raspberry Pi
vcgencmd measure_temp

# Processus Python en cours
ps aux | grep python
```

### **Mise à Jour du Code**

```bash
# Aller dans le dossier du projet
cd ~/MediSense-jk

# Sauvegarder les modifications locales (si nécessaire)
cp mesure_server.py mesure_server.py.backup

# Mettre à jour depuis GitHub
git pull origin main

# Redémarrer le service pour appliquer les changements
sudo systemctl restart medisense
```

### **Sauvegarde**

```bash
# Créer une sauvegarde complète
sudo tar -czf ~/medisense_backup_$(date +%Y%m%d).tar.gz ~/MediSense-jk /etc/systemd/system/medisense.service

# Sauvegarder seulement les logs
sudo journalctl -u medisense > ~/medisense_logs_$(date +%Y%m%d).txt
```

---

## 📊 Données et Logs

### **Fichiers de Log**

- **Service système** : `sudo journalctl -u medisense`
- **Log applicatif** : `~/MediSense-jk/medisense.log`
- **Logs système** : `/var/log/syslog`

### **Mode Simulation**

Si aucun capteur physique n'est connecté, le système fonctionne en **mode simulation** :
- 📊 **Données fictives** mais réalistes
- 🔄 **Mise à jour automatique**
- ✅ **Interface fonctionnelle** pour les tests

### **Capteurs Réels**

Pour connecter de vrais capteurs :
1. **Connecter** les dispositifs USB/série
2. **Vérifier** les ports : `ls /dev/ttyUSB* /dev/ttyACM*`
3. **Modifier** les ports dans `mesure_server.py` si nécessaire
4. **Redémarrer** le service

---

## 📞 Support

### **Logs pour Diagnostic**

En cas de problème, collectez ces informations :

```bash
# Informations système
uname -a
cat /etc/os-release

# Statut du service
sudo systemctl status medisense

# Logs récents
sudo journalctl -u medisense -n 100

# Ports série disponibles
ls -la /dev/tty*

# Processus Python
ps aux | grep python

# Utilisation réseau
sudo netstat -tlnp | grep 8765
```

### **Réinstallation Complète**

Si rien ne fonctionne :

```bash
# Arrêter et supprimer le service
sudo systemctl stop medisense
sudo systemctl disable medisense
sudo rm /etc/systemd/system/medisense.service
sudo systemctl daemon-reload

# Supprimer le dossier
rm -rf ~/MediSense-jk

# Recommencer l'installation depuis le début
# (voir section "Téléchargement et Installation")
```

### **Contacts**

- **📧 Email Support** : support@medisense.com
- **🐛 Issues GitHub** : https://github.com/joelkemkeng/MediSense-jk/issues
- **📖 Documentation** : https://docs.medisense.com

---

## ✅ Checklist de Vérification

### **Installation Réussie :**
- [ ] Raspberry Pi démarré et connecté
- [ ] Projet téléchargé dans `~/MediSense-jk`
- [ ] Script d'installation exécuté sans erreur
- [ ] Service `medisense` actif après redémarrage
- [ ] Interface web accessible et connectée
- [ ] Données affichées (simulation ou réelles)

### **Fonctionnement Normal :**
- [ ] Statut "Connecté au serveur IoT" affiché
- [ ] Cartes mises à jour toutes les 2 secondes
- [ ] Clic sur les cartes fonctionne
- [ ] Logs sans erreurs critiques
- [ ] Service redémarre automatiquement en cas de problème

---

## 🎉 Félicitations !

Votre système **MediSense Pro** est maintenant opérationnel ! 

🚀 **Le système se lance automatiquement** à chaque démarrage du Raspberry Pi  
📱 **Ouvrez simplement l'interface web** pour voir vos données en temps réel  
🔄 **Tout fonctionne en arrière-plan** sans intervention de votre part  

**Profitez de votre monitoring médical intelligent !** 🏥✨

---

*Guide rédigé avec ❤️ pour la communauté MediSense Pro*  
*Dernière mise à jour : Décembre 2024*