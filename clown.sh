#!/bin/bash

# ============================================================
# SSH HARDENING SCRIPT - ЧИСТОВАЯ ВЕРСИЯ
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Функция очистки экрана
clear_screen() {
    clear
    echo ""
    echo "========================================="
    echo "     SSH HARDENING SCRIPT"
    echo "========================================="
}

# Проверка root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Запустите от root: sudo bash $0${NC}"
    exit 1
fi

# ============================================================
# ГЛАВНОЕ МЕНЮ
# ============================================================

while true; do
    clear_screen
    
    echo ""
    echo "1) Настроить ключи + отключить пароли"
    echo "2) Сменить SSH порт"
    echo "3) Выйти"
    echo ""
    read -p "Выберите [1-3]: " MENU_CHOICE
    
    case $MENU_CHOICE in
        1)
            clear_screen
            echo ""
            echo "=== НАСТРОЙКА КЛЮЧЕЙ И БЕЗОПАСНОСТИ ==="
            
            # Подменю ключей
            echo ""
            echo "1) Скачать с GitHub (@mrpltrans)"
            echo "2) Вставить публичный ключ вручную"
            echo "3) Пропустить"
            echo ""
            read -p "Выберите [1-3]: " KEY_OPT
            
            case $KEY_OPT in
                1)
                    echo ""
                    echo "Скачиваем ключи с GitHub..."
                    mkdir -p /root/.ssh
                    curl -s https://github.com/mrpltrans.keys > /root/.ssh/authorized_keys
                    chmod 700 /root/.ssh
                    chmod 600 /root/.ssh/authorized_keys
                    echo -e "${GREEN}✅ Ключи загружены${NC}"
                    ;;
                2)
                    echo ""
                    echo "Вставьте публичный SSH ключ:"
                    read USER_KEY
                    mkdir -p /root/.ssh
                    echo "$USER_KEY" > /root/.ssh/authorized_keys
                    chmod 700 /root/.ssh
                    chmod 600 /root/.ssh/authorized_keys
                    echo -e "${GREEN}✅ Ключ сохранён${NC}"
                    ;;
                3)
                    echo ""
                    echo -e "${YELLOW}⏭️ Пропускаем установку ключей${NC}"
                    ;;
            esac
            
            # Показываем ключи если есть
            if [ -s /root/.ssh/authorized_keys ] && [ "$KEY_OPT" != "3" ]; then
                echo ""
                echo -e "${GREEN}Установленные ключи:${NC}"
                echo "────────────────────────────────────────"
                cat /root/.ssh/authorized_keys
                echo "────────────────────────────────────────"
            fi
            
            # Безопасность
            echo ""
            echo "Отключаем вход по паролю..."
            cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)
            sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
            sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
            sed -i 's/PermitRootLogin yes/PermitRootLogin prohibit-password/g' /etc/ssh/sshd_config
            
            systemctl restart ssh
            echo -e "${GREEN}✅ Пароли отключены, вход только по ключам${NC}"
            
            echo ""
            echo -e "${GREEN}✅ Готово! Порт остался 22${NC}"
            echo ""
            read -p "Нажмите Enter для продолжения..."
            ;;
            
        2)
            clear_screen
            echo ""
            echo "=== СМЕНА SSH ПОРТА ==="
            
            # Текущий порт
            CURRENT_PORT=$(grep "^Port" /etc/ssh/sshd_config | awk '{print $2}')
            [ -z "$CURRENT_PORT" ] && CURRENT_PORT=22
            echo -e "Текущий порт: ${YELLOW}$CURRENT_PORT${NC}"
            
            # Ввод нового порта
            while true; do
                echo ""
                read -p "Введите новый порт (1-65535): " NEW_PORT
                
                if [ "$NEW_PORT" -ge 1 ] && [ "$NEW_PORT" -le 65535 ] 2>/dev/null; then
                    if [ "$NEW_PORT" = "$CURRENT_PORT" ]; then
                        echo -e "${RED}Это текущий порт, выберите другой${NC}"
                        continue
                    fi
                    break
                else
                    echo -e "${RED}Ошибка: порт от 1 до 65535${NC}"
                fi
            done
            
            # Открываем новый порт
            if command -v ufw &> /dev/null; then
                echo ""
                echo "Открываем порт $NEW_PORT..."
                ufw allow $NEW_PORT/tcp
                echo -e "${GREEN}✅ Порт $NEW_PORT открыт${NC}"
            fi
            
            # Меняем порт в конфиге
            echo ""
            echo "Меняем порт в конфиге SSH..."
            if grep -q "^Port" /etc/ssh/sshd_config; then
                sed -i "s/^Port .*/Port $NEW_PORT/" /etc/ssh/sshd_config
            else
                echo "Port $NEW_PORT" >> /etc/ssh/sshd_config
            fi
            
            systemctl restart ssh
            echo -e "${GREEN}✅ SSH перезапущен${NC}"
            
            # Проверка
            echo ""
            echo -e "${RED}════════════════════════════════════════════${NC}"
            echo -e "${RED}⚠️  НЕ ЗАКРЫВАЙТЕ ЭТУ СЕССИЮ!${NC}"
            echo -e "${RED}════════════════════════════════════════════${NC}"
            echo ""
            
            IP=$(hostname -I | awk '{print $1}')
            echo -e "Проверьте в НОВОМ терминале:"
            echo -e "${CYAN}ssh -p $NEW_PORT root@$IP${NC}"
            echo ""
            read -p "Новый порт работает? (y/n): " CHECK
            
            if [ "$CHECK" = "y" ]; then
                # Закрываем старый порт
                if command -v ufw &> /dev/null; then
                    ufw delete allow $CURRENT_PORT/tcp 2>/dev/null
                    echo -e "${GREEN}✅ Порт $CURRENT_PORT закрыт${NC}"
                fi
                echo -e "${GREEN}✅ Порт изменён на $NEW_PORT${NC}"
            else
                # Откат
                echo ""
                echo "Откатываем изменения..."
                sed -i "s/^Port .*/Port $CURRENT_PORT/" /etc/ssh/sshd_config
                if command -v ufw &> /dev/null; then
                    ufw delete allow $NEW_PORT/tcp 2>/dev/null
                fi
                systemctl restart ssh
                echo -e "${GREEN}✅ Откат выполнен, порт $CURRENT_PORT${NC}"
            fi
            
            echo ""
            read -p "Нажмите Enter для продолжения..."
            ;;
            
        3)
            echo "Выход"
            exit 0
            ;;
            
        *)
            echo -e "${RED}Неверный выбор${NC}"
            sleep 1
            ;;
    esac
done
