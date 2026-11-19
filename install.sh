#!/usr/bin/env bash

# strict mode
set -euo pipefail

# define consts and exit modes
EXIT_SUCCESS=0
EXIT_SOURCE_ERROR=1
EXIT_WRITE_ERROR=2

# guarda o arquivo de configuração
CONFIG_FILE="./src/syspulse.conf"


## FUNÇÃO PARA ATUALIZAR ARQUIVO DE CONFIGURAÇÃO
update_config() {
    local key="$1"
    local value="$2"
    local use_quotes="$3"

    # escapa caracteres especiais (&, \, |) para não quebrar o sed
    local valor_escapado
    valor_escapado=$(printf '%s\n' "$value" | sed 's/[&\|]/\\&/g')

    # y = yes
    if [ "$use_quotes" = "y" ]; then
        sed -i "s|^${key}=.*|${key}=\"${valor_escapado}\"|" "$CONFIG_FILE"
    else
        sed -i "s|^${key}=.*|${key}=${valor_escapado}|" "$CONFIG_FILE"
    fi
}


## CRIA AS PASTAS E ARQUIVOS LOCAIS

# cria as pastas de configuração, instalação e serviço
if mkdir -p ~/.config/syspulse/core/ && mkdir -p ~/.config/syspulse/services/ && mkdir -p ~/.local/bin/ && mkdir -p ~/.config/systemd/user/; then
    echo "[INFO] Pastas criadas com sucesso."
else
    echo "[ERROR] Não foi possível criar as pastas."
    exit $EXIT_WRITE_ERROR
fi

# copia os scripts para um diretório interno

cp ./src/syspulse-backup.sh ~/.config/syspulse/core/syspulse-backup

cp ./src/syspulse-health.sh ~/.config/syspulse/core/syspulse-health

cp ./src/syspulse-logger.sh ~/.config/syspulse/core/syspulse-logger

cp ./src/syspulse.conf ~/.config/syspulse/syspulse.conf

# cria links simbólicos apontando para os scripts

ln -sf ~/.config/syspulse/core/syspulse-backup ~/.local/bin/syspulse-backup

ln -sf ~/.config/syspulse/core/syspulse-health ~/.local/bin/syspulse-health


## GRAVAR O COMANDO GLOBAL NO TERMINAL

## garantir que o ~/.local/bin esteja no PATH do usuário

# diretório de instalação
TARGET_DIR="$HOME/.local/bin"

# verifica se o caminho já está ativo no PATH atual
case ":$PATH:" in
    *":$TARGET_DIR:"*)
        echo "[INFO] O diretório $TARGET_DIR já está no seu PATH."
        ;;
    *)
        # detecta o arquivo de configuração baseado no shell do usuário
        case "$(basename "$SHELL")" in
            zsh)
                CONFIG_FILE="$HOME/.zshrc"
                ;;
            bash)
                CONFIG_FILE="$HOME/.bashrc"
                ;;
            fish)
                CONFIG_FILE="$HOME/.config/fish/config.fish"
                ;;
            *)
                # fallback padrão para qualquer outro shell (sh, ash, dash, etc.)
                CONFIG_FILE="$HOME/.profile"
                ;;
        esac

        # define o comando de exportação (o Fish usa uma sintaxe diferente)
        if [ "$(basename "$SHELL")" = "fish" ]; then
            EXPORT_CMD="fish_add_path $TARGET_DIR"
            mkdir -p "$(dirname "$CONFIG_FILE")"
        else
            EXPORT_CMD="export PATH=\"\$HOME/.local/bin:\$PATH\""
        fi

        # cria o arquivo se não existir e adiciona a linha apenas se ela ainda não estiver lá
        touch "$CONFIG_FILE"
        if ! grep -Fq "$TARGET_DIR" "$CONFIG_FILE"; then
            printf "\n# Adicionado pelo instalador\n%s\n" "$EXPORT_CMD" >> "$CONFIG_FILE"
            echo "[INFO] Caminho adicionado em $CONFIG_FILE."
            echo "[INFO] Reinicie o terminal ou execute: source $CONFIG_FILE"
        else
            echo "[INFO] A configuração já existe em $CONFIG_FILE (reinicie o terminal para aplicar)."
        fi
        ;;
