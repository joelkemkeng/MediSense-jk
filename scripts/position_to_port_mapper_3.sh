#!/bin/bash

# Script de mapping Position Physique → Port USB
# Prend en paramètre une position physique et retourne le port correspondant
# Auteur: MediSense Team
# Usage: bash position_mapper.sh <position_physique>
# Exemple: bash position_mapper.sh 1-1.4.2

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

# Fonction d'aide
show_help() {
    echo -e "${BOLD}${CYAN}📖 AIDE - Mapper Position Physique vers Port USB${NC}"
    echo ""
    echo -e "${WHITE}Usage:${NC}"
    echo -e "${GREEN}   bash position_mapper.sh <position_physique>${NC}"
    echo ""
    echo -e "${WHITE}Exemples:${NC}"
    echo -e "${YELLOW}   bash position_mapper.sh 1-1.4.2${NC}"
    echo -e "${YELLOW}   bash position_mapper.sh 1-1.4.3${NC}"
    echo ""
    echo -e "${WHITE}Options:${NC}"
    echo -e "${CYAN}   --list     : Lister toutes les positions disponibles${NC}"
    echo -e "${CYAN}   --help     : Afficher cette aide${NC}"
    echo ""
    echo -e "${WHITE}Sortie:${NC}"
    echo -e "${WHITE}   Le script retourne le nom du port (ex: ttyUSB0) correspondant${NC}"
    echo -e "${WHITE}   à la position physique spécifiée${NC}"
}

