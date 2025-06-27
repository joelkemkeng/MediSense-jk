#!/bin/bash

# Script d'analyse des positions physiques USB - Raspberry Pi
# Analyse UNIQUEMENT les positions sans identifier les capteurs
# Auteur: MediSense Team
# Usage: bash usb_positions.sh

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Fonction d'affichage avec style
print_header() {
    echo -e "${BOLD}${BLUE}$1${NC}"
    echo -e "${BLUE}$(printf '=%.0s' {1..70})${NC}"
}

print_section() {
    echo -e "\n${BOLD}${CYAN}$1${NC}"
    echo -e "${CYAN}$(printf '-%.0s' {1..50})${NC}"
}

print_info() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_detail() {
    echo -e "${WHITE}   📋 $1${NC}"
}

print_position() {
    echo -e "${BOLD}${PURPLE}   🎯 $1${NC}"
}

# Début du script
clear
print_header "🔍 ANALYSEUR DES POSITIONS PHYSIQUES USB - RASPBERRY PI"
echo -e "${BOLD}${WHITE}Date: $(date)${NC}"
echo -e "${BOLD}${WHITE}Système: $(uname -a | cut -d' ' -f1-3)${NC}"
echo -e "${BOLD}${WHITE}Objectif: Identifier les positions physiques uniques des ports USB${NC}"
echo ""

# Vérification que les ports existent
USB_PORTS=($(ls /dev/ttyUSB* 2>/dev/null | sort))
ACM_PORTS=($(ls /dev/ttyACM* 2>/dev/null | sort))
ALL_PORTS=("${USB_PORTS[@]}" "${ACM_PORTS[@]}")

