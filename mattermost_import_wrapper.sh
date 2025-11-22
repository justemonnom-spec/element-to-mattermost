#!/bin/bash
################################################################################
# Script d'import Element.io → Mattermost
# Installation: /opt/mattermost/scripts/element-import.sh
#
# Usage (en tant que mattermost):
#   ./element-import.sh --team myteam export.json
#
# Prérequis:
#   - Script exécuté par l'utilisateur 'mattermost'
#   - mmctl configuré en mode local
#   - Python 3.7+
#   - element_to_mattermost.py dans le même dossier
################################################################################

set -euo pipefail  # Strict mode: exit on error, undefined var, pipe failure

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONVERTER_SCRIPT="${SCRIPT_DIR}/element_to_mattermost.py"
readonly WORK_DIR="/tmp/mattermost_import_$$"
readonly LOG_FILE="/var/log/mattermost/element_import.log"
readonly MATTERMOST_USER="mattermost"

################################################################################
# Fonctions utilitaires
################################################################################

log() {
    local msg="$1"
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $msg" | tee -a "$LOG_FILE"
}

log_error() {
    local msg="$1"
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ✗ ERREUR:${NC} $msg" | tee -a "$LOG_FILE" >&2
}

log_warning() {
    local msg="$1"
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ ATTENTION:${NC} $msg" | tee -a "$LOG_FILE"
}

log_info() {
    local msg="$1"
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] ℹ INFO:${NC} $msg" | tee -a "$LOG_FILE"
}

log_step() {
    local step="$1"
    local msg="$2"
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')] 📋 ${step}:${NC} $msg" | tee -a "$LOG_FILE"
}

cleanup() {
    if [ -d "$WORK_DIR" ]; then
        log_info "Nettoyage du répertoire temporaire..."
        rm -rf "$WORK_DIR" 2>/dev/null || true
    fi
}

trap cleanup EXIT INT TERM

show_banner() {
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║              Import Element.io → Mattermost                   ║
║                      Version 2.0                              ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo ""
}

check_user() {
    local current_user
    current_user=$(whoami)
    
    if [ "$current_user" != "$MATTERMOST_USER" ]; then
        log_error "Ce script DOIT être exécuté par l'utilisateur '$MATTERMOST_USER'"
        log_error "Utilisateur actuel: $current_user"
        echo ""
        echo "Solution:"
        echo "  sudo -u $MATTERMOST_USER $0 $*"
        exit 1
    fi
}

check_requirements() {
    log "Vérification des prérequis..."
    
    local errors=0
    
    # Python
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 non installé"
        ((errors++))
    else
        log_info "✓ Python: $(python3 --version)"
    fi
    
    # mmctl
    if ! command -v mmctl &> /dev/null; then
        log_error "mmctl non installé ou pas dans le PATH"
        ((errors++))
    else
        log_info "✓ mmctl: $(mmctl version 2>/dev/null | head -1 || echo 'version inconnue')"
    fi
    
    # Script Python
    if [ ! -f "$CONVERTER_SCRIPT" ]; then
        log_error "Script de conversion introuvable: $CONVERTER_SCRIPT"
        ((errors++))
    else
        log_info "✓ Script Python trouvé"
    fi
    
    # Zip
    if ! command -v zip &> /dev/null; then
        log_error "La commande 'zip' n'est pas installée"
        ((errors++))
    else
        log_info "✓ zip installé"
    fi
    
    # Dossier logs
    if [ ! -w "$(dirname "$LOG_FILE")" ]; then
        log_error "Impossible d'écrire dans $(dirname "$LOG_FILE")"
        ((errors++))
    else
        log_info "✓ Logs accessibles"
    fi
    
    if [ $errors -gt 0 ]; then
        log_error "$errors prérequis manquants"
        exit 1
    fi
    
    log "✓ Tous les prérequis sont satisfaits"
}

check_mmctl_local_mode() {
    log_info "Vérification du mode local mmctl..."
    
    # Tester si mmctl fonctionne en mode local
    if mmctl --local version &>/dev/null; then
        log_info "✓ mmctl en mode local opérationnel"
        return 0
    else
        log_warning "mmctl ne fonctionne pas en mode local"
        log_warning "Tentative d'activation..."
        
        # Essayer d'activer le mode local
        export MMCTL_LOCAL=true
        
        if mmctl --local version &>/dev/null; then
            log_info "✓ Mode local activé avec succès"
            echo 'export MMCTL_LOCAL=true' >> ~/.bashrc
            return 0
        else
            log_error "Impossible d'utiliser mmctl en mode local"
            log_error "Vérifiez la configuration de Mattermost (EnableLocalMode)"
            return 1
        fi
    fi
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] <fichier_element_json>

Convertit et importe un export Element.io dans Mattermost.