# Fonction pour lister toutes les positions
list_all_positions() {
    print_header "📍 LISTE DES POSITIONS PHYSIQUES DISPONIBLES"
    
    # Obtenir tous les ports
    USB_PORTS=($(ls /dev/ttyUSB* 2>/dev/null | sort))
    ACM_PORTS=($(ls /dev/ttyACM* 2>/dev/null | sort))
    ALL_PORTS=("${USB_PORTS[@]}" "${ACM_PORTS[@]}")
    
    if [ ${#ALL_PORTS[@]} -eq 0 ]; then
        print_error "Aucun port USB/ACM détecté!"
        return 1
    fi
    
    declare -A POSITIONS
    
    echo -e "${CYAN}Positions physiques actuellement disponibles:${NC}"
    echo ""
    
    for port in "${ALL_PORTS[@]}"; do
        port_name=$(basename "$port")
        kernels=$(sudo udevadm info -a -n "$port" | grep 'KERNELS==' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
        
        if [ "$kernels" != "N/A" ]; then
            POSITIONS["$kernels"]="$port_name"
        fi
    done
    
    # Afficher le tableau
    echo -e "${CYAN}┌─────────────────────────────┬─────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${BOLD}Position Physique${NC}           ${CYAN}│${NC} ${BOLD}Port Actuel${NC}         ${CYAN}│${NC}"
    echo -e "${CYAN}├─────────────────────────────┼─────────────────┤${NC}"
    
    for kernels in $(printf '%s\n' "${!POSITIONS[@]}" | sort); do
        port_name="${POSITIONS[$kernels]}"
        printf "${CYAN}│${NC} %-27s ${CYAN}│${NC} %-15s ${CYAN}│${NC}\n" "$kernels" "$port_name"
    done
    
    echo -e "${CYAN}└─────────────────────────────┴─────────────────┘${NC}"
    echo ""
    echo -e "${WHITE}💡 Utilisez une de ces positions avec:${NC}"
    echo -e "${GREEN}   bash position_mapper.sh <position>${NC}"
}

# Fonction principale de mapping
map_position_to_port() {
    local target_position="$1"
    
    print_header "🔍 RECHERCHE DE LA POSITION: $target_position"
    
    # Obtenir tous les ports
    USB_PORTS=($(ls /dev/ttyUSB* 2>/dev/null | sort))
    ACM_PORTS=($(ls /dev/ttyACM* 2>/dev/null | sort))
    ALL_PORTS=("${USB_PORTS[@]}" "${ACM_PORTS[@]}")
    
    if [ ${#ALL_PORTS[@]} -eq 0 ]; then
        print_error "Aucun port USB/ACM détecté!"
        return 1
    fi
    
    echo -e "${CYAN}🔍 Recherche de la position physique: ${BOLD}$target_position${NC}"
    echo ""
    
    # Chercher la position dans tous les ports
    found_port=""
    found_details=""
    
    for port in "${ALL_PORTS[@]}"; do
        port_name=$(basename "$port")
        kernels=$(sudo udevadm info -a -n "$port" | grep 'KERNELS==' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
        
        if [ "$kernels" = "$target_position" ]; then
            found_port="$port_name"
            found_details="$port"
            break
        fi
    done
    
    if [ -n "$found_port" ]; then
        print_info "Position trouvée!"
        echo ""
        echo -e "${BOLD}${GREEN}📱 RÉSULTAT:${NC}"
        echo -e "${WHITE}   Position physique: ${CYAN}$target_position${NC}"
        echo -e "${WHITE}   Port correspondant: ${YELLOW}$found_port${NC}"
        echo -e "${WHITE}   Chemin complet: ${GREEN}$found_details${NC}"
        
        # Informations supplémentaires
        echo ""
        echo -e "${CYAN}📋 Informations supplémentaires:${NC}"
        
        vendor_id=$(sudo udevadm info -a -n "$found_details" | grep 'ATTRS{idVendor}' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
        product_id=$(sudo udevadm info -a -n "$found_details" | grep 'ATTRS{idProduct}' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
        serial=$(sudo udevadm info -a -n "$found_details" | grep 'ATTRS{serial}' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
        
        print_detail "Vendor ID: $vendor_id"
        print_detail "Product ID: $product_id"
        print_detail "Numéro de série: $serial"
        
        # Vérifier les permissions
        if [ -r "$found_details" ] && [ -w "$found_details" ]; then
            print_detail "Permissions: Lecture/Écriture OK"
        else
            print_warning "Permissions insuffisantes sur $found_details"
            echo -e "${WHITE}   Utilisez: ${YELLOW}sudo usermod -a -G dialout \$USER${NC}"
        fi
        
        echo ""
        echo -e "${BOLD}${GREEN}🎯 Port à utiliser: $found_port${NC}"
        
        # Sortie pour utilisation dans d'autres scripts
        echo ""
        echo -e "${CYAN}📤 Sortie pour script:${NC}"
        echo "$found_port"
        
        return 0
    else
        print_error "Position physique '$target_position' non trouvée!"
        echo ""
        echo -e "${CYAN}🔍 Positions disponibles:${NC}"
        
        for port in "${ALL_PORTS[@]}"; do
            port_name=$(basename "$port")
            kernels=$(sudo udevadm info -a -n "$port" | grep 'KERNELS==' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
            
            if [ "$kernels" != "N/A" ]; then
                echo -e "${WHITE}   • $kernels → $port_name${NC}"
            fi
        done
        
        echo ""
        print_warning "Vérifiez que la position physique est correcte"
        return 1
    fi
}

# Fonction pour mapper plusieurs positions en une fois
batch_mapping() {
    local positions=("$@")
    
    print_header "📍 MAPPING MULTIPLE DE POSITIONS"
    
    echo -e "${CYAN}Mapping de ${#positions[@]} position(s):${NC}"
    echo ""
    
    declare -A results
    
    for position in "${positions[@]}"; do
        echo -e "${WHITE}🔍 Recherche: $position${NC}"
        
        # Obtenir tous les ports
        USB_PORTS=($(ls /dev/ttyUSB* 2>/dev/null | sort))
        ACM_PORTS=($(ls /dev/ttyACM* 2>/dev/null | sort))
        ALL_PORTS=("${USB_PORTS[@]}" "${ACM_PORTS[@]}")
        
        found_port=""
        for port in "${ALL_PORTS[@]}"; do
            port_name=$(basename "$port")
            kernels=$(sudo udevadm info -a -n "$port" | grep 'KERNELS==' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
            
            if [ "$kernels" = "$position" ]; then
                found_port="$port_name"
                break
            fi
        done
        
        if [ -n "$found_port" ]; then
            results["$position"]="$found_port"
            echo -e "${GREEN}   ✅ $position → $found_port${NC}"
        else
            results["$position"]="NOT_FOUND"
            echo -e "${RED}   ❌ $position → Non trouvé${NC}"
        fi
    done
    
    echo ""
    echo -e "${BOLD}${CYAN}📋 RÉSUMÉ DU MAPPING:${NC}"
    echo -e "${CYAN}┌─────────────────────────────┬─────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${BOLD}Position Physique${NC}           ${CYAN}│${NC} ${BOLD}Port Trouvé${NC}         ${CYAN}│${NC}"
    echo -e "${CYAN}├─────────────────────────────┼─────────────────┤${NC}"
    
    for position in "${positions[@]}"; do
        port_result="${results[$position]}"
        if [ "$port_result" = "NOT_FOUND" ]; then
            printf "${CYAN}│${NC} %-27s ${CYAN}│${NC} ${RED}%-15s${NC} ${CYAN}│${NC}\n" "$position" "Non trouvé"
        else
            printf "${CYAN}│${NC} %-27s ${CYAN}│${NC} ${GREEN}%-15s${NC} ${CYAN}│${NC}\n" "$position" "$port_result"
        fi
    done
    
    echo -e "${CYAN}└─────────────────────────────┴─────────────────┘${NC}"
}

# Script principal
main() {
    # Vérifier les arguments
    if [ $# -eq 0 ]; then
        print_error "Aucun argument fourni!"
        echo ""
        show_help
        exit 1
    fi
    
    case "$1" in
        "--help"|"-h")
            show_help
            exit 0
            ;;
        "--list"|"-l")
            list_all_positions
            exit 0
            ;;
        *)
            if [ $# -eq 1 ]; then
                # Mapping d'une seule position
                map_position_to_port "$1"
            else
                # Mapping multiple
                batch_mapping "$@"
            fi
            ;;
    esac
}

# Exécuter le script principal
main "$@"