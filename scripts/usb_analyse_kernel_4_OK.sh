#!/bin/bash

# Système de contrôle des ports par KERNELS (positions physiques uniques)
# Identifie chaque port par son numéro de position physique unique
# Auteur: MediSense Team
# Usage: bash kernel_port_system.sh

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

# Fonctions d'affichage
print_header() {
    echo -e "${BOLD}${BLUE}$1${NC}"
    echo -e "${BLUE}$(printf '=%.0s' {1..80})${NC}"
}

print_section() {
    echo -e "\n${BOLD}${CYAN}$1${NC}"
    echo -e "${CYAN}$(printf -- '-%.0s' {1..60})${NC}"
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

print_kernel() {
    echo -e "${BOLD}${PURPLE}   🎯 KERNEL: ${GREEN}$1${NC}"
}

# Fonction pour extraire le KERNEL réel d'un port
get_real_kernel() {
    local port=$1
    local kernel_candidate=""
    
    # Méthode 1: KERNELS direct
    kernel_candidate=$(sudo udevadm info -a -n "$port" | grep 'KERNELS==' | head -1 | cut -d'"' -f2 2>/dev/null || echo "")
    
    # Si le KERNELS est vide ou égal au nom du port, extraire du chemin
    if [ -z "$kernel_candidate" ] || [ "$kernel_candidate" = "$(basename $port)" ]; then
        # Méthode 2: Extraire du chemin USB
        local devpath=$(sudo udevadm info -a -n "$port" | grep 'looking at device' | head -1 | cut -d"'" -f2 2>/dev/null || echo "")
        
        if [[ "$devpath" =~ ([0-9]+-[0-9]+(\.[0-9]+)*) ]]; then
            kernel_candidate="${BASH_REMATCH[1]}"
        else
            # Méthode 3: Analyser le chemin complet pour extraire la position USB
            local usb_path=$(echo "$devpath" | grep -o '/usb[0-9]*/[^/]*' | tail -1 | cut -d'/' -f3 2>/dev/null || echo "")
            if [ -n "$usb_path" ] && [ "$usb_path" != "$(basename $port)" ]; then
                kernel_candidate="$usb_path"
            else
                # Méthode 4: Utiliser les informations du bus USB
                local bus_info=$(lsusb -t | grep -A 5 -B 5 "$(basename $port)" 2>/dev/null || echo "")
                if [[ "$bus_info" =~ Port\ ([0-9]+) ]]; then
                    kernel_candidate="usb-port-${BASH_REMATCH[1]}"
                else
                    kernel_candidate="unknown-$(basename $port)"
                fi
            fi
        fi
    fi
    
    echo "$kernel_candidate"
}

# Début du script
clear
print_header "🎯 SYSTÈME DE CONTRÔLE PAR KERNELS - POSITIONS PHYSIQUES UNIQUES"
echo -e "${BOLD}${WHITE}Date: $(date)${NC}"
echo -e "${BOLD}${WHITE}Système: $(uname -a | cut -d' ' -f1-3)${NC}"
echo -e "${BOLD}${WHITE}Objectif: Identifier chaque port par son KERNEL unique${NC}"
echo ""

# Détection exhaustive des ports série
print_section "🔍 DÉTECTION EXHAUSTIVE DES PORTS SÉRIE"

USB_PORTS=($(ls /dev/ttyUSB* 2>/dev/null | sort))
ACM_PORTS=($(ls /dev/ttyACM* 2>/dev/null | sort))
S_PORTS=($(ls /dev/ttyS* 2>/dev/null | sort))
AMA_PORTS=($(ls /dev/ttyAMA* 2>/dev/null | sort))

echo -e "${CYAN}📡 Scan complet des ports série:${NC}"
echo -e "${WHITE}   🔌 USB (ttyUSB*): ${#USB_PORTS[@]} port(s)${NC}"
echo -e "${WHITE}   🔌 ACM (ttyACM*): ${#ACM_PORTS[@]} port(s)${NC}"
echo -e "${WHITE}   🔌 Série (ttyS*): ${#S_PORTS[@]} port(s)${NC}"
echo -e "${WHITE}   🔌 UART (ttyAMA*): ${#AMA_PORTS[@]} port(s)${NC}"

# Combiner tous les ports pour analyse
ALL_PORTS=("${USB_PORTS[@]}" "${ACM_PORTS[@]}")

# Ajouter les ports système utilisables
for port in "${S_PORTS[@]}"; do
    if [[ "$port" == "/dev/ttyS0" ]] || [ -w "$port" ] 2>/dev/null; then
        ALL_PORTS+=("$port")
    fi
done

for port in "${AMA_PORTS[@]}"; do
    if [ -w "$port" ] 2>/dev/null; then
        ALL_PORTS+=("$port")
    fi
done

if [ ${#ALL_PORTS[@]} -eq 0 ]; then
    print_error "Aucun port série utilisable détecté!"
    exit 1
fi

print_info "Total des ports à analyser: ${#ALL_PORTS[@]}"

# Analyse des KERNELS pour chaque port
print_section "🎯 EXTRACTION DES KERNELS UNIQUES"

declare -A KERNEL_TO_PORT  # KERNEL -> Port
declare -A PORT_TO_KERNEL  # Port -> KERNEL
declare -A PORT_DETAILS    # Port -> Détails complets
declare -A KERNEL_DETAILS  # KERNEL -> Informations complètes

kernel_count=0

for port in "${ALL_PORTS[@]}"; do
    port_name=$(basename "$port")
    
    echo ""
    echo -e "${BOLD}${PURPLE}🔍 ANALYSE DU PORT: $port_name${NC}"
    echo -e "${PURPLE}$(printf '▔%.0s' {1..50})${NC}"
    
    # Extraire le KERNEL réel
    real_kernel=$(get_real_kernel "$port")
    
    if [ -n "$real_kernel" ] && [ "$real_kernel" != "unknown-$port_name" ]; then
        print_kernel "$real_kernel"
        kernel_count=$((kernel_count + 1))
        
        # Stocker les mappings
        KERNEL_TO_PORT["$real_kernel"]="$port_name"
        PORT_TO_KERNEL["$port_name"]="$real_kernel"
        
        # Récupérer les détails du port
        vendor_id=$(sudo udevadm info -a -n "$port" | grep 'ATTRS{idVendor}' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
        product_id=$(sudo udevadm info -a -n "$port" | grep 'ATTRS{idProduct}' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
        serial=$(sudo udevadm info -a -n "$port" | grep 'ATTRS{serial}' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
        driver=$(sudo udevadm info -a -n "$port" | grep 'DRIVERS==' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
        
        print_detail "Port: $port"
        print_detail "Vendor ID: $vendor_id"
        print_detail "Product ID: $product_id"
        print_detail "Driver: $driver"
        
        # Stocker les détails
        PORT_DETAILS["$port_name"]="$vendor_id:$product_id:$serial:$driver"
        KERNEL_DETAILS["$real_kernel"]="$port_name:$port:$vendor_id:$product_id:$serial:$driver"
        
        print_info "KERNEL '$real_kernel' → Port '$port_name' mappé avec succès"
    else
        print_warning "KERNEL non déterminable pour $port_name"
    fi
done

print_info "Total des KERNELS uniques identifiés: $kernel_count"

# Tableau de correspondance KERNEL ↔ PORT
print_section "📋 TABLEAU DE CORRESPONDANCE KERNEL ↔ PORT"

echo -e "${BOLD}${WHITE}Système de contrôle par position physique unique:${NC}"
echo ""
echo -e "${CYAN}┌─────────────────────────────────┬─────────────────┬─────────────────────┐${NC}"
echo -e "${CYAN}│${NC} ${BOLD}KERNEL (Position Unique)${NC}        ${CYAN}│${NC} ${BOLD}Port Actuel${NC}         ${CYAN}│${NC} ${BOLD}Chemin Complet${NC}      ${CYAN}│${NC}"
echo -e "${CYAN}├─────────────────────────────────┼─────────────────┼─────────────────────┤${NC}"

for kernel in $(printf '%s\n' "${!KERNEL_TO_PORT[@]}" | sort); do
    port_name="${KERNEL_TO_PORT[$kernel]}"
    details="${KERNEL_DETAILS[$kernel]}"
    full_path=$(echo "$details" | cut -d':' -f2)
    
    printf "${CYAN}│${NC} %-31s ${CYAN}│${NC} %-15s ${CYAN}│${NC} %-19s ${CYAN}│${NC}\n" "$kernel" "$port_name" "$full_path"
done

echo -e "${CYAN}└─────────────────────────────────┴─────────────────┴─────────────────────┘${NC}"

# Génération du système de contrôle
print_section "🎮 SYSTÈME DE CONTRÔLE PAR KERNEL"

echo -e "${CYAN}💡 Fonctions de contrôle générées:${NC}"
echo ""

# Créer le fichier de mapping
MAPPING_FILE="/tmp/kernel_port_mapping.conf"
echo "# Mapping KERNEL → PORT pour MediSense Pro" > "$MAPPING_FILE"
echo "# Généré automatiquement le $(date)" >> "$MAPPING_FILE"
echo "" >> "$MAPPING_FILE"

for kernel in $(printf '%s\n' "${!KERNEL_TO_PORT[@]}" | sort); do
    port_name="${KERNEL_TO_PORT[$kernel]}"
    details="${KERNEL_DETAILS[$kernel]}"
    full_path=$(echo "$details" | cut -d':' -f2)
    vendor_id=$(echo "$details" | cut -d':' -f3)
    product_id=$(echo "$details" | cut -d':' -f4)
    
    echo "[$kernel]" >> "$MAPPING_FILE"
    echo "PORT_NAME=$port_name" >> "$MAPPING_FILE"
    echo "FULL_PATH=$full_path" >> "$MAPPING_FILE"
    echo "VENDOR_ID=$vendor_id" >> "$MAPPING_FILE"
    echo "PRODUCT_ID=$product_id" >> "$MAPPING_FILE"
    echo "" >> "$MAPPING_FILE"
    
    echo -e "${WHITE}🎯 KERNEL: ${YELLOW}$kernel${NC}"
    echo -e "${WHITE}   └─ Port: $full_path${NC}"
    echo -e "${WHITE}   └─ Contrôle: get_port_by_kernel('$kernel')${NC}"
    echo ""
done

print_info "Mapping sauvegardé dans: $MAPPING_FILE"

# Créer les fonctions de contrôle
CONTROL_SCRIPT="/tmp/kernel_control_functions.sh"
cat > "$CONTROL_SCRIPT" << 'EOF'
#!/bin/bash

# Fonctions de contrôle des ports par KERNEL
# Source: source /tmp/kernel_control_functions.sh

# Charger le mapping KERNEL → PORT
declare -A KERNEL_MAP
declare -A PORT_MAP

load_kernel_mapping() {
    local mapping_file="/tmp/kernel_port_mapping.conf"
    
    if [ ! -f "$mapping_file" ]; then
        echo "❌ Fichier de mapping non trouvé: $mapping_file"
        return 1
    fi
    
    local current_kernel=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^\[(.+)\]$ ]]; then
            current_kernel="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^FULL_PATH=(.+)$ ]] && [ -n "$current_kernel" ]; then
            local full_path="${BASH_REMATCH[1]}"
            KERNEL_MAP["$current_kernel"]="$full_path"
            PORT_MAP["$(basename $full_path)"]="$current_kernel"
        fi
    done < "$mapping_file"
    
    echo "✅ Mapping chargé: ${#KERNEL_MAP[@]} KERNELS trouvés"
}

# Fonction: Obtenir le port par KERNEL
get_port_by_kernel() {
    local kernel="$1"
    
    if [ -z "$kernel" ]; then
        echo "❌ Usage: get_port_by_kernel <kernel>"
        return 1
    fi
    
    if [[ -n "${KERNEL_MAP[$kernel]}" ]]; then
        echo "${KERNEL_MAP[$kernel]}"
        return 0
    else
        echo "❌ KERNEL '$kernel' non trouvé"
        return 1
    fi
}

# Fonction: Obtenir le KERNEL par port
get_kernel_by_port() {
    local port="$1"
    
    if [ -z "$port" ]; then
        echo "❌ Usage: get_kernel_by_port <port>"
        return 1
    fi
    
    # Accepter le port avec ou sans /dev/
    local port_name=$(basename "$port")
    
    if [[ -n "${PORT_MAP[$port_name]}" ]]; then
        echo "${PORT_MAP[$port_name]}"
        return 0
    else
        echo "❌ Port '$port_name' non trouvé"
        return 1
    fi
}

# Fonction: Lister tous les KERNELs disponibles
list_all_kernels() {
    echo "🎯 KERNELs disponibles:"
    for kernel in "${!KERNEL_MAP[@]}"; do
        echo "   $kernel → ${KERNEL_MAP[$kernel]}"
    done
}

# Fonction: Tester un port par KERNEL
test_port_by_kernel() {
    local kernel="$1"
    local baudrate="${2:-9600}"
    
    local port=$(get_port_by_kernel "$kernel")
    if [ $? -eq 0 ]; then
        echo "🧪 Test du port $port (KERNEL: $kernel) à $baudrate baud..."
        
        if [ -w "$port" ]; then
            echo "✅ Port accessible en écriture"
            # Test basique
            timeout 2 bash -c "echo 'test' > $port" 2>/dev/null && echo "✅ Test d'écriture réussi" || echo "⚠️ Test d'écriture échoué"
        else
            echo "❌ Port non accessible en écriture"
        fi
    else
        echo "$port"  # Message d'erreur de get_port_by_kernel
    fi
}

# Fonction: Contrôler un capteur par KERNEL
control_sensor_by_kernel() {
    local kernel="$1"
    local command="$2"
    local baudrate="${3:-9600}"
    
    local port=$(get_port_by_kernel "$kernel")
    if [ $? -eq 0 ]; then
        echo "🎮 Contrôle du capteur sur $port (KERNEL: $kernel)"
        
        case "$command" in
            "read")
                echo "📖 Lecture des données..."
                timeout 3 python3 -c "
import serial
import time
try:
    ser = serial.Serial('$port', $baudrate, timeout=2)
    time.sleep(0.5)
    if ser.in_waiting > 0:
        data = ser.readline().decode('utf-8', errors='ignore').strip()
        print(f'📊 Données reçues: {data}')
    else:
        print('⚠️ Aucune donnée disponible')
    ser.close()
except Exception as e:
    print(f'❌ Erreur: {e}')
" 2>/dev/null
                ;;
            "info")
                echo "ℹ️ Informations du port:"
                ls -la "$port"
                ;;
            *)
                echo "❌ Commande inconnue. Utilisez: read, info"
                ;;
        esac
    else
        echo "$port"  # Message d'erreur
    fi
}

# Charger automatiquement le mapping au source
load_kernel_mapping
EOF

chmod +x "$CONTROL_SCRIPT"
print_info "Script de contrôle créé: $CONTROL_SCRIPT"

# Exemples d'utilisation
print_section "🎯 EXEMPLES D'UTILISATION"

echo -e "${CYAN}💡 Comment utiliser le système de contrôle par KERNEL:${NC}"
echo ""

echo -e "${WHITE}${BOLD}1. Charger les fonctions de contrôle:${NC}"
echo -e "${GREEN}   source /tmp/kernel_control_functions.sh${NC}"
echo ""

echo -e "${WHITE}${BOLD}2. Obtenir le port par KERNEL:${NC}"
for kernel in $(printf '%s\n' "${!KERNEL_TO_PORT[@]}" | sort | head -3); do
    port_name="${KERNEL_TO_PORT[$kernel]}"
    echo -e "${GREEN}   get_port_by_kernel '$kernel'${NC}  # Retourne: /dev/$port_name"
done
echo ""

echo -e "${WHITE}${BOLD}3. Contrôler un capteur par KERNEL:${NC}"
for kernel in $(printf '%s\n' "${!KERNEL_TO_PORT[@]}" | sort | head -2); do
    echo -e "${GREEN}   control_sensor_by_kernel '$kernel' read 57600${NC}"
done
echo ""

echo -e "${WHITE}${BOLD}4. Lister tous les KERNELs:${NC}"
echo -e "${GREEN}   list_all_kernels${NC}"

# Génération des règles udev basées sur les KERNELs
print_section "📝 RÈGLES UDEV PAR KERNEL"

echo -e "${CYAN}🔧 Règles udev pour fixer les ports par KERNEL:${NC}"
echo ""

for kernel in $(printf '%s\n' "${!KERNEL_TO_PORT[@]}" | sort); do
    port_name="${KERNEL_TO_PORT[$kernel]}"
    details="${KERNEL_DETAILS[$kernel]}"
    vendor_id=$(echo "$details" | cut -d':' -f3)
    product_id=$(echo "$details" | cut -d':' -f4)
    
    if [ "$vendor_id" != "N/A" ] && [ "$product_id" != "N/A" ]; then
        echo -e "${WHITE}# Règle pour KERNEL: $kernel → $port_name${NC}"
        echo -e "${GREEN}SUBSYSTEM==\"tty\", ATTRS{idVendor}==\"$vendor_id\", ATTRS{idProduct}==\"$product_id\", KERNELS==\"$kernel\", SYMLINK+=\"medisense_kernel_${kernel//[-.]/_}\"${NC}"
        echo ""
    fi
done

# Fin du script
print_section "✅ SYSTÈME KERNEL GÉNÉRÉ AVEC SUCCÈS"

echo -e "${BOLD}${GREEN}🎯 Résumé du système de contrôle par KERNEL:${NC}"
echo -e "${WHITE}   📊 ${#KERNEL_TO_PORT[@]} KERNEL(s) unique(s) identifié(s)${NC}"
echo -e "${WHITE}   🎮 Fonctions de contrôle générées${NC}"
echo -e "${WHITE}   📝 Règles udev prêtes${NC}"
echo ""
echo -e "${CYAN}🚀 Prochaines étapes:${NC}"
echo -e "${WHITE}   1. source /tmp/kernel_control_functions.sh${NC}"
echo -e "${WHITE}   2. get_port_by_kernel '<votre_kernel>'${NC}"
echo -e "${WHITE}   3. Intégrer dans votre code MediSense${NC}"
echo ""
echo -e "${BOLD}${BLUE}Système de contrôle par KERNEL prêt! 🎯${NC}"