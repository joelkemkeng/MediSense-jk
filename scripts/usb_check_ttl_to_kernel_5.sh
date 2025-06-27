#!/bin/bash

# Script pour Raspberry Pi : Obtenir le port série par KERNEL
# Usage: ./get_port_by_kernel.sh <kernel_number>
# Exemple: ./get_port_by_kernel.sh 1-1.4
# Auteur: Expert Raspberry Pi Assistant
# Compatible: Raspberry Pi OS, Ubuntu, Debian

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Fonction d'aide
show_help() {
    echo -e "${BOLD}${BLUE}🎯 Script de récupération de port par KERNEL - Raspberry Pi${NC}"
    echo ""
    echo -e "${CYAN}Usage:${NC}"
    echo -e "  $0 <kernel_number>     # Obtenir le port associé au KERNEL"
    echo -e "  $0 --list              # Lister tous les KERNELs disponibles"
    echo -e "  $0 --help              # Afficher cette aide"
    echo ""
    echo -e "${CYAN}Exemples:${NC}"
    echo -e "  $0 1-1.4               # Chercher le port pour KERNEL 1-1.4"
    echo -e "  $0 1-1.2               # Chercher le port pour KERNEL 1-1.2"
    echo -e "  $0 --list              # Voir tous les KERNELs disponibles"
    echo ""
    echo -e "${YELLOW}Note: Ce script détecte automatiquement ttyUSB*, ttyACM*, ttyS*, ttyAMA* sur Raspberry Pi${NC}"
}