if [ ${#ALL_PORTS[@]} -eq 0 ]; then
    print_error "Aucun port série USB/ACM détecté!"
    print_warning "Vérifiez que vos périphériques USB sont connectés"
    exit 1
fi

print_section "📡 PORTS SÉRIE DÉTECTÉS"
print_info "Nombre total de ports: ${#ALL_PORTS[@]}"

for i in "${!ALL_PORTS[@]}"; do
    port="${ALL_PORTS[$i]}"
    port_name=$(basename "$port")
    echo -e "${WHITE}   $((i+1)). ${YELLOW}$port_name${NC} → $port"
done

# Analyse détaillée de chaque port
print_section "📍 ANALYSE DES POSITIONS PHYSIQUES"

declare -A POSITION_MAP
declare -A PORT_DETAILS

for i in "${!ALL_PORTS[@]}"; do
    port="${ALL_PORTS[$i]}"
    port_name=$(basename "$port")
    port_num=$((i+1))
    
    echo ""
    echo -e "${BOLD}${PURPLE}📱 PORT #$port_num: $port_name${NC}"
    echo -e "${PURPLE}$(printf '▔%.0s' {1..40})${NC}"
    
    # Récupérer toutes les informations du port
    echo -e "${CYAN}🏷️  Informations complètes du périphérique:${NC}"
    
    # Informations de base
    VENDOR_ID=$(sudo udevadm info -a -n "$port" | grep 'ATTRS{idVendor}' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
    PRODUCT_ID=$(sudo udevadm info -a -n "$port" | grep 'ATTRS{idProduct}' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
    SERIAL=$(sudo udevadm info -a -n "$port" | grep 'ATTRS{serial}' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
    
    print_detail "Vendor ID: ${YELLOW}$VENDOR_ID${NC}"
    print_detail "Product ID: ${YELLOW}$PRODUCT_ID${NC}"
    print_detail "Numéro de série: ${YELLOW}$SERIAL${NC}"
    
    # Position physique (KERNELS) - Information principale
    KERNELS=$(sudo udevadm info -a -n "$port" | grep 'KERNELS==' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
    print_position "Position physique unique: ${BOLD}${GREEN}$KERNELS${NC}"
    
    # Informations du système
    DEVPATH=$(sudo udevadm info -a -n "$port" | grep 'looking at device' | head -1 | cut -d"'" -f2 2>/dev/null || echo "N/A")
    SUBSYSTEM=$(sudo udevadm info -a -n "$port" | grep 'SUBSYSTEM==' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
    DRIVER=$(sudo udevadm info -a -n "$port" | grep 'DRIVERS==' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
    
    print_detail "Sous-système: $SUBSYSTEM"
    print_detail "Driver: $DRIVER"
    print_detail "Chemin périphérique: $DEVPATH"
    
    # Informations du fabricant si disponibles
    MANUFACTURER=$(sudo udevadm info -a -n "$port" | grep 'ATTRS{manufacturer}' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
    PRODUCT_NAME=$(sudo udevadm info -a -n "$port" | grep 'ATTRS{product}' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
    
    if [ "$MANUFACTURER" != "N/A" ]; then
        print_detail "Fabricant: $MANUFACTURER"
    fi
    if [ "$PRODUCT_NAME" != "N/A" ]; then
        print_detail "Nom du produit: $PRODUCT_NAME"
    fi
    
    # Informations de l'interface
    INTERFACE_CLASS=$(sudo udevadm info -a -n "$port" | grep 'ATTRS{bInterfaceClass}' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
    INTERFACE_PROTOCOL=$(sudo udevadm info -a -n "$port" | grep 'ATTRS{bInterfaceProtocol}' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
    
    if [ "$INTERFACE_CLASS" != "N/A" ]; then
        print_detail "Classe d'interface: $INTERFACE_CLASS"
    fi
    if [ "$INTERFACE_PROTOCOL" != "N/A" ]; then
        print_detail "Protocole d'interface: $INTERFACE_PROTOCOL"
    fi
    
    # Permissions et propriétés du fichier
    PORT_PERMS=$(ls -la "$port" 2>/dev/null | awk '{print $1" "$3" "$4}' || echo "N/A")
    print_detail "Permissions: $PORT_PERMS"
    
    # Stocker les informations pour le résumé
    POSITION_MAP["$KERNELS"]="$port_name"
    PORT_DETAILS["$port_name"]="$KERNELS:$VENDOR_ID:$PRODUCT_ID:$SERIAL"
done

# Résumé des positions physiques uniques
print_section "📋 RÉSUMÉ DES POSITIONS PHYSIQUES UNIQUES"

echo -e "${BOLD}${WHITE}Tableau des correspondances Position ↔ Port:${NC}"
echo ""
echo -e "${CYAN}┌─────────────────────────────┬─────────────────┐${NC}"
echo -e "${CYAN}│${NC} ${BOLD}Position Physique Unique${NC}   ${CYAN}│${NC} ${BOLD}Port Assigné${NC}       ${CYAN}│${NC}"
echo -e "${CYAN}├─────────────────────────────┼─────────────────┤${NC}"

# Trier les positions par ordre alphabétique pour un affichage cohérent
for kernels in $(printf '%s\n' "${!POSITION_MAP[@]}" | sort); do
    port_name="${POSITION_MAP[$kernels]}"
    printf "${CYAN}│${NC} %-27s ${CYAN}│${NC} %-15s ${CYAN}│${NC}\n" "$kernels" "$port_name"
done

echo -e "${CYAN}└─────────────────────────────┴─────────────────┘${NC}"

# Liste des positions uniques disponibles
print_section "🎯 POSITIONS UNIQUES DISPONIBLES"

echo -e "${BOLD}${GREEN}Positions physiques que vous pouvez utiliser pour fixer vos capteurs:${NC}"
echo ""

position_count=1
for kernels in $(printf '%s\n' "${!POSITION_MAP[@]}" | sort); do
    port_name="${POSITION_MAP[$kernels]}"
    echo -e "${WHITE}   $position_count. Position: ${BOLD}${YELLOW}$kernels${NC} ${WHITE}→ Actuellement: ${GREEN}$port_name${NC}"
    position_count=$((position_count + 1))
done

# Guide d'utilisation
print_section "📖 GUIDE D'UTILISATION"

echo -e "${CYAN}💡 Comment utiliser ces informations:${NC}"
echo ""
echo -e "${WHITE}1. ${BOLD}Choisir une position fixe pour chaque capteur:${NC}"
echo -e "${WHITE}   • Notez la position physique (ex: 1-1.4.2) de chaque port${NC}"
echo -e "${WHITE}   • Cette position ne changera pas tant que vous ne déplacez pas le câble${NC}"
echo ""
echo -e "${WHITE}2. ${BOLD}Créer des règles udev basées sur ces positions:${NC}"
echo -e "${WHITE}   • Utilisez le KERNELS pour créer des liens fixes${NC}"
echo -e "${WHITE}   • Exemple: KERNELS==\"1-1.4.2\" → /dev/medisense_temperature${NC}"
echo ""
echo -e "${WHITE}3. ${BOLD}Instructions pour vos utilisateurs:${NC}"
echo -e "${WHITE}   • \"Branchez le capteur de température sur la position 1-1.4.2\"${NC}"
echo -e "${WHITE}   • \"Branchez la balance sur la position 1-1.4.3\"${NC}"

# Sauvegarde des informations
CONFIG_FILE="/tmp/usb_positions.conf"
echo "# Configuration des positions physiques USB - $(date)" > "$CONFIG_FILE"
echo "# Généré automatiquement par usb_positions.sh" >> "$CONFIG_FILE"
echo "" >> "$CONFIG_FILE"

for kernels in $(printf '%s\n' "${!POSITION_MAP[@]}" | sort); do
    port_name="${POSITION_MAP[$kernels]}"
    port_info="${PORT_DETAILS[$port_name]}"
    vendor_id=$(echo "$port_info" | cut -d':' -f2)
    product_id=$(echo "$port_info" | cut -d':' -f3)
    serial=$(echo "$port_info" | cut -d':' -f4)
    
    echo "[$port_name]" >> "$CONFIG_FILE"
    echo "POSITION=$kernels" >> "$CONFIG_FILE"
    echo "VENDOR_ID=$vendor_id" >> "$CONFIG_FILE"
    echo "PRODUCT_ID=$product_id" >> "$CONFIG_FILE"
    echo "SERIAL=$serial" >> "$CONFIG_FILE"
    echo "" >> "$CONFIG_FILE"
done

print_section "💾 SAUVEGARDE"
print_info "Configuration sauvegardée dans: $CONFIG_FILE"
print_detail "Utilisez ce fichier pour référence future"

# Fin du script
print_section "✅ ANALYSE TERMINÉE"

echo -e "${BOLD}${GREEN}🎯 Résumé: ${#ALL_PORTS[@]} port(s) USB analysé(s)${NC}"
echo -e "${BOLD}${GREEN}📍 ${#POSITION_MAP[@]} position(s) physique(s) unique(s) identifiée(s)${NC}"
echo ""
echo -e "${WHITE}🔄 Relancez ce script après avoir reconnecté/déplacé des périphériques${NC}"
echo -e "${WHITE}📱 Utilisez le script de mapping pour associer position → port${NC}"
echo ""
echo -e "${BOLD}${BLUE}Analyse des positions physiques terminée! 🏥${NC}"