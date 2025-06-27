#!/bin/bash

# Script d'analyse des positions physiques USB - Raspberry Pi CORRIGÉ
# Analyse UNIQUEMENT les positions sans identifier les capteurs
# Auteur: MediSense Team - Version Corrigée
# Usage: bash usb_positions_fixed.sh

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

# Fonction d'affichage avec style (CORRIGÉES)
print_header() {
    echo -e "${BOLD}${BLUE}$1${NC}"
    echo -e "${BLUE}$(printf '=%.0s' {1..70})${NC}"
}

print_section() {
    echo -e "\n${BOLD}${CYAN}$1${NC}"
    echo -e "${CYAN}$(printf -- '-%.0s' {1..50})${NC}"  # ✅ CORRECTION: Ajout de --
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
echo -e "${BOLD}${WHITE}Objectif: Identifier les VRAIES positions physiques uniques des ports USB${NC}"
echo ""

# Détection des ports (ÉLARGIE)
print_section "🔍 DÉTECTION ÉLARGIE DES PORTS SÉRIE"

# ✅ CORRECTION: Détecter aussi ttyS0 qui peut être votre capteur manquant
USB_PORTS=($(ls /dev/ttyUSB* 2>/dev/null | sort))
ACM_PORTS=($(ls /dev/ttyACM* 2>/dev/null | sort))
S_PORTS=($(ls /dev/ttyS* 2>/dev/null | sort))

echo -e "${CYAN}🔌 Ports USB série (ttyUSB*):${NC}"
if [ ${#USB_PORTS[@]} -gt 0 ]; then
    for port in "${USB_PORTS[@]}"; do
        print_info "$(basename $port) → $port"
    done
else
    print_warning "Aucun port ttyUSB* détecté"
fi

echo -e "${CYAN}🔌 Ports ACM (ttyACM*):${NC}"
if [ ${#ACM_PORTS[@]} -gt 0 ]; then
    for port in "${ACM_PORTS[@]}"; do
        print_info "$(basename $port) → $port"
    done
else
    print_warning "Aucun port ttyACM* détecté"
fi

echo -e "${CYAN}🔌 Ports série natifs (ttyS*):${NC}"
if [ ${#S_PORTS[@]} -gt 0 ]; then
    for port in "${S_PORTS[@]}"; do
        # Vérifier si le port est utilisable (pas un port système vide)
        if [ -w "$port" ] 2>/dev/null || [[ "$port" == "/dev/ttyS0" ]]; then
            print_info "$(basename $port) → $port (POTENTIEL CAPTEUR!)"
        else
            print_detail "$(basename $port) → $port (Port système)"
        fi
    done
else
    print_warning "Aucun port ttyS* détecté"
fi

# Combiner les ports (INCLURE ttyS0 qui pourrait être votre capteur manquant)
ALL_PORTS=("${USB_PORTS[@]}" "${ACM_PORTS[@]}")

# Ajouter ttyS0 s'il existe (c'est peut-être votre capteur manquant!)
if [ -e "/dev/ttyS0" ]; then
    ALL_PORTS+=("/dev/ttyS0")
    print_warning "ttyS0 ajouté à l'analyse - c'est peut-être votre capteur manquant!"
fi

if [ ${#ALL_PORTS[@]} -eq 0 ]; then
    print_error "Aucun port série USB/ACM détecté!"
    print_warning "Vérifiez que vos périphériques USB sont connectés"
    exit 1
fi

print_section "📡 PORTS SÉRIE À ANALYSER"
print_info "Nombre total de ports: ${#ALL_PORTS[@]}"

for i in "${!ALL_PORTS[@]}"; do
    port="${ALL_PORTS[$i]}"
    port_name=$(basename "$port")
    echo -e "${WHITE}   $((i+1)). ${YELLOW}$port_name${NC} → $port"
done

# Analyse détaillée de chaque port
print_section "📍 ANALYSE DES VRAIES POSITIONS PHYSIQUES"

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
    
    # ✅ CORRECTION PRINCIPALE: Position physique réelle (KERNELS)
    KERNELS=$(sudo udevadm info -a -n "$port" | grep 'KERNELS==' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
    
    # ✅ CORRECTION: Si KERNELS est vide, essayer d'autres méthodes
    if [ "$KERNELS" = "N/A" ] || [ "$KERNELS" = "$port_name" ]; then
        # Essayer de récupérer depuis le chemin physique
        DEVPATH=$(sudo udevadm info -a -n "$port" | grep 'looking at device' | head -1 | cut -d"'" -f2 2>/dev/null || echo "N/A")
        
        if [[ "$DEVPATH" =~ usb([0-9]+)/([0-9]+-[0-9]+(\.[0-9]+)*) ]]; then
            KERNELS="${BASH_REMATCH[2]}"
            print_position "Position physique réelle: ${BOLD}${GREEN}$KERNELS${NC} (extraite du chemin)"
        else
            # Fallback: utiliser une partie du chemin USB
            USB_PATH=$(echo "$DEVPATH" | grep -o '[0-9]\+-[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1 || echo "N/A")
            if [ "$USB_PATH" != "N/A" ]; then
                KERNELS="$USB_PATH"
                print_position "Position physique estimée: ${BOLD}${YELLOW}$KERNELS${NC} (du chemin USB)"
            else
                KERNELS="$port_name"
                print_warning "Position physique non trouvée, utilisation du nom: $KERNELS"
            fi
        fi
    else
        print_position "Position physique réelle: ${BOLD}${GREEN}$KERNELS${NC}"
    fi
    
    # Informations du système
    DEVPATH=$(sudo udevadm info -a -n "$port" | grep 'looking at device' | head -1 | cut -d"'" -f2 2>/dev/null || echo "N/A")
    SUBSYSTEM=$(sudo udevadm info -a -n "$port" | grep 'SUBSYSTEM==' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
    DRIVER=$(sudo udevadm info -a -n "$port" | grep 'DRIVERS==' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
    
    print_detail "Sous-système: $SUBSYSTEM"
    print_detail "Driver: $DRIVER"
    if [ "$DEVPATH" != "N/A" ]; then
        print_detail "Chemin périphérique: $DEVPATH"
    fi
    
    # Informations du fabricant si disponibles
    MANUFACTURER=$(sudo udevadm info -a -n "$port" | grep 'ATTRS{manufacturer}' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
    PRODUCT_NAME=$(sudo udevadm info -a -n "$port" | grep 'ATTRS{product}' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
    
    if [ "$MANUFACTURER" != "N/A" ]; then
        print_detail "Fabricant: $MANUFACTURER"
    fi
    if [ "$PRODUCT_NAME" != "N/A" ]; then
        print_detail "Nom du produit: $PRODUCT_NAME"
    fi
    
    # Type de port et remarques spéciales
    if [[ "$port_name" == "ttyS0" ]]; then
        echo -e "${YELLOW}⚠️  ATTENTION: ttyS0 pourrait être votre capteur manquant!${NC}"
        echo -e "${WHITE}   Si vous aviez ttyUSB2 avant, il a peut-être été réattribué à ttyS0${NC}"
    fi
    
    # Permissions et propriétés du fichier
    PORT_PERMS=$(ls -la "$port" 2>/dev/null | awk '{print $1" "$3" "$4}' || echo "N/A")
    print_detail "Permissions: $PORT_PERMS"
    
    # Vérifier l'accessibilité
    if [ -r "$port" ] && [ -w "$port" ]; then
        print_detail "Accessibilité: ${GREEN}Lecture/Écriture OK${NC}"
    elif [ -r "$port" ]; then
        print_detail "Accessibilité: ${YELLOW}Lecture seule${NC}"
    else
        print_detail "Accessibilité: ${RED}Accès refusé${NC}"
        print_warning "Ajoutez-vous au groupe dialout: sudo usermod -a -G dialout \$USER"
    fi
    
    # Stocker les informations pour le résumé
    POSITION_MAP["$KERNELS"]="$port_name"
    PORT_DETAILS["$port_name"]="$KERNELS:$VENDOR_ID:$PRODUCT_ID:$SERIAL"
done

# Résumé des positions physiques uniques
print_section "📋 RÉSUMÉ DES VRAIES POSITIONS PHYSIQUES"

echo -e "${BOLD}${WHITE}Tableau des correspondances Position ↔ Port (CORRIGÉ):${NC}"
echo ""
echo -e "${CYAN}┌─────────────────────────────┬─────────────────┬─────────────────────┐${NC}"
echo -e "${CYAN}│${NC} ${BOLD}Position Physique Réelle${NC}     ${CYAN}│${NC} ${BOLD}Port Actuel${NC}         ${CYAN}│${NC} ${BOLD}Remarques${NC}           ${CYAN}│${NC}"
echo -e "${CYAN}├─────────────────────────────┼─────────────────┼─────────────────────┤${NC}"

# Trier les positions par ordre alphabétique pour un affichage cohérent
for kernels in $(printf '%s\n' "${!POSITION_MAP[@]}" | sort); do
    port_name="${POSITION_MAP[$kernels]}"
    
    # Déterminer les remarques
    if [[ "$kernels" =~ ^[0-9]+-[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        remarks="Position fixe"
    elif [[ "$port_name" == "ttyS0" ]]; then
        remarks="Capteur manquant?"
    elif [[ "$kernels" == "$port_name" ]]; then
        remarks="Position incertaine"
    else
        remarks="OK"
    fi
    
    printf "${CYAN}│${NC} %-27s ${CYAN}│${NC} %-15s ${CYAN}│${NC} %-19s ${CYAN}│${NC}\n" "$kernels" "$port_name" "$remarks"
done

echo -e "${CYAN}└─────────────────────────────┴─────────────────┴─────────────────────┘${NC}"

# Diagnostic spécial pour le capteur manquant
print_section "🕵️ DIAGNOSTIC DU CAPTEUR MANQUANT"

echo -e "${CYAN}💡 Analyse du problème ttyUSB2 → ttyS0:${NC}"
echo ""

if [ -e "/dev/ttyS0" ]; then
    print_info "ttyS0 détecté - c'est probablement votre capteur manquant!"
    echo -e "${WHITE}   📋 Votre capteur qui était sur ttyUSB2 est maintenant sur ttyS0${NC}"
    echo -e "${WHITE}   📋 Cela arrive quand Linux change la numérotation des ports${NC}"
    
    # Tester ttyS0 pour voir s'il répond
    echo -e "${CYAN}🧪 Test de ttyS0:${NC}"
    if timeout 2 bash -c 'echo "test" > /dev/ttyS0' 2>/dev/null; then
        print_info "ttyS0 accepte les données - c'est bien un port série fonctionnel"
    else
        print_warning "ttyS0 ne répond pas - vérifiez les permissions"
    fi
else
    print_warning "ttyS0 non détecté"
fi

# Recommandations pour fixer le problème
print_section "🔧 RECOMMANDATIONS POUR FIXER LES PORTS"

echo -e "${CYAN}💡 Solutions pour stabiliser vos ports:${NC}"
echo ""

echo -e "${WHITE}${BOLD}1. Utiliser les positions physiques réelles:${NC}"
for kernels in $(printf '%s\n' "${!POSITION_MAP[@]}" | sort); do
    port_name="${POSITION_MAP[$kernels]}"
    if [[ "$kernels" =~ ^[0-9]+-[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${WHITE}   ✅ Position stable détectée: $kernels → Utilisez pour règle udev${NC}"
    fi
done

echo ""
echo -e "${WHITE}${BOLD}2. Règles udev suggérées:${NC}"
for kernels in $(printf '%s\n' "${!POSITION_MAP[@]}" | sort); do
    port_name="${POSITION_MAP[$kernels]}"
    port_info="${PORT_DETAILS[$port_name]}"
    vendor_id=$(echo "$port_info" | cut -d':' -f2)
    product_id=$(echo "$port_info" | cut -d':' -f3)
    
    if [[ "$kernels" =~ ^[0-9]+-[0-9]+\.[0-9]+\.[0-9]+$ ]] && [ "$vendor_id" != "N/A" ]; then
        echo -e "${GREEN}# Pour fixer $port_name sur la position $kernels${NC}"
        echo -e "${WHITE}SUBSYSTEM==\"tty\", ATTRS{idVendor}==\"$vendor_id\", ATTRS{idProduct}==\"$product_id\", KERNELS==\"$kernels\", SYMLINK+=\"medisense_capteur_$port_name\"${NC}"
        echo ""
    fi
done

echo -e "${WHITE}${BOLD}3. Si ttyS0 est votre capteur manquant:${NC}"
echo -e "${WHITE}   • Modifiez votre code pour inclure /dev/ttyS0${NC}"
echo -e "${WHITE}   • Testez: python3 -c \"import serial; ser=serial.Serial('/dev/ttyS0', 57600); print('OK')\"${NC}"
echo -e "${WHITE}   • Créez une règle udev pour le stabiliser${NC}"

# Sauvegarde des informations
CONFIG_FILE="/tmp/usb_positions_corrected.conf"
echo "# Configuration des positions physiques USB CORRIGÉE - $(date)" > "$CONFIG_FILE"
echo "# Généré automatiquement par usb_positions_fixed.sh" >> "$CONFIG_FILE"
echo "" >> "$CONFIG_FILE"

for kernels in $(printf '%s\n' "${!POSITION_MAP[@]}" | sort); do
    port_name="${POSITION_MAP[$kernels]}"
    port_info="${PORT_DETAILS[$port_name]}"
    vendor_id=$(echo "$port_info" | cut -d':' -f2)
    product_id=$(echo "$port_info" | cut -d':' -f3)
    serial=$(echo "$port_info" | cut -d':' -f4)
    
    echo "[$port_name]" >> "$CONFIG_FILE"
    echo "REAL_POSITION=$kernels" >> "$CONFIG_FILE"
    echo "VENDOR_ID=$vendor_id" >> "$CONFIG_FILE"
    echo "PRODUCT_ID=$product_id" >> "$CONFIG_FILE"
    echo "SERIAL=$serial" >> "$CONFIG_FILE"
    echo "" >> "$CONFIG_FILE"
done

print_section "💾 SAUVEGARDE"
print_info "Configuration corrigée sauvegardée dans: $CONFIG_FILE"
print_detail "Cette version corrige les problèmes de positions physiques"

# Fin du script
print_section "✅ ANALYSE CORRIGÉE TERMINÉE"

echo -e "${BOLD}${GREEN}🎯 Résumé: ${#ALL_PORTS[@]} port(s) analysé(s) (incluant ttyS0)${NC}"
echo -e "${BOLD}${GREEN}📍 ${#POSITION_MAP[@]} position(s) physique(s) réelle(s) identifiée(s)${NC}"
echo ""
echo -e "${WHITE}🔍 Votre capteur manquant est probablement sur ttyS0 maintenant!${NC}"
echo -e "${WHITE}🔄 Modifiez votre code pour inclure /dev/ttyS0 dans la détection${NC}"
echo ""
echo -e "${BOLD}${BLUE}Analyse corrigée terminée! 🏥${NC}"