#!/bin/bash

# ============================================================
# SSH HARDENING SCRIPT - БЕЗ ГЛЮКОВ
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
    echo "Запустите от root: sudo bash $0"
    exit 1
fi

# ============================================================
# ГЛАВНОЕ МЕНЮ
# ============================================================

while true; do
    echo ""
    echo "1) Настроить ключи + отключить пароли"
    echo "2) Сменить SSH порт"
    echo "3) Выйти"
    echo ""
    read -p "Выберите [1-3]: " MENU_CHOICE
    
    case $MENU_CHOICE in
        1)
            echo ""
            echo "=== НАСТРОЙКА КЛЮЧЕЙ И БЕЗОПАСНОСТИ ==="
            
            # Ключи
            echo ""
            echo "1. Устанавливаем SSH ключи..."
            mkdir -p /root/.ssh
            
            echo "   a) Скачать с GitHub (@mrpltrans)"
            echo "   b) Вставить вручную"
            echo "   c) Пропустить"
            read -p "Выберите [a/b/c]: " KEY_OPT
            
            case $KEY_OPT in
                a)
                    curl -s https://github.com/mrpltrans.keys > /root/.ssh/authorized_keys
                    echo "✅ Ключи с GitHub"
                    ;;
                b)
                    echo "Вставьте публичный ключ:"
                    read USER_KEY
                    echo "$USER_KEY" > /root/.ssh/authorized_keys
                    echo "✅ Ключ добавлен"
                    ;;
                c)
                    echo "⏭️ Пропускаем"
                    ;;
            esac
            
            if [ -s /root/.ssh/authorized_keys ]; then
                chmod 700 /root/.ssh
                chmod 600 /root/.ssh/authorized_keys
                echo ""
                echo "Установленные ключи:"
                cat /root/.ssh/authorized_keys
            fi
            
            # Безопасность
            echo ""
            echo "2. Отключаем вход по паролю..."
            cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)
            sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
            sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
            sed -i 's/PermitRootLogin yes/PermitRootLogin prohibit-password/g' /etc/ssh/sshd_config
            
            systemctl restart ssh
            echo "✅ Пароли отключены, вход только по ключам"
            echo ""
            echo "Готово! Порт остался 22"
            ;;
            
        2)
            echo ""
            echo "=== СМЕНА SSH ПОРТА ==="
            
            # Определяем текущий порт
            CURRENT_PORT=$(grep "^Port" /etc/ssh/sshd_config | awk '{print $2}')
            if [ -z "$CURRENT_PORT" ]; then
                CURRENT_PORT=22
            fi
            echo "Текущий порт: $CURRENT_PORT"
            
            # Вводим новый порт
            while true; do
                echo ""
                read -p "Введите новый порт (1-65535): " NEW_PORT
                
                if [ "$NEW_PORT" -ge 1 ] && [ "$NEW_PORT" -le 65535 ] 2>/dev/null; then
                    if [ "$NEW_PORT" = "$CURRENT_PORT" ]; then
                        echo "Это текущий порт, выберите другой"
                        continue
                    fi
                    break
                else
                    echo "Ошибка: порт должен быть от 1 до 65535"
                fi
            done
            
            # Открываем новый порт в фаерволле
            if command -v ufw &> /dev/null; then
                echo ""
                echo "Открываем порт $NEW_PORT..."
                ufw allow $NEW_PORT/tcp
                echo "✅ Порт $NEW_PORT открыт"
            fi
            
            # Меняем порт в конфиге
            echo ""
            echo "Меняем порт в конфиге SSH..."
            if grep -q "^Port" /etc/ssh/sshd_config; then
                sed -i "s/^Port .*/Port $NEW_PORT/" /etc/ssh/sshd_config
            else
                echo "Port $NEW_PORT" >> /etc/ssh/sshd_config
            fi
            
            # Перезапускаем SSH
            systemctl restart ssh
            echo "✅ SSH перезапущен"
            
            # Инструкция
            echo ""
            echo "========================================="
            echo "ВАЖНО! НЕ ЗАКРЫВАЙТЕ ЭТУ СЕССИЮ!"
            echo "========================================="
            echo ""
            IP=$(hostname -I | awk '{print $1}')
            echo "Проверьте новое подключение:"
            echo "ssh -p $NEW_PORT root@$IP"
            echo ""
            read -p "Новый порт работает? (y/n): " CHECK
            
            if [ "$CHECK" = "y" ]; then
                # Закрываем старый порт
                if command -v ufw &> /dev/null; then
                    ufw delete allow $CURRENT_PORT/tcp 2>/dev/null
                    echo "✅ Порт $CURRENT_PORT закрыт"
                fi
                echo "✅ Порт изменён на $NEW_PORT"
            else
                # Откат
                echo "Откатываем..."
                sed -i "s/^Port .*/Port $CURRENT_PORT/" /etc/ssh/sshd_config
                if command -v ufw &> /dev/null; then
                    ufw delete allow $NEW_PORT/tcp 2>/dev/null
                fi
                systemctl restart ssh
                echo "✅ Откат, порт $CURRENT_PORT"
            fi
            ;;
            
        3)
            echo "Выход"
            exit 0
            ;;
            
        *)
            echo "Неверный выбор"
            ;;
    esac
done
