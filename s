#!/bin/bash

# ============================================================
# SSH HARDENING SCRIPT - ТОЛЬКО КЛЮЧИ И БЕЗОПАСНОСТЬ
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Проверка root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Запустите от root: sudo bash $0${NC}"
    exit 1
fi

echo ""
echo "=== НАСТРОЙКА КЛЮЧЕЙ И БЕЗОПАСНОСТИ ==="

# Публичный SSH-ключ владельца.
PUBLIC_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIqGn4hzxZLqi/J2B8b+JRqGGuJeKP7vcEImKJDonCGN SERHII HRYSHYN'
AUTHORIZED_KEYS='/root/.ssh/authorized_keys'

prepare_ssh_dir() {
    install -d -m 700 -o root -g root /root/.ssh
    if [ ! -e "$AUTHORIZED_KEYS" ]; then
        install -m 600 -o root -g root /dev/null "$AUTHORIZED_KEYS"
    fi
    chown root:root "$AUTHORIZED_KEYS"
    chmod 600 "$AUTHORIZED_KEYS"
}

validate_public_key() {
    case "$1" in
        ssh-ed25519\ *|ssh-rsa\ *|ecdsa-sha2-*\ *) return 0 ;;
        *) return 1 ;;
    esac
}

add_key() {
    local key="$1"
    local key_type key_data
    local temp_file

    if ! validate_public_key "$key"; then
        echo -e "${RED}Некорректный формат публичного SSH-ключа.${NC}"
        exit 1
    fi

    key_type=$(printf '%s\n' "$key" | awk '{print $1}')
    key_data=$(printf '%s\n' "$key" | awk '{print $2}')
    if awk -v type="$key_type" -v data="$key_data" \
        '$1 == type && $2 == data { found=1 } END { exit !found }' "$AUTHORIZED_KEYS"; then
        echo -e "${YELLOW}Этот ключ уже установлен.${NC}"
        return
    fi

    temp_file=$(mktemp /root/.ssh/authorized_keys.XXXXXX)
    awk 'NF > 0' "$AUTHORIZED_KEYS" > "$temp_file"
    printf '%s\n' "$key" >> "$temp_file"
    chown root:root "$temp_file"
    chmod 600 "$temp_file"
    mv "$temp_file" "$AUTHORIZED_KEYS"
    echo -e "${GREEN}✅ Ключ добавлен${NC}"
}

show_keys() {
    local number=0
    local line fingerprint comment

    echo ""
    echo -e "${GREEN}Установленные ключи:${NC}"
    echo "────────────────────────────────────────"
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        number=$((number + 1))
        fingerprint=$(printf '%s\n' "$line" | ssh-keygen -lf - 2>/dev/null | awk '{print $2}')
        comment=$(printf '%s\n' "$line" | cut -d' ' -f3-)
        [ "$comment" != "$line" ] || comment='без комментария'
        printf '• %s — %s\n' "${fingerprint:-неизвестный fingerprint}" "$comment"
    done < "$AUTHORIZED_KEYS"
    if [ "$number" -eq 0 ]; then
        echo "Ключей нет."
    fi
    echo "────────────────────────────────────────"
}

prepare_ssh_dir
add_key "$PUBLIC_KEY"

# Показываем ключи после изменения
show_keys

if [ ! -s "$AUTHORIZED_KEYS" ]; then
    echo -e "${YELLOW}На сервере не осталось SSH-ключей.${NC}"
    echo -e "${YELLOW}SSH-конфигурация и служба не изменялись. Не закрывайте текущую сессию, если нужен доступ к серверу.${NC}"
    exit 0
fi

# Безопасность
echo ""
echo "Отключаем вход по паролю..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin yes/PermitRootLogin prohibit-password/g' /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin yes/PermitRootLogin prohibit-password/g' /etc/ssh/sshd_config

systemctl restart ssh
echo -e "${GREEN}✅ Пароли отключены, вход только по ключам${NC}"

# Финальный вывод
IP=$(hostname -I | awk '{print $1}')
echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ НАСТРОЙКА ЗАВЕРШЕНА!${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo -e "Подключение: ${CYAN}ssh root@$IP${NC}"
echo ""