esac

## dar permissão de execução (chmod +x) em todos os scripts
chmod +x ~/.config/syspulse/core/syspulse-backup

chmod +x ~/.config/syspulse/core/syspulse-health

chmod +x ~/.config/syspulse/core/syspulse-logger


## PREENCHE O syspulse.conf INTERATIVAMENTE

# pergunta sobre o backup directory
read -rp "Diretório de backup: " input_backup
if [[ -z $input_backup ]]; then
    BACKUP_DIR="~/.config/syspulse/backup"
    mkdir -p ~/.config/syspulse/backup
else
    BACKUP_DIR="${input_backup}"
fi

# pergunta sobre o source directory
read -rp "Caminho completo do arquivo de origem: " input_source
SOURCE_FILE="${input_source:-~/.config/syspulse/}"

# pergunta sobre o log file
read -rp "Caminho do arquivo de log: " input_log
LOG_FILE="${input_log:-~/.config/syspulse/}"

# pergunta sobre retention count
read -rp "Quantidade de retenção de backups: " input_ret
RETENTION_COUNT="${input_ret:-5}"

# asks about disk threshold
read -rp "Limite de uso de disco em %: " input_disk
DISK_THRESHOLD="${input_disk:-85}"

# asks about ram threshold
read -rp "Limite de uso de RAM em %: " input_ram
RAM_THRESHOLD="${input_ram:-85}"

# gravar no aquivo de configuração
update_config "BACKUP_DIR" "$BACKUP_DIR" "y"
update_config "SOURCE_FILE" "$SOURCE_FILE" "y"
update_config "LOG_FILE" "$LOG_FILE" "y"

update_config "RETENTION_COUNT" "$RETENTION_COUNT" "n"
update_config "DISK_THRESHOLD" "$DISK_THRESHOLD" "n"
update_config "RAM_THRESHOLD" "$RAM_THRESHOLD" "n"

echo "[SUCCESS] Configuração salva com sucesso em ${CONFIG_FILE}!"


## DEFINIR SERVICES (SYSTEMD) E TIMER

# health check em segundo plano ou não

PS3="configurar o monitoramento de saúde (RAM e Disco) como CONTÍNUO (Roda em segundo plano a cada 1 minuto via Systemd Timer)?"
select HEALTH_OPTION in "Yes" "No"; do
    case "$HEALTH_OPTION" in
        "Yes")
            echo "[INFO] Iniciando a criação do Health Check service."

            # copia os serviços para a pasta local do usuário
            cp ./services/syspulse-health-check.service ~/.config/syspulse/services/syspulse-health-check.service

            cp ./services/syspulse-health-check.timer ~/.config/syspulse/services/syspulse-health-check.timer

            # verifica se os arquivos foram copiados

            if [[ ! -f ~/.config/syspulse/services/syspulse-health-check.service && -f ~/.config/syspulse/services/syspulse-health-check.timer ]]; then
                echo "[ERROR] Não foi possível copiar os arquivos de serviço."
                exit $EXIT_WRITE_ERROR
            fi

            # cria os links simbolicos e verifica se foram criados
            if ! ln -sf ~/.config/syspulse/services/syspulse-health-check.service ~/.config/systemd/user/syspulse-health-check.service || ! ln -sf ~/.config/syspulse/services/syspulse-health-check.timer ~/.config/systemd/user/syspulse-health-check.timer; then
                echo "[ERROR] Não foi possível criar os links simbólicos do serviço de health check."
            fi

            # ativa o timer do health check
            systemctl --user daemon-reload
            systemctl --user enable --now health-check.timer

            # garante que o timer rode mesmo se o usuário reiniciar o computador e não logar na interface gráfica
            loginctl enable-linger "$USER" 2>/dev/null || true

            echo "[SUCCESS] Health Chech ativado com sucesso!"
        ;;
        "No")
            echo "[INFO] Continuando instalação..."
        ;;
    esac
