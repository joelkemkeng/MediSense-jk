#!/bin/bash

# Script d'installation automatique du service MediSense Pro
# Version finale avec détection automatique du chemin
# À exécuter avec : bash install_medisense_service.sh

set -e  # Arrêter le script en cas d'erreur

echo "🚀 Installation du service MediSense Pro..."
echo "⏱️  $(date)"
echo ""

# ============================================
# DÉTECTION AUTOMATIQUE DU RÉPERTOIRE PROJET
# ============================================

# Obtenir le répertoire absolu du script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"

echo "📁 Détection automatique du répertoire projet..."
echo "📂 Répertoire détecté: $PROJECT_DIR"

# Variables
SERVICE_NAME="medisense"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
USER_NAME="$(whoami)"
PYTHON_CMD=""

echo "👤 Utilisateur détecté: $USER_NAME"

# ============================================
# VÉRIFICATIONS PRÉALABLES
# ============================================

echo ""
echo "🔍 Vérifications préalables..."

# Vérifier si on est sur un système Linux avec systemd
if ! command -v systemctl &> /dev/null; then
    echo "❌ Erreur: systemctl non trouvé. Ce script nécessite systemd."
    exit 1
fi

# Vérifier les permissions sudo
if ! sudo -n true 2>/dev/null; then
    echo "🔐 Permissions administrateur requises..."
    if ! sudo -v; then
        echo "❌ Erreur: Permissions administrateur nécessaires pour installer le service."
        exit 1
    fi
fi

# Vérifier si le script principal existe
if [ ! -f "$PROJECT_DIR/mesure_server.py" ]; then
    echo "❌ Erreur: Le fichier mesure_server.py n'existe pas dans $PROJECT_DIR"
    echo "📋 Fichiers présents dans le répertoire:"
    ls -la "$PROJECT_DIR/"
    exit 1
fi

# Détecter la commande Python appropriée
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    # Vérifier que c'est Python 3
    PYTHON_VERSION=$(python --version 2>&1 | cut -d' ' -f2 | cut -d'.' -f1)
    if [ "$PYTHON_VERSION" = "3" ]; then
        PYTHON_CMD="python"
    else
        echo "❌ Erreur: Python 3 requis. Python 2 détecté."
        exit 1
    fi
else
    echo "❌ Erreur: Python 3 non trouvé. Veuillez installer Python 3."
    exit 1
fi

echo "🐍 Python détecté: $PYTHON_CMD ($(which $PYTHON_CMD))"

# Vérifier que Python peut importer les modules de base
if ! $PYTHON_CMD -c "import sys; sys.exit(0 if sys.version_info >= (3,6) else 1)" 2>/dev/null; then
    echo "❌ Erreur: Python 3.6+ requis."
    exit 1
fi

echo "✅ Toutes les vérifications sont passées!"

# ============================================
# INSTALLATION DES DÉPENDANCES
# ============================================

echo ""
echo "📦 Installation des dépendances Python..."

# Détecter pip
PIP_CMD=""
if command -v pip3 &> /dev/null; then
    PIP_CMD="pip3"
elif command -v pip &> /dev/null; then
    PIP_CMD="pip"
else
    echo "⚠️  pip non trouvé, tentative d'installation..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y python3-pip
        PIP_CMD="pip3"
    else
        echo "❌ Erreur: Impossible d'installer pip automatiquement."
        echo "📋 Installez manuellement: sudo apt-get install python3-pip"
        exit 1
    fi
fi

echo "📦 Outil pip détecté: $PIP_CMD"

# Installer les dépendances avec gestion d'erreur
echo "📦 Installation de pyserial et websockets..."
if ! $PIP_CMD install pyserial websockets --user --quiet; then
    echo "⚠️  Tentative d'installation système..."
    if ! sudo $PIP_CMD install pyserial websockets --quiet; then
        echo "❌ Erreur lors de l'installation des dépendances Python."
        echo "📋 Essayez manuellement: $PIP_CMD install pyserial websockets"
        exit 1
    fi
fi

echo "✅ Dépendances installées avec succès!"

# ============================================
# TEST DU SCRIPT PYTHON
# ============================================

echo ""
echo "🧪 Test du script Python..."

# Tester l'importation des modules
if ! $PYTHON_CMD -c "import serial, asyncio, websockets, threading, logging; print('✅ Modules OK')" 2>/dev/null; then
    echo "❌ Erreur: Impossible d'importer les modules Python requis."
    exit 1
fi

echo "✅ Script Python validé!"

# ============================================
# ARRÊT DU SERVICE EXISTANT (SI PRÉSENT)
# ============================================

if sudo systemctl is-active --quiet $SERVICE_NAME.service 2>/dev/null; then
    echo ""
    echo "⏹️  Arrêt du service existant..."
    sudo systemctl stop $SERVICE_NAME.service || true
fi

# ============================================
# CRÉATION DU SERVICE SYSTEMD
# ============================================

echo ""
echo "📝 Création du service systemd..."

# Créer le fichier de service avec protection contre les erreurs
sudo tee $SERVICE_FILE > /dev/null <<EOF
[Unit]
Description=MediSense Pro IoT Server
Documentation=https://github.com/medisense/medisense-pro
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
Type=simple
User=$USER_NAME
Group=$USER_NAME
WorkingDirectory=$PROJECT_DIR
ExecStart=$(which $PYTHON_CMD) $PROJECT_DIR/mesure_server.py
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=mixed
KillSignal=SIGTERM
TimeoutStopSec=30