OPTIONS OBLIGATOIRES:
    -t, --team NAME         Nom de l'équipe Mattermost (sera créée si inexistante)

OPTIONS:
    -d, --data-dir DIR      Dossier contenant les médias Element
    -p, --password PASS     Mot de passe par défaut pour les utilisateurs
                            (défaut: ChangeMe123!)
    -o, --output FILE       Fichier JSONL de sortie (défaut: auto-généré)
    -n, --no-import         Conversion uniquement, pas d'import
    -h, --help              Afficher cette aide

EXEMPLES:
    # Import simple
    $0 --team myteam export_element.json
    
    # Avec médias
    $0 --team myteam --data-dir ./media export_element.json
    
    # Conversion seule (pour vérification)
    $0 --team myteam --no-import export_element.json

NOTES:
    - Le script DOIT être exécuté en tant qu'utilisateur '$MATTERMOST_USER'
    - Les logs sont dans: $LOG_FILE
    - Mode local mmctl requis (MMCTL_LOCAL=true)
    - L'équipe et les canaux seront créés automatiquement
    - Les utilisateurs seront créés avec le mot de passe par défaut

EOF
}

################################################################################
# Fonction principale d'import
################################################################################

process_import() {
    local input_file="$1"
    local team_name="$2"
    local data_dir="$3"
    local password="$4"
    local output_file="$5"
    local no_import="$6"
    
    # Vérifier que le fichier existe
    if [ ! -f "$input_file" ]; then
        log_error "Fichier d'entrée introuvable: $input_file"
        exit 1
    fi
    
    # Créer le répertoire de travail
    mkdir -p "$WORK_DIR"
    log_info "Répertoire de travail: $WORK_DIR"
    
    # Générer nom de fichier si non spécifié
    if [ -z "$output_file" ]; then
        output_file="${WORK_DIR}/import_${team_name}_$(date +%Y%m%d_%H%M%S).jsonl"
    fi
    
    # ========================================================================
    # Étape 1: Conversion Element → Mattermost JSONL
    # ========================================================================
    log_step "Étape 1/4" "Conversion Element → Mattermost JSONL"
    
    local convert_cmd="python3 \"$CONVERTER_SCRIPT\" \"$input_file\" --team \"$team_name\" --output \"$output_file\""
    
    if [ -n "$data_dir" ]; then
        convert_cmd="$convert_cmd --data-dir \"$data_dir\""
    fi
    
    if [ -n "$password" ]; then
        convert_cmd="$convert_cmd --password \"$password\""
    fi
    
    log_info "Commande: $convert_cmd"
    
    if ! eval $convert_cmd >> "$LOG_FILE" 2>&1; then
        log_error "Échec de la conversion"
        log_error "Consultez les logs: $LOG_FILE"
        exit 1
    fi
    
    if [ ! -f "$output_file" ]; then
        log_error "Le fichier $output_file n'a pas été créé"
        exit 1
    fi
    
    log "✓ Conversion réussie: $output_file"
    log_info "Taille: $(du -h "$output_file" | cut -f1)"
    
    # ========================================================================
    # Étape 2: Création de l'archive ZIP
    # ========================================================================
    log_step "Étape 2/4" "Création de l'archive ZIP"
    
    cd "$WORK_DIR" || exit 1
    
    local zip_file="import_${team_name}_$(date +%Y%m%d_%H%M%S).zip"
    
    if [ -d "mattermost_data" ]; then
        log_info "Inclusion des fichiers média..."
        zip -q -r "$zip_file" "$(basename "$output_file")" mattermost_data/
    else
        zip -q "$zip_file" "$(basename "$output_file")"
    fi
    
    if [ ! -f "$zip_file" ]; then
        log_error "Échec de la création de l'archive"
        exit 1
    fi
    
    log "✓ Archive créée: $zip_file"
    log_info "Taille: $(du -h "$zip_file" | cut -f1)"
    
    # Si mode conversion seule, s'arrêter ici
    if [ "$no_import" = true ]; then
        log_info "Mode conversion seule activé - import non effectué"
        log_info "Archive disponible: ${WORK_DIR}/${zip_file}"
        log_info ""
        log_info "Pour importer manuellement:"
        log_info "  cd $WORK_DIR"
        log_info "  mmctl --local import process --bypass-upload $zip_file"
        exit 0
    fi
    
    # ========================================================================
    # Étape 3: Import dans Mattermost avec mmctl
    # ========================================================================
    log_step "Étape 3/4" "Import dans Mattermost"
    log_warning "Ceci peut prendre du temps selon la taille des données..."
    
    # Utiliser --bypass-upload pour import local direct (pas de validation séparée)
    local import_output
    import_output=$(mmctl --local import process --bypass-upload "$zip_file" 2>&1 | tee -a "$LOG_FILE")
    
    # Extraire le Job ID
    local job_id
    job_id=$(echo "$import_output" | grep -oP 'ID: \K[a-z0-9]+' | head -1 || echo "")
    
    if [ -z "$job_id" ]; then
        log_error "Impossible d'extraire le Job ID de l'import"
        log_error "Sortie mmctl:"
        echo "$import_output" | tee -a "$LOG_FILE"
        log_info ""
        log_info "L'import a peut-être échoué. Vérifiez manuellement:"
        log_info "  mmctl --local import job list"
        exit 1
    fi
    
    log "✓ Job d'import créé: $job_id"
    
    # ========================================================================
    # Étape 4: Suivi de la progression
    # ========================================================================
    log_step "Étape 4/4" "Suivi de la progression"
    
    local status="pending"
    local attempts=0
    local max_attempts=600  # 10 minutes max (600 * 1s)
    local last_status=""
    
    while [ "$status" != "success" ] && [ "$status" != "error" ] && [ "$status" != "canceled" ] && [ "$attempts" -lt "$max_attempts" ]; do
        sleep 1
        ((attempts++))
        
        # Récupérer le statut
        local job_info
        job_info=$(mmctl --local import job show "$job_id" 2>/dev/null || echo "")
        
        if [ -n "$job_info" ]; then
            status=$(echo "$job_info" | grep "Status:" | awk '{print $2}' || echo "unknown")
            
            # Afficher la progression tous les 10 secondes
            if [ "$status" != "$last_status" ] || [ $((attempts % 10)) -eq 0 ]; then
                log_info "Statut: $status (${attempts}s écoulées)"
                last_status="$status"
            fi
        fi
    done
    
    # Vérifier le résultat final
    if [ "$status" = "success" ]; then
        log ""
        log "✅ Import terminé avec succès!"
        log ""
        
        # Afficher les détails
        mmctl --local import job show "$job_id" | tee -a "$LOG_FILE"
        
        log ""
        log "🎉 Migration terminée!"
        log ""
        log "Prochaines étapes:"
        log "  1. Connectez-vous à Mattermost"
        log "  2. Vérifiez l'équipe: $team_name"
        log "  3. Les utilisateurs peuvent se connecter avec:"
        log "     - Mot de passe: ${password:-ChangeMe123!}"
        log "     - Email: <username>@imported.local"
        
    elif [ "$status" = "error" ]; then
        log_error "Import échoué"
        log_error "Détails du job:"
        mmctl --local import job show "$job_id" | tee -a "$LOG_FILE"
        exit 1
        
    elif [ "$status" = "canceled" ]; then
        log_error "Import annulé"
        exit 1
        
    else
        log_warning "Timeout atteint (${max_attempts}s)"
        log_warning "Statut actuel: $status"
        log_info "Vérifiez manuellement:"
        log_info "  mmctl --local import job show $job_id"
        exit 1
    fi
}