done

# backup agendado ou não

PS3="Deseja configurar o módulo de Backup como AGENDADO (define uma data/horário automático via Systemd Timer)? "
select BACKUP_OPTION in "Yes" "No"; do
    case "$BACKUP_OPTION" in
        "Yes")
            echo "[INFO] Iniciando a criação do backup service."

            echo ""
            echo "Escolha a frequência do backup:"
            echo "1) Diário (Todo dia às 22:00)"
            echo "2) Semanal (Toda sexta-feira às 18:00)"
            echo "3) Mensal (Todo dia 1º às 00:00)"
            echo "4) Personalizado (Ex: 2026-12-25 14:30:00 ou *-*-15 12:00:00)"
            read -rp "Opção [1-4]: " FREQ_OPT

            case "$FREQ_OPT" in
                1) CALENDAR_SPEC="*-*-* 22:00:00" ;;
                2) CALENDAR_SPEC="Fri *-*-* 18:00:00" ;;
                3) CALENDAR_SPEC="*-*-01 00:00:00" ;;
                4) 
                    while true; do
                        read -rp "Digite a data e hora (Ex: 2026-12-25 14:30:00 ou daily): " CALENDAR_SPEC
                        if systemd-analyze calendar "$CALENDAR_SPEC" >/dev/null 2>&1; then
                            break
                        else
                            echo "[ERROR] Formato inválido! Tente novamente (ex: 2026-12-25 14:30:00)."
                        fi
                    done
                    ;;
                *)
                    echo "[WARN] Opção inválida. Usando padrão diário (22:00)."
                    CALENDAR_SPEC="*-*-* 22:00:00"
                    ;;
            esac

            echo "[INFO] Configurando agendamento ($CALENDAR_SPEC)..."

            # copia os templates para a pasta services/
            cp ./services/syspulse-backup.service ~/.config/syspulse/services/syspulse-backup.service
            cp ./services/syspulse-backup.timer ~/.config/syspulse/services/syspulse-backup.timer

            # substitui a linha OnCalendar no arquivo instalado pela escolha do usuário
            sed -i "s|^OnCalendar=.*|OnCalendar=$CALENDAR_SPEC|" ~/.config/syspulse/services/syspulse-backup.timer

            # cria os links simbolicos e verifica se foram criados
            if ! ln -sf ~/.config/syspulse/services/syspulse-backup.service ~/.config/systemd/user/syspulse-backup.service || ! ln -sf ~/.config/syspulse/services/syspulse-backup.timer ~/.config/systemd/user/syspulse-backup.timer; then
                echo "[ERROR] Não foi possível criar os links simbólicos do serviço de backup."
            fi

            # ativa o timer do backup
            systemctl --user daemon-reload
            systemctl --user enable --now syspulse-backup.timer

            # garante que o timer rode mesmo se o usuário reiniciar o computador e não logar na interface gráfica
            loginctl enable-linger "$USER" 2>/dev/null || true

            echo "[SUCCESS] Backup agendado ativado com sucesso!"
        ;;
        "No")
            echo "[INFO] Continuando instalação..."
        ;;
    esac
done


## VERIFICAÇÃO FINAL COM TESTE RÁPIDO
if syspulse-health && syspulse-backup; then
    echo "[SUCCESS] A instalação finalizou com sucesso!"
    exit $EXIT_SUCCESS
else
    echo "[ERROR] Algo ocorreu de errado na instalação."
    exit $EXIT_WRITE_ERROR
fi
