#!/bin/bash

# Détecteur complet de ports série - Tous types
# Compatible Raspberry Pi - Détecte TOUS les changements de ports
# Auteur: MediSense Team
# Usage: bash comprehensive_detector.sh

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
print_header "🔍 DÉTECTEUR COMPLET DE PORTS SÉRIE - RASPBERRY PI"
echo -e "${BOLD}${WHITE}Date: $(date)${NC}"
echo -e "${BOLD}${WHITE}Système: $(uname -a | cut -d' ' -f1-3)${NC}"
echo -e "${BOLD}${WHITE}Objectif: Détecter TOUS les ports série (USB, ACM, S, AMA, etc.)${NC}"
echo ""

# Étape 1: Détection complète de TOUS les ports série
print_section "📡 DÉTECTION COMPLÈTE DES PORTS SÉRIE"

echo -e "${CYAN}🔍 Recherche de tous les types de ports série...${NC}"

# Rechercher tous les types de ports série possibles
USB_PORTS=($(ls /dev/ttyUSB* 2>/dev/null | sort))
ACM_PORTS=($(ls /dev/ttyACM* 2>/dev/null | sort))
S_PORTS=($(ls /dev/ttyS* 2>/dev/null | sort))
AMA_PORTS=($(ls /dev/ttyAMA* 2>/dev/null | sort))

