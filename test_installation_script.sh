#!/bin/bash
################################################################################
# Script de tests automatisés - Installation Element Import
# Vérifie que tous les composants sont correctement installés et fonctionnels
#
# Usage: ./test_installation.sh
################################################################################

set -euo pipefail

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Compteurs
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNING=0

################################################################################
# Fonctions utilitaires
################################################################################

print_header() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║  $1"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
}

test_start() {
    echo -n "  [TEST] $1... "
}

test_pass() {
    echo -e "${GREEN}✓ OK${NC}"
    ((TESTS_PASSED++))
}

test_fail() {
    echo -e "${RED}✗ ÉCHEC${NC}"
    if [ -n "${1:-}" ]; then
        echo -e "         ${RED}↳ $1${NC}"
    fi
    ((TESTS_FAILED++))
}

test_warning() {
    echo -e "${YELLOW}⚠ ATTENTION${NC}"
    if [ -n "${1:-}" ]; then
        echo -e "         ${YELLOW}↳ $1${NC}"
    fi
    ((TESTS_WARNING++))
}

################################################################################
# Tests du système
################################################################################

test_system() {
    print_header "Tests du système"
    
    # OS
    test_start "Système d'exploitation"
    if [ -f /etc/os-release ]; then
        OS_NAME=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
        test_pass
        echo "         → $OS_NAME"
    else
        test_fail "Impossible de déterminer l'OS"
    fi
    
    # Architecture
    test_start "Architecture"
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        test_pass
        echo "         → $ARCH"
    else
        test_warning "Architecture non standard: $ARCH"
    fi
    
    # Utilisateur
    test_start "Utilisateur actuel"
    CURRENT_USER=$(whoami)
    if [ "$CURRENT_USER" = "mattermost" ]; then
        test_pass
        echo "         → $CURRENT_USER"
    else
        test_warning "Devrait être exécuté en tant que 'mattermost', actuel: $CURRENT_USER"
    fi
    
    # Espace disque
    test_start "Espace disque disponible"
    DISK_AVAIL=$(df -BG /opt/mattermost | tail -1 | awk '{print $4}' | sed 's/G//')
    if [ "$DISK_AVAIL" -gt 5 ]; then
        test_pass
        echo "         → ${DISK_AVAIL}G disponible"
    else
        test_warning "Peu d'espace disque: ${DISK_AVAIL}G"
    fi
}

################################################################################
# Tests des dépendances
################################################################################

test_dependencies() {
    print_header "Tests des dépendances"
    
    # Python
    test_start "Python 3"
    if command -v python3 &> /dev/null; then
        PY_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
        PY_MAJOR=$(echo "$PY_VERSION" | cut -d'.' -f1)
        PY_MINOR=$(echo "$PY_VERSION" | cut -d'.' -f2)
        
        if [ "$PY_MAJOR" -ge 3 ] && [ "$PY_MINOR" -ge 7 ]; then
            test_pass
            echo "         → Version $PY_VERSION"
        else
            test_fail "Version trop ancienne: $PY_VERSION (requis: 3.7+)"
        fi
    else
        test_fail "Python 3 non installé"
    fi
    
    # mmctl
    test_start "mmctl"
    if command -v mmctl &> /dev/null; then
        MMCTL_VERSION=$(mmctl version 2>&1 | head -1 || echo "version inconnue")
        test_pass
        echo "         → $MMCTL_VERSION"
    else
        test_fail "mmctl non installé"
    fi
    
    # zip
    test_start "zip"
    if command -v zip &> /dev/null; then
        test_pass
    else
        test_fail "La commande 'zip' n'est pas installée"
    fi
    
    # Flask (pour interface web)
    test_start "Flask (optionnel)"
    if python3 -c "import flask" 2>/dev/null; then
        FLASK_VERSION=$(python3 -c "import flask; print(flask.__version__)" 2>/dev/null)
        test_pass
        echo "         → Version $FLASK_VERSION"
    else
        test_warning "Flask non installé (requis pour l'interface web)"
    fi
}

################################################################################
# Tests des fichiers et dossiers
################################################################################

