#!/bin/bash
#
# 🚀 ZEN-LS Installer
# Installa zen-ls e configura gli alias per una migliore esperienza
#

set -e

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

echo -e "${CYAN}${BOLD}"
echo "╔═══════════════════════════════════════════╗"
echo "║         🚀 ZEN-LS Installer 🚀            ║"
echo "║     A modern, blazing-fast ls command     ║"
echo "╚═══════════════════════════════════════════╝"
echo -e "${NC}"

# Determina la directory dello script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.local/bin"
ZEN_LS_BIN="${SCRIPT_DIR}/zig-out/bin/zen-ls"

# Funzione per rilevare la shell
detect_shell() {
    # Usa la shell attuale dal processo parent
    local current_shell=$(ps -p $PPID -o comm= 2>/dev/null | sed 's/^-//')
    
    # Fallback al basename di $SHELL
    if [ -z "$current_shell" ]; then
        current_shell=$(basename "$SHELL")
    fi
    
    echo "$current_shell"
}

# Funzione per ottenere il file RC della shell
get_rc_file() {
    local shell_name=$(detect_shell)
    case "$shell_name" in
        zsh)
            echo "${HOME}/.zshrc"
            ;;
        bash)
            if [ -f "${HOME}/.bashrc" ]; then
                echo "${HOME}/.bashrc"
            else
                echo "${HOME}/.bash_profile"
            fi
            ;;
        fish)
            echo "${HOME}/.config/fish/config.fish"
            ;;
        *)
            echo "${HOME}/.profile"
            ;;
    esac
}

# Compila se necessario
compile_zen_ls() {
    echo -e "${BLUE}📦 Compilazione di zen-ls...${NC}"
    
    if ! command -v zig &> /dev/null; then
        echo -e "${RED}❌ Errore: Zig non è installato!${NC}"
        echo -e "${YELLOW}   Installa Zig da: https://ziglang.org/download/${NC}"
        exit 1
    fi
    
    cd "$SCRIPT_DIR"
    
    # Compila in modalità release per massime prestazioni
    if zig build -Doptimize=ReleaseFast 2>/dev/null; then
        echo -e "${GREEN}✅ Compilazione completata!${NC}"
    else
        echo -e "${YELLOW}⚠️  Compilazione in release fallita, provo debug...${NC}"
        zig build
        echo -e "${GREEN}✅ Compilazione completata (debug)!${NC}"
    fi
}

# Installa il binario
install_binary() {
    echo -e "${BLUE}📁 Installazione binario...${NC}"
    
    # Crea directory se non esiste
    mkdir -p "$INSTALL_DIR"
    
    # Copia il binario
    cp "$ZEN_LS_BIN" "$INSTALL_DIR/zen-ls"
    chmod +x "$INSTALL_DIR/zen-ls"
    
    echo -e "${GREEN}✅ Binario installato in: ${INSTALL_DIR}/zen-ls${NC}"
}

# Configura gli alias
setup_aliases() {
    local rc_file=$(get_rc_file)
    local shell_name=$(detect_shell)
    
    echo -e "${BLUE}⚙️  Configurazione alias in ${rc_file}...${NC}"
    
    # Rimuovi vecchi alias zen-ls se presenti
    if [ -f "$rc_file" ]; then
        sed -i.bak '/# ZEN-LS aliases/,/# END ZEN-LS/d' "$rc_file" 2>/dev/null || true
    fi
    
    # Aggiungi nuovi alias
    cat >> "$rc_file" << 'ALIASES'

# ZEN-LS aliases - Modern ls replacement
# Aggiungi ~/.local/bin al PATH se non presente
[[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && export PATH="$HOME/.local/bin:$PATH"

# ll - Vista dettagliata con tutte le info utili
# -l: long format, -a: mostra hidden, -h: human readable sizes
# --group-directories-first: cartelle prima, --icons: icone nerd fonts
alias ll='zen-ls -lah --group-directories-first --icons'

# l - Vista ultra veloce per navigazione rapida
# Modalità minimalista senza dettagli
alias l='zen-ls --ultra-fast --group-directories-first'

# la - Mostra tutti i file inclusi hidden
alias la='zen-ls -a --group-directories-first --icons'

# lt - Vista ad albero per visualizzare struttura
alias lt='zen-ls --tree --icons'

# lS - Ordina per dimensione (più grandi prima)
alias lS='zen-ls -lahS --group-directories-first --icons'

# lT - Ordina per data modifica (più recenti prima)
alias lT='zen-ls -laht --group-directories-first --icons'

# lr - Lista ricorsiva
alias lr='zen-ls -lahR --group-directories-first --icons'
# END ZEN-LS
ALIASES

    echo -e "${GREEN}✅ Alias configurati!${NC}"
}

# Verifica installazione
verify_installation() {
    echo -e "\n${BLUE}🔍 Verifica installazione...${NC}"
    
    if [ -x "$INSTALL_DIR/zen-ls" ]; then
        echo -e "${GREEN}✅ zen-ls installato correttamente${NC}"
        
        # Mostra versione/test
        echo -e "\n${CYAN}📋 Test rapido:${NC}"
        "$INSTALL_DIR/zen-ls" -lh "$SCRIPT_DIR" | head -5
    else
        echo -e "${RED}❌ Installazione fallita${NC}"
        exit 1
    fi
}

# Mostra istruzioni finali
show_instructions() {
    local rc_file=$(get_rc_file)
    
    echo -e "\n${GREEN}${BOLD}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}    ✨ Installazione completata! ✨${NC}"
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════${NC}"
    
    echo -e "\n${CYAN}📌 Alias disponibili:${NC}"
    echo -e "   ${BOLD}ll${NC}  - Vista dettagliata (come ls -lah ma migliore)"
    echo -e "   ${BOLD}l${NC}   - Vista veloce minimalista"
    echo -e "   ${BOLD}la${NC}  - Mostra tutti i file"
    echo -e "   ${BOLD}lt${NC}  - Vista ad albero"
    echo -e "   ${BOLD}lS${NC}  - Ordina per dimensione"
    echo -e "   ${BOLD}lT${NC}  - Ordina per data"
    echo -e "   ${BOLD}lr${NC}  - Lista ricorsiva"
    
    echo -e "\n${YELLOW}⚠️  Per attivare gli alias, esegui:${NC}"
    echo -e "   ${BOLD}source ${rc_file}${NC}"
    echo -e "\n   oppure apri un nuovo terminale."
    
    echo -e "\n${CYAN}🎨 Suggerimento: usa un font Nerd Font per le icone!${NC}"
    echo -e "   https://www.nerdfonts.com/"
    echo
}

# Main
main() {
    compile_zen_ls
    install_binary
    setup_aliases
    verify_installation
    show_instructions
}

# Esegui
main "$@"
