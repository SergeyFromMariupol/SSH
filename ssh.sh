#!/bin/bash

# ============================================================
# SSH HARDENING SCRIPT - ТОЛЬКО КЛЮЧИ И БЕЗОПАСНОСТЬ
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo ""
echo "========================================="
echo "     SSH HARDENING SCRIPT"
echo "========================================="

# Проверка root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Запустите от root: sudo bash $0${NC}"
    exit 1
fi

echo ""
echo "=== НАСТРОЙКА КЛЮЧЕЙ И БЕЗОПАСНОСТИ ==="

# Публичные ключи. Пароль защищает приватный файл на компьютере владельца;
# на сервер устанавливается только соответствующая публичная часть.
KEY_PASSWORD_NO='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIqGn4hzxZLqi/J2B8b+JRqGGuJeKP7vcEImKJDonCGN SERHII HRYSHYN'
KEY_PASSWORD_YES='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDQgJqQX0gbt56vHK7kzfvS5Aa5YxVvp+1dLs2s1kd6/ SERHII HRYSHYN'
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
        printf '%d) %s — %s\n' "$number" "${fingerprint:-неизвестный fingerprint}" "$comment"
    done < "$AUTHORIZED_KEYS"
    if [ "$number" -eq 0 ]; then
        echo "Ключей нет."
    fi
    echo "────────────────────────────────────────"
}

delete_key() {
    local -a keys=()
    local -a stored_keys=()
    local key
    local selected temp_file index

    mapfile -t stored_keys < "$AUTHORIZED_KEYS"
    for key in "${stored_keys[@]}"; do
        [ -n "$key" ] && keys+=("$key")
    done
    if [ "${#keys[@]}" -le 1 ]; then
        echo -e "${RED}Нельзя удалить последний ключ: вы потеряете SSH-доступ.${NC}"
        exit 1
    fi

    show_keys
    read -r -p "Номер ключа для удаления: " selected
    if [[ ! "$selected" =~ ^[0-9]+$ ]] || \
       [ "$selected" -lt 1 ] || [ "$selected" -gt "${#keys[@]}" ]; then
        echo -e "${RED}Некорректный номер ключа.${NC}"
        exit 1
    fi

    temp_file=$(mktemp /root/.ssh/authorized_keys.XXXXXX)
    for index in "${!keys[@]}"; do
        if [ "$((index + 1))" -ne "$selected" ]; then
            printf '%s\n' "${keys[$index]}" >> "$temp_file"
        fi
    done
    if [ ! -s "$temp_file" ]; then
        rm -f "$temp_file"
        echo -e "${RED}Удаление остановлено: authorized_keys стал бы пустым.${NC}"
        exit 1
    fi
    chown root:root "$temp_file"
    chmod 600 "$temp_file"
    mv "$temp_file" "$AUTHORIZED_KEYS"
    echo -e "${GREEN}✅ Ключ удалён. Не закрывайте текущую сессию до проверки нового входа.${NC}"
}

prepare_ssh_dir

# Подменю ключей
echo ""
echo "1) Добавить ключ без пароля"
echo "2) Добавить ключ с паролем"
echo "3) Добавить публичный ключ вручную"
echo "4) Удалить установленный ключ"
echo "5) Показать установленные ключи"
echo "6) Выход"
echo ""
read -r -p "Выберите [1-6]: " KEY_OPT

case $KEY_OPT in
    1)
        add_key "$KEY_PASSWORD_NO"
        ;;
    2)
        add_key "$KEY_PASSWORD_YES"
        ;;
    3)
        echo ""
        echo "Вставьте публичный SSH ключ:"
        read -r USER_KEY
        add_key "$USER_KEY"
        ;;
    4)
        delete_key
        ;;
    5)
        :
        ;;
    6)
        echo "Выход без изменений."
        exit 0
        ;;
    *)
        echo -e "${RED}Некорректный выбор.${NC}"
        exit 1
        ;;
esac

# Показываем ключи после изменения
show_keys

if [ ! -s "$AUTHORIZED_KEYS" ]; then
    echo -e "${RED}authorized_keys пуст. Отключать парольный вход небезопасно.${NC}"
    exit 1
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