################################################################################
# Script principal
################################################################################

main() {
    show_banner
    
    # Vérifier l'utilisateur en premier
    check_user "$@"
    
    # Créer le fichier de log si nécessaire
    touch "$LOG_FILE" 2>/dev/null || {
        echo "ERREUR: Impossible de créer $LOG_FILE"
        echo "Vérifiez les permissions du dossier $(dirname "$LOG_FILE")"
        exit 1
    }
    
    log "Démarrage de l'import Element.io → Mattermost"
    log "Utilisateur: $(whoami)"
    log "PID: $$"
    
    # Vérifier les prérequis
    check_requirements
    check_mmctl_local_mode || exit 1
    
    # Parser les arguments
    local input_file=""
    local team_name=""
    local data_dir=""
    local password=""
    local output_file=""
    local no_import=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--team)
                team_name="$2"
                shift 2
                ;;
            -d|--data-dir)
                data_dir="$2"
                shift 2
                ;;
            -p|--password)
                password="$2"
                shift 2
                ;;
            -o|--output)
                output_file="$2"
                shift 2
                ;;
            -n|--no-import)
                no_import=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                log_error "Option inconnue: $1"
                echo ""
                show_usage
                exit 1
                ;;
            *)
                if [ -z "$input_file" ]; then
                    input_file="$1"
                else
                    log_error "Argument supplémentaire inattendu: $1"
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Vérifier les arguments obligatoires
    if [ -z "$input_file" ]; then
        log_error "Fichier d'entrée manquant"
        echo ""
        show_usage
        exit 1
    fi
    
    if [ -z "$team_name" ]; then
        log_error "Nom d'équipe manquant (--team)"
        echo ""
        show_usage
        exit 1
    fi
    
    # Lancer l'import
    process_import "$input_file" "$team_name" "$data_dir" "$password" "$output_file" "$no_import"
}

# Lancer le script
main "$@"