test_files() {
    print_header "Tests des fichiers et dossiers"
    
    # Dossier scripts
    test_start "Dossier /opt/mattermost/scripts"
    if [ -d "/opt/mattermost/scripts" ]; then
        test_pass
        
        # Permissions
        test_start "  Permissions du dossier scripts"
        OWNER=$(stat -c '%U:%G' /opt/mattermost/scripts)
        if [ "$OWNER" = "mattermost:mattermost" ]; then
            test_pass
        else
            test_fail "Propriétaire incorrect: $OWNER (attendu: mattermost:mattermost)"
        fi
    else
        test_fail "Dossier manquant"
    fi
    
    # Script Python de conversion
    test_start "Script element_to_mattermost.py"
    if [ -f "/opt/mattermost/scripts/element_to_mattermost.py" ]; then
        test_pass
        
        # Exécutable
        test_start "  Permissions d'exécution"
        if [ -x "/opt/mattermost/scripts/element_to_mattermost.py" ]; then
            test_pass
        else
            test_warning "Script non exécutable"
        fi
        
        # Test syntaxe
        test_start "  Syntaxe Python"
        if python3 -m py_compile /opt/mattermost/scripts/element_to_mattermost.py 2>/dev/null; then
            test_pass
        else
            test_fail "Erreur de syntaxe Python"
        fi
    else
        test_fail "Fichier manquant"
    fi
    
    # Script Bash principal
    test_start "Script element-import.sh"
    if [ -f "/opt/mattermost/scripts/element-import.sh" ]; then
        test_pass
        
        # Exécutable
        test_start "  Permissions d'exécution"
        if [ -x "/opt/mattermost/scripts/element-import.sh" ]; then
            test_pass
        else
            test_fail "Script non exécutable"
        fi
        
        # Test syntaxe
        test_start "  Syntaxe Bash"
        if bash -n /opt/mattermost/scripts/element-import.sh 2>/dev/null; then
            test_pass
        else
            test_fail "Erreur de syntaxe Bash"
        fi
    else
        test_fail "Fichier manquant"
    fi
    
    # Dossier logs
    test_start "Dossier /var/log/mattermost"
    if [ -d "/var/log/mattermost" ]; then
        test_pass
        
        # Permissions d'écriture
        test_start "  Permissions d'écriture"
        if [ -w "/var/log/mattermost" ]; then
            test_pass
        else
            test_fail "Pas de permissions d'écriture"
        fi
    else
        test_fail "Dossier manquant"
    fi
    
    # Interface web (optionnel)
    test_start "Interface web element_import_web.py (optionnel)"
    if [ -f "/opt/mattermost/scripts/element_import_web.py" ]; then
        test_pass
        
        test_start "  Syntaxe Python"
        if python3 -m py_compile /opt/mattermost/scripts/element_import_web.py 2>/dev/null; then
            test_pass
        else
            test_fail "Erreur de syntaxe Python"
        fi
    else
        test_warning "Interface web non installée"
    fi
}

################################################################################
# Tests de configuration
################################################################################

test_configuration() {
    print_header "Tests de configuration"
    
    # mmctl mode local
    test_start "mmctl mode local"
    export MMCTL_LOCAL=true
    if mmctl --local version &>/dev/null; then
        test_pass
    else
        test_fail "Mode local non fonctionnel"
    fi
    
    # Connexion Mattermost
    test_start "Connexion au serveur Mattermost"
    if mmctl --local team list &>/dev/null; then
        test_pass
        TEAM_COUNT=$(mmctl --local team list 2>/dev/null | wc -l)
        echo "         → $TEAM_COUNT équipes trouvées"
    else
        test_fail "Impossible de se connecter au serveur"
    fi
    
    # Variables d'environnement
    test_start "Variable MMCTL_LOCAL"
    if [ "${MMCTL_LOCAL:-}" = "true" ]; then
        test_pass
    else
        test_warning "MMCTL_LOCAL non définie dans l'environnement"
    fi
}

################################################################################
# Tests fonctionnels
################################################################################

test_functional() {
    print_header "Tests fonctionnels"
    
    # Test aide du script
    test_start "Aide du script element-import.sh"
    if /opt/mattermost/scripts/element-import.sh --help &>/dev/null; then
        test_pass
    else
        test_fail "La commande --help échoue"
    fi
    
    # Test conversion avec fichier minimal
    test_start "Test de conversion (fichier minimal)"
    
    # Créer un fichier JSON de test
    TEST_DIR="/tmp/element_import_test_$$"
    mkdir -p "$TEST_DIR"
    
    cat > "$TEST_DIR/test.json" << 'EOF'
{
  "room_name": "Test Room",
  "events": [
    {
      "type": "m.room.message",
      "sender": "@testuser:matrix.org",
      "content": {
        "msgtype": "m.text",
        "body": "Test message"
      },
      "origin_server_ts": 1234567890000,
      "event_id": "$test123"
    }
  ]
}
EOF
    
    if python3 /opt/mattermost/scripts/element_to_mattermost.py \
       "$TEST_DIR/test.json" \
       --team test-import \
       --output "$TEST_DIR/output.jsonl" &>/dev/null; then
        
        if [ -f "$TEST_DIR/output.jsonl" ]; then
            test_pass
            
            # Vérifier la validité du JSONL
            test_start "  Validité du JSONL généré"
            if python3 -c "
import json
with open('$TEST_DIR/output.jsonl') as f:
    for line in f:
        json.loads(line)
" 2>/dev/null; then
                test_pass
                
                # Compter les lignes
                LINE_COUNT=$(wc -l < "$TEST_DIR/output.jsonl")
                echo "         → $LINE_COUNT objets générés"
            else
                test_fail "JSONL invalide"
            fi
        else
            test_fail "Fichier de sortie non créé"
        fi
    else
        test_fail "Échec de la conversion"
    fi
    
    # Nettoyage
    rm -rf "$TEST_DIR"
}

