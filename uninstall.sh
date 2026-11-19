#!/usr/bin/env bash


# Syspulse - Módulo de Desinstalação (Rootless / User-space)
# Para e desativa timers/services do systemd --user, remove symlinks e limpa os diretórios de instalação do usuário.

set -euo pipefail

EXIT_SUCCESS=0

# --- FUNÇÃO AUXILIAR DE LOG SIMPLES ---
log_info()  { echo -e "\033[34m[INFO]\033[0m $1"; }
log_warn()  { echo -e "\033[33m[WARN]\033[0m $1"; }
log_ok()    { echo -e "\033[32m[SUCCESS]\033[0m $1"; }

echo "=========================================="
echo "       Syspulse - Desinstalador"
echo "=========================================="
read -rp "Tem certeza que deseja remover o Syspulse do usuário '$USER'? [s/N]: " confirm
case "${confirm,,}" in
    s|sim|y|yes) ;;
    *)
        log_info "Desinstalação cancelada pelo usuário."
        exit "$EXIT_SUCCESS"
        ;;
esac

# --- 1. PARAR E DESATIVAR TIMERS E SERVICES DO SYSTEMD (--user) ---
log_info "Parando e desativando unidades do systemd do usuário..."

UNITS=(
    "syspulse-health-check.timer"
    "syspulse-health-check.service"
    "health-check.timer"
    "syspulse-backup.timer"
    "syspulse-backup.service"
)

if systemctl --user list-units >/dev/null 2>&1; then
    for unit in "${UNITS[@]}"; do
        systemctl --user stop "$unit" 2>/dev/null || true
        systemctl --user disable "$unit" 2>/dev/null || true
    done
else
    log_warn "Sessão do systemd --user não detectada no ambiente atual; removendo arquivos diretamente."
fi

# --- 2. REMOVER SYMLINKS DO SYSTEMD E DO ~/.local/bin ---
log_info "Removendo links simbólicos..."

for unit in "${UNITS[@]}"; do
    rm -f "$HOME/.config/systemd/user/$unit"
done

rm -f "$HOME/.local/bin/syspulse-backup"
rm -f "$HOME/.local/bin/syspulse-health"

# Recarrega o systemd do usuário para ele esquecer as unidades removidas
if systemctl --user list-units >/dev/null 2>&1; then
    systemctl --user daemon-reload
    systemctl --user reset-failed 2>/dev/null || true
fi

# --- 3. REMOVER ARQUIVOS E PASTAS DO SYSPULSE ---
log_info "Removendo diretórios internos do Syspulse..."

rm -rf "$HOME/.config/syspulse/core"
rm -rf "$HOME/.config/syspulse/services"
rm -f  "$HOME/.config/syspulse/syspulse.conf"

# Pergunta opcional: remover também a pasta de backups/logs dentro de ~/.config/syspulse (se existir)
if [[ -d "$HOME/.config/syspulse/backup" ]]; then
    read -rp "Deseja apagar também '$HOME/.config/syspulse/backup'? [s/N]: " del_backup
    case "${del_backup,,}" in
        s|sim|y|yes)
            rm -rf "$HOME/.config/syspulse/backup"
            log_info "Pasta de backups interna removida."
            ;;
        *)
            log_info "Pasta de backups preservada."
            ;;
    esac
fi

# Remove ~/.config/syspulse apenas se estiver vazia
rmdir "$HOME/.config/syspulse" 2>/dev/null || true

# --- 4. NOTA SOBRE PATH E LINGER ---
log_info "Nota: linhas adicionadas ao seu arquivo de shell (~/.bashrc, ~/.zshrc, etc.) não foram apagadas automaticamente por segurança."
log_info "Se quiser desativar o linger do usuário no sistema, execute: loginctl disable-linger $USER"

log_ok "Desinstalação concluída!"
exit "$EXIT_SUCCESS"