# Fonction pour lister tous les KERNELs disponibles
list_all_kernels() {
    echo -e "${BOLD}${CYAN}🔍 Scan des ports série et leurs KERNELs sur Raspberry Pi:${NC}"
    echo ""
    
    # Types de ports série sur Raspberry Pi
    local port_types=("ttyUSB" "ttyACM" "ttyS" "ttyAMA")
    local found_ports=()
    
    # Collecter tous les ports disponibles
    for port_type in "${port_types[@]}"; do
        local ports=($(ls /dev/${port_type}* 2>/dev/null | sort))
        found_ports+=("${ports[@]}")
    done
    
    if [ ${#found_ports[@]} -eq 0 ]; then
        echo -e "${RED}❌ Aucun port série détecté sur cette Raspberry Pi${NC}"
        return 1
    fi
    
    echo -e "${GREEN}📊 ${#found_ports[@]} port(s) détecté(s):${NC}"
    echo -e "${BLUE}┌────────────────────┬────────────────────────────┬─────────────────┐${NC}"
    echo -e "${BLUE}│${NC} ${BOLD}Port${NC}               ${BLUE}│${NC} ${BOLD}KERNEL${NC}                     ${BLUE}│${NC} ${BOLD}Informations${NC}    ${BLUE}│${NC}"
    echo -e "${BLUE}├────────────────────┼────────────────────────────┼─────────────────┤${NC}"
    
    for port in "${found_ports[@]}"; do
        local port_name=$(basename "$port")
        local kernel=$(get_kernel_for_port "$port")
        local device_info="N/A"
        
        # Obtenir les informations du périphérique
        local vendor_id=$(sudo udevadm info -a -n "$port" 2>/dev/null | grep 'ATTRS{idVendor}' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
        local product_id=$(sudo udevadm info -a -n "$port" 2>/dev/null | grep 'ATTRS{idProduct}' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
        
        if [ "$vendor_id" != "N/A" ] && [ "$product_id" != "N/A" ]; then
            device_info="${vendor_id}:${product_id}"
        fi
        
        printf "${BLUE}│${NC} %-18s ${BLUE}│${NC} %-26s ${BLUE}│${NC} %-15s ${BLUE}│${NC}\n" "$port_name" "$kernel" "$device_info"
    done
    
    echo -e "${BLUE}└────────────────────┴────────────────────────────┴─────────────────┘${NC}"
}

# Fonction pour obtenir le KERNEL d'un port
get_kernel_for_port() {
    local port="$1"
    local kernel=""
    
    # Méthode 1: KERNELS direct via udevadm
    kernel=$(sudo udevadm info -a -n "$port" 2>/dev/null | grep 'KERNELS==' | head -1 | cut -d'"' -f2 2>/dev/null || echo "")
    
    # Si le KERNELS est vide ou identique au nom du port, essayer d'autres méthodes
    if [ -z "$kernel" ] || [ "$kernel" = "$(basename $port)" ]; then
        # Méthode 2: Extraire du chemin du périphérique
        local devpath=$(sudo udevadm info -a -n "$port" 2>/dev/null | grep 'looking at device' | head -1 | cut -d"'" -f2 2>/dev/null || echo "")
        
        # Rechercher un pattern USB dans le chemin
        if [[ "$devpath" =~ ([0-9]+-[0-9]+(\.[0-9]+)*) ]]; then
            kernel="${BASH_REMATCH[1]}"
        else
            # Méthode 3: Analyser la hiérarchie USB
            local parent_devpath=$(sudo udevadm info -a -n "$port" 2>/dev/null | grep 'looking at parent device' | head -1 | cut -d"'" -f2 2>/dev/null || echo "")
            if [[ "$parent_devpath" =~ ([0-9]+-[0-9]+(\.[0-9]+)*) ]]; then
                kernel="${BASH_REMATCH[1]}"
            else
                kernel="unknown"
            fi
        fi
    fi
    
    echo "$kernel"
}

# Fonction principale pour obtenir le port par KERNEL
get_port_by_kernel() {
    local target_kernel="$1"
    
    if [ -z "$target_kernel" ]; then
        echo -e "${RED}❌ Erreur: KERNEL non spécifié${NC}" >&2
        return 1
    fi
    
    # Types de ports série sur Raspberry Pi
    local port_types=("ttyUSB" "ttyACM" "ttyS" "ttyAMA")
    local found_ports=()
    
    # Collecter tous les ports disponibles
    for port_type in "${port_types[@]}"; do
        local ports=($(ls /dev/${port_type}* 2>/dev/null | sort))
        found_ports+=("${ports[@]}")
    done
    
    if [ ${#found_ports[@]} -eq 0 ]; then
        echo -e "${RED}❌ Aucun port série disponible sur cette Raspberry Pi${NC}" >&2
        return 1
    fi
    
    # Rechercher le KERNEL correspondant
    local matching_port=""
    local kernel_found=false
    
    for port in "${found_ports[@]}"; do
        local port_kernel=$(get_kernel_for_port "$port")
        
        if [ "$port_kernel" = "$target_kernel" ]; then
            matching_port="$port"
            kernel_found=true
            break
        fi
    done
    
    if [ "$kernel_found" = true ]; then
        # Retourner juste le chemin du port (pour faciliter l'utilisation en script)
        echo "$matching_port"
        return 0
    else
        echo -e "${RED}❌ KERNEL '$target_kernel' non trouvé${NC}" >&2
        echo -e "${YELLOW}💡 Utilisez '$0 --list' pour voir tous les KERNELs disponibles${NC}" >&2
        return 1
    fi
}

# Fonction pour obtenir des informations détaillées sur un port
get_port_details() {
    local target_kernel="$1"
    local port=$(get_port_by_kernel "$target_kernel" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$port" ]; then
        echo -e "${BOLD}${GREEN}🎯 Détails pour KERNEL '$target_kernel':${NC}"
        echo -e "${CYAN}┌─────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│${NC} ${BOLD}Port trouvé:${NC} $port"
        
        # Informations udev
        local vendor_id=$(sudo udevadm info -a -n "$port" 2>/dev/null | grep 'ATTRS{idVendor}' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
        local product_id=$(sudo udevadm info -a -n "$port" 2>/dev/null | grep 'ATTRS{idProduct}' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
        local serial=$(sudo udevadm info -a -n "$port" 2>/dev/null | grep 'ATTRS{serial}' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
        local driver=$(sudo udevadm info -a -n "$port" 2>/dev/null | grep 'DRIVERS==' | head -1 | cut -d'"' -f2 2>/dev/null || echo "N/A")
        
        echo -e "${CYAN}│${NC} ${BOLD}Vendor ID:${NC} $vendor_id"
        echo -e "${CYAN}│${NC} ${BOLD}Product ID:${NC} $product_id"
        echo -e "${CYAN}│${NC} ${BOLD}Serial:${NC} $serial"
        echo -e "${CYAN}│${NC} ${BOLD}Driver:${NC} $driver"
        
        # Test d'accessibilité
        if [ -r "$port" ] && [ -w "$port" ]; then
            echo -e "${CYAN}│${NC} ${BOLD}Accessibilité:${NC} ${GREEN}✅ Lecture/Écriture${NC}"
        elif [ -r "$port" ]; then
            echo -e "${CYAN}│${NC} ${BOLD}Accessibilité:${NC} ${YELLOW}⚠️ Lecture seule${NC}"
        else
            echo -e "${CYAN}│${NC} ${BOLD}Accessibilité:${NC} ${RED}❌ Aucun accès${NC}"
        fi
        
        echo -e "${CYAN}└─────────────────────────────────────────────────────────────┘${NC}"
    else
        echo -e "${RED}❌ KERNEL '$target_kernel' non trouvé${NC}" >&2
        return 1
    fi
}

# Script principal
main() {
    # Vérifier si on est sur Raspberry Pi
    if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null && ! grep -q "BCM" /proc/cpuinfo 2>/dev/null; then
        echo -e "${YELLOW}⚠️ Ce script est optimisé pour Raspberry Pi, mais fonctionne sur d'autres systèmes Linux${NC}" >&2
    fi
    
    case "${1:-}" in
        "--help"|"-h"|"")
            show_help
            ;;
        "--list"|"-l")
            list_all_kernels
            ;;
        "--details"|"-d")
            if [ -z "$2" ]; then
                echo -e "${RED}❌ Erreur: Spécifiez un KERNEL pour obtenir les détails${NC}" >&2
                echo -e "${CYAN}Usage: $0 --details <kernel_number>${NC}" >&2
                exit 1
            fi
            get_port_details "$2"
            ;;
        *)
            # Mode normal: retourner le port pour le KERNEL donné
            get_port_by_kernel "$1"
            ;;
    esac
}

# Exécuter le script principal
main "$@"