# Redémarrage automatique
Restart=always
RestartSec=10

# Logs
StandardOutput=journal
StandardError=journal
SyslogIdentifier=medisense

# Variables d'environnement
Environment=PYTHONPATH=$PROJECT_DIR
Environment=PYTHONUNBUFFERED=1
Environment=PYTHONDONTWRITEBYTECODE=1

# Sécurité
NoNewPrivileges=true
PrivateTmp=true

# Timeout
TimeoutStartSec=60
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

# Vérifier que le fichier a été créé
if [ ! -f "$SERVICE_FILE" ]; then
    echo "❌ Erreur: Impossible de créer le fichier de service."
    exit 1
fi

# Donner les bonnes permissions
sudo chmod 644 $SERVICE_FILE
echo "✅ Fichier de service créé: $SERVICE_FILE"

# ============================================
# CONFIGURATION DU SERVICE
# ============================================

echo ""
echo "🔄 Configuration du service systemd..."

# Recharger systemd
if ! sudo systemctl daemon-reload; then
    echo "❌ Erreur lors du rechargement de systemd."
    exit 1
fi

# Activer le service pour démarrage automatique
echo "✅ Activation du démarrage automatique..."
if ! sudo systemctl enable $SERVICE_NAME.service; then
    echo "❌ Erreur lors de l'activation du service."
    exit 1
fi

# ============================================
# DÉMARRAGE DU SERVICE
# ============================================

echo ""
echo "🚀 Démarrage du service MediSense Pro..."

if ! sudo systemctl start $SERVICE_NAME.service; then
    echo "❌ Erreur lors du démarrage du service."
    echo "📋 Consultez les logs: sudo journalctl -u $SERVICE_NAME.service"
    exit 1
fi

# Attendre que le service démarre complètement
echo "⏳ Attente du démarrage complet (15 secondes)..."
sleep 15

# ============================================
# VÉRIFICATIONS FINALES
# ============================================

echo ""
echo "🔍 Vérifications finales..."

# Vérifier le statut du service
if sudo systemctl is-active --quiet $SERVICE_NAME.service; then
    echo "✅ Service actif et en cours d'exécution!"
    
    # Vérifier que le port WebSocket répond
    echo "🌐 Test de connectivité WebSocket..."
    if timeout 5 bash -c "</dev/tcp/127.0.0.1/8765" 2>/dev/null; then
        echo "✅ WebSocket accessible sur ws://127.0.0.1:8765"
    else
        echo "⚠️  WebSocket non accessible immédiatement (démarrage en cours...)"
    fi
    
    # Afficher les dernières lignes de log
    echo ""
    echo "📋 Dernières lignes de log:"
    sudo journalctl -u $SERVICE_NAME.service --no-pager -n 5
    
else
    echo "❌ Erreur: Le service n'est pas actif!"
    echo "📋 Statut du service:"
    sudo systemctl status $SERVICE_NAME.service --no-pager
    echo ""
    echo "📋 Dernières lignes de log d'erreur:"
    sudo journalctl -u $SERVICE_NAME.service --no-pager -n 10
    exit 1
fi

# ============================================
# CONFIGURATION DES PERMISSIONS (OPTIONNEL)
# ============================================

echo ""
echo "🔧 Configuration des permissions pour les ports série..."

# Ajouter l'utilisateur aux groupes nécessaires pour les ports série
if ! groups $USER_NAME | grep -q "dialout"; then
    echo "👥 Ajout au groupe dialout pour accès aux ports série..."
    sudo usermod -a -G dialout $USER_NAME
    echo "⚠️  Redémarrage recommandé pour appliquer les permissions de groupe."
fi

if ! groups $USER_NAME | grep -q "tty"; then
    echo "👥 Ajout au groupe tty..."
    sudo usermod -a -G tty $USER_NAME
fi

# ============================================
# RÉSUMÉ ET INSTRUCTIONS
# ============================================

echo ""
echo "🎉 ============================================="
echo "🎯 INSTALLATION TERMINÉE AVEC SUCCÈS!"
echo "============================================="
echo ""
echo "📊 Résumé de l'installation:"
echo "   📁 Répertoire projet: $PROJECT_DIR"
echo "   🐍 Python utilisé: $(which $PYTHON_CMD)"
echo "   👤 Utilisateur: $USER_NAME"
echo "   🔧 Service: $SERVICE_NAME.service"
echo "   🌐 WebSocket: ws://127.0.0.1:8765"
echo ""
echo "🎮 Commandes utiles:"
echo "   sudo systemctl status $SERVICE_NAME          # Voir le statut"
echo "   sudo journalctl -u $SERVICE_NAME -f          # Voir les logs en temps réel"
echo "   sudo systemctl restart $SERVICE_NAME         # Redémarrer le service"
echo "   sudo systemctl stop $SERVICE_NAME            # Arrêter le service"
echo "   sudo systemctl disable $SERVICE_NAME         # Désactiver le démarrage auto"
echo ""
echo "🚀 VOTRE RASPBERRY PI EST MAINTENANT CONFIGURÉ!"
echo "📱 Ouvrez simplement 'medical_iot_dashboard.html' dans votre navigateur"
echo "🔄 Le service se lancera automatiquement à chaque démarrage"
echo ""
echo "⚠️  Si vous avez été ajouté à de nouveaux groupes, redémarrez avec:"
echo "   sudo reboot"
echo ""
echo "🎊 Installation terminée le $(date) @Joel Kemkeng te felicite"
echo "============================================="