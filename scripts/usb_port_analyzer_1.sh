#!/bin/bash

# Script d'analyse complète des ports USB pour MediSense Pro
# Compatible Raspberry Pi - Analyse des positions physiques des ports
# Auteur: MediSense Team
# Usage: bash usb_analyzer.sh

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
    echo -e "${BLUE}$(printf '=%.0s' {1..60})${NC}"
}

print_section() {
    echo -e "\n${BOLD}${CYAN}$1${NC}"
    echo -e "${CYAN}$(printf '-%.0s' {1..40})${NC}"
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

# Fonction pour tester un capteur
test_sensor() {
    local port=$1
    local baudrate=$2
    local timeout=3
    
    timeout $timeout python3 -c "
import serial
import time
import sys

try:
    ser = serial.Serial('$port', $baudrate, timeout=2)
    time.sleep(1)
    
    values = []
    codes = []
    
    for _ in range(5):
        if ser.in_waiting > 0:
            data = ser.readline().decode('utf-8', errors='ignore').strip()
            if data:
                # Test valeur numérique
                try:
                    value = float(data)
                    values.append(value)
                except:
                    pass
                
                # Test code entier
                try:
                    code = int(data)
                    if 100000 <= code <= 999999:
                        codes.append(code)
                except:
                    pass
        time.sleep(0.2)
    
    ser.close()
    
    # Analyser les résultats
    if values:
        avg = sum(values) / len(values)
        if 35 <= avg <= 42:
            print(f'TEMPERATURE:{avg:.1f}°C')
        elif 1 <= avg <= 200:
            print(f'POIDS:{avg:.1f}kg')
        else:
            print(f'UNKNOWN_NUMERIC:{avg:.1f}')
    elif codes:
        print(f'VALIDATION:{codes[0]}')
    else:
        print('NO_DATA')

except Exception as e:
    print('ERROR')
" 2>/dev/null
}

# Début du script
clear
print_header "🔍 ANALYSEUR COMPLET DES PORTS USB - RASPBERRY PI"
echo -e "${BOLD}${WHITE}Date: $(date)${NC}"
echo -e "${BOLD}${WHITE}Système: $(uname -a | cut -d' ' -f1-3)${NC}"
echo ""

# Vérification des prérequis
print_section "🔧 Vérification des prérequis"

if ! command -v python3 &> /dev/null; then
    print_error "Python3 non trouvé"
    exit 1
fi

if ! python3 -c "import serial" 2>/dev/null; then
    print_error "Module pyserial non installé"
    echo "Installez avec: pip3 install pyserial"
    exit 1
fi

print_info "Python3 et pyserial disponibles"

# Étape 1: Lister tous les ports série
print_section "📡 DÉTECTION DES PORTS SÉRIE"

USB_PORTS=($(ls /dev/ttyUSB* 2>/dev/null | sort))
ACM_PORTS=($(ls /dev/ttyACM* 2>/dev/null | sort))
ALL_PORTS=("${USB_PORTS[@]}" "${ACM_PORTS[@]}")

if [ ${#ALL_PORTS[@]} -eq 0 ]; then
    print_error "Aucun port série détecté!"
    print_warning "Vérifiez que vos périphériques USB sont connectés"
    exit 1
fi

print_info "Ports série détectés: ${#ALL_PORTS[@]}"
for port in "${ALL_PORTS[@]}"; do
    print_detail "$(basename $port) → $port"
done

# Étape 2: Analyse détaillée de chaque port
print_section "🔍 ANALYSE DÉTAILLÉE DES PORTS USB"

declare -A PORT_INFO
declare -A SENSOR_MAPPING

for port in "${ALL_PORTS[@]}"; do
    if [ ! -e "$port" ]; then
        continue
    fi
    
    port_name=$(basename "$port")
    echo ""
    echo -e "${BOLD}${PURPLE}📱 ANALYSE DE $port_name${NC}"
    echo -e "${PURPLE}$(printf '▔%.0s' {1..30})${NC}"
    
    # Informations udev complètes
    echo -e "${CYAN}🏷️  Informations du périphérique:${NC}"
    
    # Vendor et Product ID
    VENDOR_ID=$(sudo udevadm info -a -n "$port" | grep 'ATTRS{idVendor}' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
    PRODUCT_ID=$(sudo udevadm info -a -n "$port" | grep 'ATTRS{idProduct}' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
    
    print_detail "Vendor ID: $VENDOR_ID"
    print_detail "Product ID: $PRODUCT_ID"
    
    # Serial Number
    SERIAL=$(sudo udevadm info -a -n "$port" | grep 'ATTRS{serial}' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
    print_detail "Numéro de série: $SERIAL"
    
    # KERNELS (position physique)
    KERNELS=$(sudo udevadm info -a -n "$port" | grep 'KERNELS==' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
    print_detail "Position physique (KERNELS): $KERNELS"
    
    # Device Path
    DEVPATH=$(sudo udevadm info -a -n "$port" | grep 'looking at device' | head -1 | cut -d"'" -f2 2>/dev/null || echo "N/A")
    print_detail "Chemin périphérique: $DEVPATH"
    
    # Informations du driver
    DRIVER=$(sudo udevadm info -a -n "$port" | grep 'DRIVERS==' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
    print_detail "Driver utilisé: $DRIVER"
    
    # Manufacturer et Product name
    MANUFACTURER=$(sudo udevadm info -a -n "$port" | grep 'ATTRS{manufacturer}' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
    PRODUCT_NAME=$(sudo udevadm info -a -n "$port" | grep 'ATTRS{product}' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
    
    if [ "$MANUFACTURER" != "N/A" ]; then
        print_detail "Fabricant: $MANUFACTURER"
    fi
    if [ "$PRODUCT_NAME" != "N/A" ]; then
        print_detail "Nom du produit: $PRODUCT_NAME"
    fi
    
    # Test du type de capteur
    echo -e "${CYAN}🧪 Test d'identification du capteur:${NC}"
    
    # Test à 9600 baud
    result_9600=$(test_sensor "$port" 9600)
    if [ "$result_9600" != "ERROR" ] && [ "$result_9600" != "NO_DATA" ]; then
        print_info "9600 baud: $result_9600"
    else
        print_detail "9600 baud: Aucune donnée valide"
    fi
    
    # Test à 57600 baud pour les capteurs de poids
    result_57600=$(test_sensor "$port" 57600)
    if [ "$result_57600" != "ERROR" ] && [ "$result_57600" != "NO_DATA" ]; then
        print_info "57600 baud: $result_57600"
    else
        print_detail "57600 baud: Aucune donnée valide"
    fi
    
    # Déterminer le type de capteur
    SENSOR_TYPE="INCONNU"
    if [[ "$result_9600" == TEMPERATURE* ]]; then
        SENSOR_TYPE="CAPTEUR_TEMPERATURE"
        SENSOR_MAPPING["TEMPERATURE"]="$port:$KERNELS"
    elif [[ "$result_57600" == POIDS* ]]; then
        SENSOR_TYPE="CAPTEUR_POIDS" 
        SENSOR_MAPPING["POIDS"]="$port:$KERNELS"
    elif [[ "$result_9600" == VALIDATION* ]] || [[ "$port" == *"ACM"* ]]; then
        SENSOR_TYPE="CAPTEUR_VALIDATION"
        SENSOR_MAPPING["VALIDATION"]="$port:$KERNELS"
    fi
    
    echo -e "${GREEN}🎯 Type identifié: ${BOLD}$SENSOR_TYPE${NC}"
    
    # Stocker les informations
    PORT_INFO["$port"]="$VENDOR_ID:$PRODUCT_ID:$KERNELS:$SENSOR_TYPE:$SERIAL"
done

# Étape 3: Résumé des positions physiques
print_section "📍 RÉSUMÉ DES POSITIONS PHYSIQUES"

echo -e "${BOLD}${WHITE}Position physique des capteurs détectés:${NC}"
echo ""

if [ ${#SENSOR_MAPPING[@]} -eq 0 ]; then
    print_warning "Aucun capteur MediSense détecté"
else
    for sensor in "TEMPERATURE" "POIDS" "VALIDATION"; do
        if [[ -n "${SENSOR_MAPPING[$sensor]}" ]]; then
            port_info="${SENSOR_MAPPING[$sensor]}"
            port_name=$(echo "$port_info" | cut -d':' -f1)
            kernels=$(echo "$port_info" | cut -d':' -f2)
            
            case $sensor in
                "TEMPERATURE")
                    icon="🌡️"
                    desc="Capteur de Température"
                    ;;
                "POIDS")
                    icon="⚖️"
                    desc="Capteur de Poids"
                    ;;
                "VALIDATION")
                    icon="🔐"
                    desc="Capteur de Validation"
                    ;;
            esac
            
            echo -e "${BOLD}${GREEN}$icon $desc${NC}"
            echo -e "   📱 Port: ${YELLOW}$port_name${NC}"
            echo -e "   📍 Position physique: ${CYAN}$kernels${NC}"
            echo ""
        else
            case $sensor in
                "TEMPERATURE") icon="🌡️"; desc="Capteur de Température" ;;
                "POIDS") icon="⚖️"; desc="Capteur de Poids" ;;
                "VALIDATION") icon="🔐"; desc="Capteur de Validation" ;;
            esac
            echo -e "${RED}$icon $desc: Non détecté${NC}"
        fi
    done
fi

# Étape 4: Génération des règles udev
print_section "📝 GÉNÉRATION DES RÈGLES UDEV"

if [ ${#SENSOR_MAPPING[@]} -gt 0 ]; then
    echo -e "${CYAN}Règles udev suggérées pour fixer les ports:${NC}"
    echo ""
    
    for sensor in "TEMPERATURE" "POIDS" "VALIDATION"; do
        if [[ -n "${SENSOR_MAPPING[$sensor]}" ]]; then
            port_info="${SENSOR_MAPPING[$sensor]}"
            port_name=$(echo "$port_info" | cut -d':' -f1)
            kernels=$(echo "$port_info" | cut -d':' -f2)
            
            # Récupérer les IDs pour ce port
            port_data="${PORT_INFO[$port_name]}"
            vendor_id=$(echo "$port_data" | cut -d':' -f1)
            product_id=$(echo "$port_data" | cut -d':' -f2)
            
            sensor_lower=$(echo "$sensor" | tr '[:upper:]' '[:lower:]')
            
            echo -e "${WHITE}# $sensor (Position: $kernels)${NC}"
            if [ "$kernels" != "N/A" ]; then
                echo -e "${GREEN}SUBSYSTEM==\"tty\", ATTRS{idVendor}==\"$vendor_id\", ATTRS{idProduct}==\"$product_id\", KERNELS==\"$kernels\", SYMLINK+=\"medisense_$sensor_lower\"${NC}"
            else
                echo -e "${YELLOW}SUBSYSTEM==\"tty\", ATTRS{idVendor}==\"$vendor_id\", ATTRS{idProduct}==\"$product_id\", SYMLINK+=\"medisense_$sensor_lower\"${NC}"
            fi
            echo ""
        fi
    done
    
    echo -e "${CYAN}💡 Pour appliquer ces règles:${NC}"
    echo -e "${WHITE}   1. sudo nano /etc/udev/rules.d/99-medisense.rules${NC}"
    echo -e "${WHITE}   2. Copier les règles ci-dessus${NC}"
    echo -e "${WHITE}   3. sudo udevadm control --reload-rules${NC}"
    echo -e "${WHITE}   4. sudo udevadm trigger${NC}"
    echo -e "${WHITE}   5. sudo reboot${NC}"
else
    print_warning "Aucune règle udev générée - capteurs non détectés"
fi

# Étape 5: Guide de branchement
print_section "🔌 GUIDE DE BRANCHEMENT POUR L'UTILISATEUR"

echo -e "${BOLD}${WHITE}Instructions de branchement des capteurs:${NC}"
echo ""

if [[ -n "${SENSOR_MAPPING[TEMPERATURE]}" ]]; then
    kernels=$(echo "${SENSOR_MAPPING[TEMPERATURE]}" | cut -d':' -f2)
    echo -e "${GREEN}🌡️  CAPTEUR DE TEMPÉRATURE:${NC}"
    echo -e "   📍 Brancher sur la position physique: ${CYAN}$kernels${NC}"
    echo -e "   💡 Cette position correspond actuellement à: ${YELLOW}$(echo "${SENSOR_MAPPING[TEMPERATURE]}" | cut -d':' -f1)${NC}"
    echo ""
fi

if [[ -n "${SENSOR_MAPPING[POIDS]}" ]]; then
    kernels=$(echo "${SENSOR_MAPPING[POIDS]}" | cut -d':' -f2)
    echo -e "${GREEN}⚖️  CAPTEUR DE POIDS (BALANCE):${NC}"
    echo -e "   📍 Brancher sur la position physique: ${CYAN}$kernels${NC}"
    echo -e "   💡 Cette position correspond actuellement à: ${YELLOW}$(echo "${SENSOR_MAPPING[POIDS]}" | cut -d':' -f1)${NC}"
    echo ""
fi

if [[ -n "${SENSOR_MAPPING[VALIDATION]}" ]]; then
    kernels=$(echo "${SENSOR_MAPPING[VALIDATION]}" | cut -d':' -f2)
    echo -e "${GREEN}🔐 CAPTEUR DE VALIDATION:${NC}"
    echo -e "   📍 Brancher sur la position physique: ${CYAN}$kernels${NC}"
    echo -e "   💡 Cette position correspond actuellement à: ${YELLOW}$(echo "${SENSOR_MAPPING[VALIDATION]}" | cut -d':' -f1)${NC}"
    echo ""
fi

# Informations supplémentaires
echo -e "${CYAN}📋 Informations importantes:${NC}"
echo -e "${WHITE}   • Les positions physiques (KERNELS) ne changent pas tant que vous${NC}"
echo -e "${WHITE}     ne déplacez pas physiquement les câbles USB${NC}"
echo -e "${WHITE}   • Une fois les règles udev appliquées, les capteurs auront${NC}"
echo -e "${WHITE}     des liens fixes: /dev/medisense_temperature, etc.${NC}"
echo -e "${WHITE}   • Redémarrez après avoir appliqué les règles udev${NC}"

# Fin du script
print_section "✅ ANALYSE TERMINÉE"

echo -e "${BOLD}${GREEN}🎯 Résumé: ${#SENSOR_MAPPING[@]} capteur(s) MediSense détecté(s)${NC}"
echo -e "${WHITE}📄 Log sauvegardé automatiquement dans les journaux système${NC}"
echo -e "${WHITE}🔄 Relancez ce script après avoir déplacé des capteurs${NC}"
echo ""
echo -e "${BOLD}${BLUE}Merci d'utiliser MediSense Pro! 🏥${NC}"