################################################################################
# Tests de l'interface web
################################################################################

test_web_interface() {
    print_header "Tests de l'interface web (optionnel)"
    
    # Vérifier si le service est actif
    test_start "Service element-import-web"
    if systemctl is-active element-import-web &>/dev/null; then
        test_pass
        
        # Test de connexion HTTP
        test_start "  Connexion HTTP (port 5000)"
        if timeout 5 bash -c 'cat < /dev/null > /dev/tcp/127.0.0.1/5000' 2>/dev/null; then
            test_pass
        else
            test_fail "Port 5000 non accessible"
        fi
        
        # Test endpoint principal
        test_start "  Page principale accessible"
        if curl -sf http://127.0.0.1:5000 > /dev/null 2>&1; then
            test_pass
        else
            test_fail "Page principale non accessible"
        fi
    else
        test_warning "Service non actif (interface web optionnelle)"
    fi
    
    # Nginx
    test_start "Configuration Nginx (optionnel)"
    if [ -f "/etc/nginx/sites-enabled/element-import" ]; then
        test_pass
        
        test_start "  Test de configuration Nginx"
        if nginx -t &>/dev/null; then
            test_pass
        else
            test_fail "Erreur de configuration Nginx"
        fi
    else
        test_warning "Nginx non configuré"
    fi
}

################################################################################
# Tests de sécurité
################################################################################

test_security() {
    print_header "Tests de sécurité"
    
    # Permissions restrictives
    test_start "Permissions des scripts (750)"
    PERMS=$(stat -c '%a' /opt/mattermost/scripts/element-import.sh 2>/dev/null || echo "000")
    if [ "$PERMS" = "750" ] || [ "$PERMS" = "755" ]; then
        test_pass
    else
        test_warning "Permissions: $PERMS (recommandé: 750)"
    fi
    
    # Propriétaire mattermost
    test_start "Propriétaire des fichiers"
    OWNER=$(stat -c '%U' /opt/mattermost/scripts/element_to_mattermost.py 2>/dev/null)
    if [ "$OWNER" = "mattermost" ]; then
        test_pass
    else
        test_fail "Propriétaire incorrect: $OWNER"
    fi
    
    # Pas de fichiers world-writable
    test_start "Aucun fichier world-writable"
    WRITABLE=$(find /opt/mattermost/scripts -type f -perm -002 2>/dev/null | wc -l)
    if [ "$WRITABLE" -eq 0 ]; then
        test_pass
    else
        test_warning "$WRITABLE fichiers sont world-writable"
    fi
}

################################################################################
# Résumé et rapport
################################################################################

print_summary() {
    local total=$((TESTS_PASSED + TESTS_FAILED + TESTS_WARNING))
    
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    RÉSUMÉ DES TESTS                           ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo -e "  Total:        $total tests"
    echo -e "  ${GREEN}✓ Réussis:${NC}    $TESTS_PASSED"
    echo -e "  ${RED}✗ Échecs:${NC}     $TESTS_FAILED"
    echo -e "  ${YELLOW}⚠ Warnings:${NC}   $TESTS_WARNING"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  ✓ Installation validée - Prêt pour la production            ║${NC}"
        echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo "Vous pouvez maintenant utiliser:"
        echo "  /opt/mattermost/scripts/element-import.sh --team myteam export.json"
        echo ""
        return 0
    else
        echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║  ✗ Des problèmes ont été détectés                            ║${NC}"
        echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo "Veuillez corriger les erreurs avant de continuer."
        echo ""
        return 1
    fi
}

################################################################################
# Main
################################################################################

main() {
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║      Tests d'installation - Element Import pour Mattermost   ║"
    echo "║                      Version 2.0                              ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    
    test_system
    test_dependencies
    test_files
    test_configuration
    test_functional
    test_web_interface
    test_security
    
    print_summary
}

# Exécution
main "$@"