echo -e "${WHITE}🔌 Ports USB série (ttyUSB*):${NC}"
if [ ${#USB_PORTS[@]} -gt 0 ]; then
    for port in "${USB_PORTS[@]}"; do
        print_info "$(basename $port) → $port"
    done
else
    print_warning "Aucun port ttyUSB* détecté"
fi

echo -e "${WHITE}🔌 Ports ACM (ttyACM*):${NC}"
if [ ${#ACM_PORTS[@]} -gt 0 ]; then
    for port in "${ACM_PORTS[@]}"; do
        print_info "$(basename $port) → $port"
    done
else
    print_warning "Aucun port ttyACM* détecté"
fi

echo -e "${WHITE}🔌 Ports série natifs (ttyS*):${NC}"
if [ ${#S_PORTS[@]} -gt 0 ]; then
    for port in "${S_PORTS[@]}"; do
        print_detail "$(basename $port) → $port (Port série natif)"
    done
else
    print_detail "Aucun port ttyS* utilisable détecté"
fi

echo -e "${WHITE}🔌 Ports UART Raspberry Pi (ttyAMA*):${NC}"
if [ ${#AMA_PORTS[@]} -gt 0 ]; then
    for port in "${AMA_PORTS[@]}"; do
        print_detail "$(basename $port) → $port (UART Raspberry Pi)"
    done
else
    print_detail "Aucun port ttyAMA* détecté"
fi

# Combiner tous les ports détectés (sauf les ports système)
ALL_PORTS=("${USB_PORTS[@]}" "${ACM_PORTS[@]}")

# Ajouter les ports UART seulement s'ils sont configurés pour les capteurs
for port in "${AMA_PORTS[@]}"; do
    if [[ "$port" != "/dev/ttyAMA0" ]] || [ -w "$port" ] 2>/dev/null; then
        ALL_PORTS+=("$port")
    fi
done

echo ""
print_info "Total des ports série utilisables: ${#ALL_PORTS[@]}"

if [ ${#ALL_PORTS[@]} -eq 0 ]; then
    print_error "Aucun port série utilisable détecté!"
    print_warning "Vérifications à faire:"
    echo -e "${WHITE}   1. Vos capteurs sont-ils bien connectés ?${NC}"
    echo -e "${WHITE}   2. Les câbles USB fonctionnent-ils ?${NC}"
    echo -e "${WHITE}   3. Les drivers sont-ils installés ?${NC}"
    echo -e "${WHITE}   4. Permissions sur les ports ? (sudo usermod -a -G dialout \$USER)${NC}"
    exit 1
fi

# Étape 2: Comparaison avec l'état précédent
print_section "📊 COMPARAISON AVEC L'ÉTAT PRÉCÉDENT"

PREVIOUS_STATE="/tmp/medisense_previous_ports.txt"

if [ -f "$PREVIOUS_STATE" ]; then
    echo -e "${CYAN}📄 État précédent trouvé, comparaison...${NC}"
    
    # Lire l'état précédent
    declare -A PREVIOUS_PORTS
    while IFS= read -r line; do
        if [[ "$line" =~ ^([^:]+):(.+)$ ]]; then
            port="${BASH_REMATCH[1]}"
            kernels="${BASH_REMATCH[2]}"
            PREVIOUS_PORTS["$kernels"]="$port"
        fi
    done < "$PREVIOUS_STATE"
    
    echo -e "${WHITE}🔄 Changements détectés:${NC}"
    
    # Vérifier les changements
    changes_detected=false
    for port in "${ALL_PORTS[@]}"; do
        port_name=$(basename "$port")
        current_kernels=$(sudo udevadm info -a -n "$port" | grep 'KERNELS==' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
        
        if [ "$current_kernels" != "N/A" ]; then
            if [[ -n "${PREVIOUS_PORTS[$current_kernels]}" ]]; then
                prev_port="${PREVIOUS_PORTS[$current_kernels]}"
                if [ "$prev_port" != "$port_name" ]; then
                    print_warning "Position $current_kernels: $prev_port → $port_name (CHANGEMENT!)"
                    changes_detected=true
                else
                    print_detail "Position $current_kernels: $port_name (Inchangé)"
                fi
            else
                print_info "Position $current_kernels: $port_name (NOUVEAU)"
                changes_detected=true
            fi
        fi
    done
    
    if [ "$changes_detected" = false ]; then
        print_info "Aucun changement détecté depuis la dernière analyse"
    fi
else
    print_warning "Aucun état précédent trouvé - première analyse"
fi

# Étape 3: Analyse détaillée de chaque port
print_section "🔍 ANALYSE DÉTAILLÉE DES PORTS"

declare -A POSITION_MAP
declare -A PORT_DETAILS

for i in "${!ALL_PORTS[@]}"; do
    port="${ALL_PORTS[$i]}"
    port_name=$(basename "$port")
    port_num=$((i+1))
    
    echo ""
    echo -e "${BOLD}${PURPLE}📱 PORT #$port_num: $port_name${NC}"
    echo -e "${PURPLE}$(printf '▔%.0s' {1..40})${NC}"
    
    # Vérifier que le port existe et est accessible
    if [ ! -e "$port" ]; then
        print_error "Port $port non accessible"
        continue
    fi
    
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
    
    # Type de port
    if [[ "$port_name" == ttyUSB* ]]; then
        PORT_TYPE="USB Série (Convertisseur USB-Série)"
    elif [[ "$port_name" == ttyACM* ]]; then
        PORT_TYPE="USB ACM (Arduino, Modem, etc.)"
    elif [[ "$port_name" == ttyS* ]]; then
        PORT_TYPE="Port série natif"
    elif [[ "$port_name" == ttyAMA* ]]; then
        PORT_TYPE="UART Raspberry Pi"
    else
        PORT_TYPE="Autre type de port série"
    fi
    
    print_detail "Type de port: $PORT_TYPE"
    
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
    if [ "$KERNELS" != "N/A" ]; then
        POSITION_MAP["$KERNELS"]="$port_name"
        PORT_DETAILS["$port_name"]="$KERNELS:$VENDOR_ID:$PRODUCT_ID:$SERIAL:$PORT_TYPE"
    fi
done

# Étape 4: Résumé des positions physiques uniques
print_section "📋 RÉSUMÉ DES POSITIONS PHYSIQUES UNIQUES"

echo -e "${BOLD}${WHITE}Tableau des correspondances Position ↔ Port:${NC}"
echo ""
echo -e "${CYAN}┌─────────────────────────────┬─────────────────┬─────────────────────┐${NC}"
echo -e "${CYAN}│${NC} ${BOLD}Position Physique Unique${NC}   ${CYAN}│${NC} ${BOLD}Port Assigné${NC}       ${CYAN}│${NC} ${BOLD}Type${NC}                ${CYAN}│${NC}"
echo -e "${CYAN}├─────────────────────────────┼─────────────────┼─────────────────────┤${NC}"

# Trier les positions par ordre alphabétique
for kernels in $(printf '%s\n' "${!POSITION_MAP[@]}" | sort); do
    port_name="${POSITION_MAP[$kernels]}"
    port_info="${PORT_DETAILS[$port_name]}"
    port_type=$(echo "$port_info" | cut -d':' -f5)
    
    # Raccourcir le type pour l'affichage
    case "$port_type" in
        "USB Série"*) short_type="USB Série" ;;
        "USB ACM"*) short_type="USB ACM" ;;
        "Port série natif") short_type="Série natif" ;;
        "UART Raspberry Pi") short_type="UART RPi" ;;
        *) short_type="Autre" ;;
    esac
    
    printf "${CYAN}│${NC} %-27s ${CYAN}│${NC} %-15s ${CYAN}│${NC} %-19s ${CYAN}│${NC}\n" "$kernels" "$port_name" "$short_type"
done

echo -e "${CYAN}└─────────────────────────────┴─────────────────┴─────────────────────┘${NC}"

# Étape 5: Sauvegarde de l'état actuel
print_section "💾 SAUVEGARDE DE L'ÉTAT ACTUEL"

echo "# État des ports série - $(date)" > "$PREVIOUS_STATE"
for kernels in $(printf '%s\n' "${!POSITION_MAP[@]}" | sort); do
    port_name="${POSITION_MAP[$kernels]}"
    echo "$port_name:$kernels" >> "$PREVIOUS_STATE"
done

print_info "État actuel sauvegardé dans: $PREVIOUS_STATE"
print_detail "Utilisé pour détecter les changements lors de la prochaine exécution"

# Étape 6: Recommandations
print_section "💡 RECOMMANDATIONS"

echo -e "${CYAN}📋 Conseils pour stabiliser vos ports:${NC}"
echo ""
echo -e "${WHITE}1. ${BOLD}Positions physiques stables détectées:${NC}"
for kernels in $(printf '%s\n' "${!POSITION_MAP[@]}" | sort); do
    port_name="${POSITION_MAP[$kernels]}"
    echo -e "${WHITE}   • Position $kernels → Utilisez toujours ce port pour le même capteur${NC}"
done

echo ""
echo -e "${WHITE}2. ${BOLD}Pour créer des liens fixes:${NC}"
echo -e "${WHITE}   • Créez des règles udev basées sur les positions KERNELS${NC}"
echo -e "${WHITE}   • Exemple: KERNELS==\"1-1.4.2\" → /dev/medisense_temperature${NC}"

echo ""
echo -e "${WHITE}3. ${BOLD}Si un port disparaît:${NC}"
echo -e "${WHITE}   • Vérifiez les connexions physiques${NC}"
echo -e "${WHITE}   • Redémarrez le Raspberry Pi${NC}"
echo -e "${WHITE}   • Vérifiez les permissions (dialout group)${NC}"

# Fin du script
print_section "✅ ANALYSE TERMINÉE"

echo -e "${BOLD}${GREEN}🎯 Résumé: ${#ALL_PORTS[@]} port(s) série analysé(s)${NC}"
echo -e "${BOLD}${GREEN}📍 ${#POSITION_MAP[@]} position(s) physique(s) unique(s) identifiée(s)${NC}"
echo ""
echo -e "${WHITE}🔄 Relancez ce script pour détecter les changements de ports${NC}"
echo -e "${WHITE}📱 Les changements de ttyUSB0→ttyUSB1 seront maintenant détectés!${NC}"
echo ""
echo -e "${BOLD}${BLUE}Analyse complète terminée! 🏥${NC}"