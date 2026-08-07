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

save_keys() {
    local content="$1"
    local temp_file

    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    temp_file=$(mktemp /root/.ssh/authorized_keys.XXXXXX)
    printf '%s\n' "$content" > "$temp_file"
    chmod 600 "$temp_file"
    mv "$temp_file" /root/.ssh/authorized_keys
}

# Подменю ключей
echo ""
echo "1) Скачать с GitHub (@SergeyFromMariupol)"
echo "2) Установить ключ без пароля (Password_NO, SHA256:k34c6+DC...)"
echo "3) Установить ключ с паролем (Password_YES, SHA256:9FZgNC+Z...)"
echo "4) Установить оба ключа"
echo "5) Вставить публичный ключ вручную"
echo "6) Пропустить"
echo ""
read -r -p "Выберите [1-6]: " KEY_OPT

case $KEY_OPT in
    1)
        echo ""
        echo "Скачиваем ключи с GitHub..."
        GITHUB_KEYS=$(curl -fsS https://github.com/SergeyFromMariupol.keys) || {
            echo -e "${RED}Не удалось скачать ключи с GitHub.${NC}"
            exit 1
        }
        if [ -z "$GITHUB_KEYS" ]; then
            echo -e "${RED}GitHub вернул пустой список ключей.${NC}"
            exit 1
        fi
        save_keys "$GITHUB_KEYS"
        echo -e "${GREEN}✅ Ключи загружены${NC}"
        ;;
    2)
        save_keys "$KEY_PASSWORD_NO"
        echo -e "${GREEN}✅ Установлен ключ Password_NO${NC}"
        ;;
    3)
        save_keys "$KEY_PASSWORD_YES"
        echo -e "${GREEN}✅ Установлен ключ Password_YES${NC}"
        ;;
    4)
        save_keys "${KEY_PASSWORD_NO}
${KEY_PASSWORD_YES}"
        echo -e "${GREEN}✅ Установлены оба ключа${NC}"
        ;;
    5)
        echo ""
        echo "Вставьте публичный SSH ключ:"
        read -r USER_KEY
        case "$USER_KEY" in
            ssh-ed25519\ *|ssh-rsa\ *|ecdsa-sha2-*\ *) ;;
            *)
                echo -e "${RED}Некорректный формат публичного SSH-ключа.${NC}"
                exit 1
                ;;
        esac
        save_keys "$USER_KEY"
        echo -e "${GREEN}✅ Ключ сохранён${NC}"
        ;;
    6)
        echo ""
        echo -e "${YELLOW}⏭️ Пропускаем установку ключей${NC}"
        ;;
    *)
        echo -e "${RED}Некорректный выбор.${NC}"
        exit 1
        ;;
esac

# Показываем ключи если есть
if [ -s /root/.ssh/authorized_keys ] && [ "$KEY_OPT" != "6" ]; then
    echo ""
    echo -e "${GREEN}Установленные ключи:${NC}"
    echo "────────────────────────────────────────"
    cat /root/.ssh/authorized_keys
    echo "────────────────────────────────────────"
fi

if [ ! -s /root/.ssh/authorized_keys ]; then
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
