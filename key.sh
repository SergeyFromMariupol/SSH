#!/bin/bash

# ============================================================
# SSH Hardening Script v3.0 - Professional Edition
# Author: mrpltrans
# GitHub: https://github.com/mrpltrans/SSH
# ============================================================

set +H
set -e

# ============================================================
# КОНФИГУРАЦИЯ
# ============================================================

VERSION="3.0"
CONFIG_FILE="/etc/ssh/sshd_config"
BACKUP_DIR="/root/ssh-backups"
LOG_FILE="/var/log/ssh-hardening.log"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# ============================================================
# ФУНКЦИИ
# ============================================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

print_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${GREEN}$1${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
}

print_success() { echo -e "${GREEN}  ✓ $1${NC}"; log "OK: $1"; }
print_error() { echo -e "${RED}  ✗ $1${NC}"; log "ERROR: $1"; }
print_warning() { echo -e "${YELLOW}  ⚠ $1${NC}"; log "WARN: $1"; }
print_info() { echo -e "${BLUE}  ℹ $1${NC}"; }
print_highlight() { echo -e "${WHITE}  ▶ $1${NC}"; }

# Проверка root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        print_error "Скрипт должен запускаться от root"
        echo "Используйте: sudo bash $0"
        exit 1
    fi
}

# Создание бэкапа
create_backup() {
    mkdir -p "$BACKUP_DIR"
    local backup_file="$BACKUP_DIR/sshd_config.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$CONFIG_FILE" "$backup_file"
    echo "$backup_file"
}

# Безопасная установка параметра SSH
set_ssh_param() {
    local param=$1
    local value=$2
    local file=$3
    
    if grep -q "^$param" "$file"; then
        sed -i "s/^$param.*/$param $value/" "$file"
    elif grep -q "^#$param" "$file"; then
        sed -i "s/^#$param.*/$param $value/" "$file"
    else
        echo "$param $value" >> "$file"
    fi
}

# Проверка конфигурации SSH
test_ssh_config() {
    if sshd -t 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Перезапуск SSH
restart_ssh() {
    systemctl restart ssh 2>/dev/null || service ssh restart 2>/dev/null
    sleep 2
}

# Настройка UFW
configure_ufw() {
    local port=$1
    if command -v ufw &> /dev/null; then
        ufw allow "$port"/tcp 2>/dev/null && print_success "Порт $port открыт в UFW"
        return 0
    else
        print_warning "UFW не установлен. Установите: apt install ufw -y"
        return 1
    fi
}

# ============================================================
# ГЛАВНОЕ МЕНЮ
# ============================================================

show_main_menu() {
    clear
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════════════════╗"
    echo "║                         SSH HARDENING SCRIPT v$VERSION                      ║"
    echo "║                      Professional Security Configuration                   ║"
    echo "╚══════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Показываем текущий статус
    local current_port=$(grep -E "^Port" "$CONFIG_FILE" | awk '{print $2}')
    [ -z "$current_port" ] && current_port=22
    
    local password_auth=$(grep -E "^PasswordAuthentication" "$CONFIG_FILE" | awk '{print $2}')
    [ -z "$password_auth" ] && password_auth="yes (default)"
    
    echo -e "${CYAN}📊 ТЕКУЩЕЕ СОСТОЯНИЕ:${NC}"
    echo -e "  ${WHITE}SSH порт:${NC} $current_port"
    echo -e "  ${WHITE}Парольная аутентификация:${NC} $password_auth"
    echo -e "  ${WHITE}IP адрес:${NC} $(hostname -I | awk '{print $1}')"
    echo -e "  ${WHITE}Хост:${NC} $(hostname)"
    echo ""
    
    echo -e "${CYAN}⚙️  ДОСТУПНЫЕ ДЕЙСТВИЯ:${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} 🔑 Управление SSH ключами"
    echo -e "  ${GREEN}2)${NC} 🔒 Настройка безопасности (отключение паролей, ограничения)"
    echo -e "  ${GREEN}3)${NC} 🌐 Смена SSH порта"
    echo -e "  ${GREEN}4)${NC} 🚀 ПОЛНАЯ НАСТРОЙКА (всё сразу)"
    echo -e "  ${GREEN}5)${NC} 🔄 Восстановление из бэкапа"
    echo -e "  ${GREEN}6)${NC} 📋 Показать текущую конфигурацию"
    echo -e "  ${GREEN}7)${NC} 🛡️  Дополнительные настройки (Fail2ban, баннеры)"
    echo -e "  ${GREEN}8)${NC} ❌ Выход"
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    read -p "$(echo -e ${YELLOW}👉 Введите номер действия [1-8]:${NC} )" ACTION
    echo ""
    
    case $ACTION in
        1) manage_keys ;;
        2) security_settings ;;
        3) change_port ;;
        4) full_setup ;;
        5) restore_backup ;;
        6) show_config ;;
        7) advanced_settings ;;
        8) exit 0 ;;
        *) print_error "Неверный выбор"; sleep 2; show_main_menu ;;
    esac
}

# ============================================================
# 1. УПРАВЛЕНИЕ КЛЮЧАМИ
# ============================================================

manage_keys() {
    print_header "УПРАВЛЕНИЕ SSH КЛЮЧАМИ"
    
    echo ""
    echo -e "  ${GREEN}a)${NC} Добавить ключи с GitHub (@mrpltrans)"
    echo -e "  ${GREEN}b)${NC} Добавить ключ вручную (вставить публичный ключ)"
    echo -e "  ${GREEN}c)${NC} Показать установленные ключи"
    echo -e "  ${GREEN}d)${NC} Удалить все ключи (ОСТОРОЖНО!)"
    echo -e "  ${GREEN}e)${NC} Назад в главное меню"
    echo ""
    read -p "$(echo -e ${YELLOW}👉 Выберите действие [a-e]:${NC} )" KEY_ACTION
    
    case $KEY_ACTION in
        a)
            print_info "Скачиваем ключи с GitHub..."
            mkdir -p /root/.ssh
            if curl -s https://github.com/mrpltrans.keys > /root/.ssh/authorized_keys; then
                chmod 700 /root/.ssh
                chmod 600 /root/.ssh/authorized_keys
                print_success "Ключи успешно добавлены"
                echo ""
                print_info "Добавленные ключи:"
                cat /root/.ssh/authorized_keys
            else
                print_error "Не удалось загрузить ключи"
            fi
            ;;
        b)
            print_info "Введите публичный SSH ключ:"
            read -p "> " USER_KEY
            mkdir -p /root/.ssh
            echo "$USER_KEY" >> /root/.ssh/authorized_keys
            chmod 700 /root/.ssh
            chmod 600 /root/.ssh/authorized_keys
            print_success "Ключ добавлен"
            ;;
        c)
            if [ -f /root/.ssh/authorized_keys ]; then
                print_info "Установленные ключи:"
                cat /root/.ssh/authorized_keys
            else
                print_warning "Ключи не найдены"
            fi
            ;;
        d)
            echo ""
            read -p "$(echo -e ${RED}⚠️  ВНИМАНИЕ! Удалить все ключи? (yes/no):${NC} )" CONFIRM
            if [ "$CONFIRM" = "yes" ]; then
                rm -f /root/.ssh/authorized_keys
                print_success "Все ключи удалены"
            fi
            ;;
        e) show_main_menu ;;
        *) print_error "Неверный выбор" ;;
    esac
    
    echo ""
    read -p "Нажмите Enter для продолжения..."
    show_main_menu
}

# ============================================================
# 2. НАСТРОЙКА БЕЗОПАСНОСТИ
# ============================================================

security_settings() {
    print_header "НАСТРОЙКА БЕЗОПАСНОСТИ SSH"
    
    local backup_file=$(create_backup)
    print_info "Создан бэкап: $backup_file"
    
    echo ""
    echo -e "${CYAN}Выберите настройки для применения:${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} Отключить вход по паролю (рекомендуется)"
    echo -e "  ${GREEN}2)${NC} Отключить вход для root по паролю"
    echo -e "  ${GREEN}3)${NC} Ограничить количество попыток (MaxAuthTries)"
    echo -e "  ${GREEN}4)${NC} Ограничить количество сессий (MaxSessions)"
    echo -e "  ${GREEN}5)${NC} Настроить таймауты (ClientAliveInterval)"
    echo -e "  ${GREEN}6)${NC} Применить ВСЕ настройки безопасности"
    echo -e "  ${GREEN}7)${NC} Назад"
    echo ""
    read -p "$(echo -e ${YELLOW}👉 Выберите действие [1-7]:${NC} )" SEC_ACTION
    
    case $SEC_ACTION in
        1)
            set_ssh_param "PasswordAuthentication" "no" "$CONFIG_FILE"
            print_success "Парольная аутентификация ОТКЛЮЧЕНА"
            restart_ssh
            ;;
        2)
            set_ssh_param "PermitRootLogin" "prohibit-password" "$CONFIG_FILE"
            print_success "Root вход разрешён только по ключам"
            restart_ssh
            ;;
        3)
            read -p "Максимум попыток (рекомендуется 3-6): " MAX_TRIES
            set_ssh_param "MaxAuthTries" "$MAX_TRIES" "$CONFIG_FILE"
            print_success "MaxAuthTries установлен на $MAX_TRIES"
            restart_ssh
            ;;
        4)
            read -p "Максимум сессий (рекомендуется 5-10): " MAX_SESSIONS
            set_ssh_param "MaxSessions" "$MAX_SESSIONS" "$CONFIG_FILE"
            print_success "MaxSessions установлен на $MAX_SESSIONS"
            restart_ssh
            ;;
        5)
            read -p "Интервал проверки в секундах (300 = 5 минут): " CLIENT_ALIVE
            set_ssh_param "ClientAliveInterval" "$CLIENT_ALIVE" "$CONFIG_FILE"
            set_ssh_param "ClientAliveCountMax" "3" "$CONFIG_FILE"
            print_success "Таймауты настроены"
            restart_ssh
            ;;
        6)
            set_ssh_param "PasswordAuthentication" "no" "$CONFIG_FILE"
            set_ssh_param "PermitRootLogin" "prohibit-password" "$CONFIG_FILE"
            set_ssh_param "MaxAuthTries" "3" "$CONFIG_FILE"
            set_ssh_param "MaxSessions" "5" "$CONFIG_FILE"
            set_ssh_param "ClientAliveInterval" "300" "$CONFIG_FILE"
            set_ssh_param "ClientAliveCountMax" "3" "$CONFIG_FILE"
            set_ssh_param "PermitEmptyPasswords" "no" "$CONFIG_FILE"
            set_ssh_param "ChallengeResponseAuthentication" "no" "$CONFIG_FILE"
            set_ssh_param "PrintLastLog" "yes" "$CONFIG_FILE"
            set_ssh_param "IgnoreRhosts" "yes" "$CONFIG_FILE"
            set_ssh_param "StrictModes" "yes" "$CONFIG_FILE"
            print_success "Все настройки безопасности применены"
            restart_ssh
            ;;
        7) show_main_menu ;;
        *) print_error "Неверный выбор" ;;
    esac
    
    # Проверка конфигурации
    if test_ssh_config; then
        print_success "Конфигурация валидна"
    else
        print_error "Ошибка в конфигурации! Восстанавливаем бэкап..."
        mv "$backup_file" "$CONFIG_FILE"
        restart_ssh
    fi
    
    echo ""
    read -p "Нажмите Enter для продолжения..."
    show_main_menu
}

# ============================================================
# 3. СМЕНА ПОРТА
# ============================================================

change_port() {
    print_header "СМЕНА SSH ПОРТА"
    
    local current_port=$(grep -E "^Port" "$CONFIG_FILE" | awk '{print $2}')
    [ -z "$current_port" ] && current_port=22
    
    echo -e "${CYAN}Текущий порт:${NC} $current_port"
    echo ""
    
    while true; do
        read -p "$(echo -e ${YELLOW}🟢 Введите новый порт [1024-65535]:${NC} )" NEW_PORT
        
        if [[ "$NEW_PORT" =~ ^[0-9]+$ ]] && [ "$NEW_PORT" -ge 1024 ] && [ "$NEW_PORT" -le 65535 ]; then
            break
        else
            print_error "Порт должен быть от 1024 до 65535"
        fi
    done
    
    local backup_file=$(create_backup)
    
    # Меняем порт
    if grep -q "^Port" "$CONFIG_FILE"; then
        sed -i "s/^Port .*/Port $NEW_PORT/" "$CONFIG_FILE"
    else
        echo "Port $NEW_PORT" >> "$CONFIG_FILE"
    fi
    
    # Настройка фаерволла
    echo ""
    read -p "$(echo -e ${YELLOW}Автоматически настроить UFW? (y/n):${NC} )" DO_UFW
    if [ "$DO_UFW" = "y" ]; then
        configure_ufw "$NEW_PORT"
        read -p "Закрыть старый порт $current_port? (y/n): " CLOSE_OLD
        if [ "$CLOSE_OLD" = "y" ] && [ "$current_port" != "22" ]; then
            ufw delete allow "$current_port"/tcp 2>/dev/null
            print_success "Порт $current_port закрыт"
        fi
    fi
    
    # Проверка
    if test_ssh_config; then
        restart_ssh
        print_success "Порт изменён на $NEW_PORT"
        print_warning "НЕ ЗАКРЫВАЙТЕ ЭТУ СЕССИЮ!"
        print_highlight "Проверьте новое подключение: ssh -p $NEW_PORT root@$(hostname -I | awk '{print $1}')"
    else
        print_error "Ошибка! Восстанавливаем..."
        mv "$backup_file" "$CONFIG_FILE"
        restart_ssh
    fi
    
    echo ""
    read -p "После успешной проверки нажмите Enter..."
    show_main_menu
}

# ============================================================
# 4. ПОЛНАЯ НАСТРОЙКА
# ============================================================

full_setup() {
    print_header "ПОЛНАЯ НАСТРОЙКА SSH"
    print_warning "Будет выполнена полная настройка безопасности"
    
    read -p "Продолжить? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        show_main_menu
        return
    fi
    
    local backup_file=$(create_backup)
    
    # 1. Ключи
    print_info "1/4: Установка ключей..."
    mkdir -p /root/.ssh
    curl -s https://github.com/mrpltrans.keys > /root/.ssh/authorized_keys
    chmod 700 /root/.ssh
    chmod 600 /root/.ssh/authorized_keys
    print_success "Ключи установлены"
    
    # 2. Безопасность
    print_info "2/4: Настройка безопасности..."
    set_ssh_param "PasswordAuthentication" "no" "$CONFIG_FILE"
    set_ssh_param "PermitRootLogin" "prohibit-password" "$CONFIG_FILE"
    set_ssh_param "MaxAuthTries" "3" "$CONFIG_FILE"
    set_ssh_param "MaxSessions" "5" "$CONFIG_FILE"
    set_ssh_param "ClientAliveInterval" "300" "$CONFIG_FILE"
    set_ssh_param "PermitEmptyPasswords" "no" "$CONFIG_FILE"
    set_ssh_param "PubkeyAuthentication" "yes" "$CONFIG_FILE"
    print_success "Безопасность настроена"
    
    # 3. Порт (опционально)
    print_info "3/4: Настройка порта..."
    read -p "Сменить SSH порт? (y/n): " CHANGE_PORT
    if [ "$CHANGE_PORT" = "y" ]; then
        while true; do
            read -p "Введите новый порт: " NEW_PORT
            if [[ "$NEW_PORT" =~ ^[0-9]+$ ]] && [ "$NEW_PORT" -ge 1024 ] && [ "$NEW_PORT" -le 65535 ]; then
                break
            fi
        done
        set_ssh_param "Port" "$NEW_PORT" "$CONFIG_FILE"
        configure_ufw "$NEW_PORT"
        FINAL_PORT=$NEW_PORT
    else
        FINAL_PORT=22
    fi
    
    # 4. Применение
    print_info "4/4: Применение настроек..."
    if test_ssh_config; then
        restart_ssh
        print_success "Настройки применены!"
    else
        print_error "Ошибка! Восстанавливаем..."
        mv "$backup_file" "$CONFIG_FILE"
        restart_ssh
        exit 1
    fi
    
    # Финальный вывод
    clear
    print_header "НАСТРОЙКА ЗАВЕРШЕНА"
    echo ""
    echo -e "${GREEN}  ✅ SSH настроен максимально безопасно!${NC}"
    echo ""
    echo -e "${CYAN}📋 Итоговые настройки:${NC}"
    echo -e "  • SSH порт: ${WHITE}$FINAL_PORT${NC}"
    echo -e "  • Пароли: ${RED}ОТКЛЮЧЕНЫ${NC}"
    echo -e "  • Ключи: ${GREEN}ВКЛЮЧЕНЫ${NC}"
    echo ""
    echo -e "${CYAN}🔑 Ваши ключи:${NC}"
    cat /root/.ssh/authorized_keys
    echo ""
    echo -e "${CYAN}📝 Подключение:${NC}"
    if [ "$FINAL_PORT" = "22" ]; then
        echo -e "  ssh root@$(hostname -I | awk '{print $1}')"
    else
        echo -e "  ssh -p $FINAL_PORT root@$(hostname -I | awk '{print $1}')"
    fi
    echo ""
    echo -e "${RED}⚠️  КРИТИЧНО: НЕ ЗАКРЫВАЙТЕ ЭТУ СЕССИЮ, пока не проверите новое подключение!${NC}"
    echo ""
    read -p "Нажмите Enter для продолжения..."
    show_main_menu
}

# ============================================================
# 5. ВОССТАНОВЛЕНИЕ ИЗ БЭКАПА
# ============================================================

restore_backup() {
    print_header "ВОССТАНОВЛЕНИЕ ИЗ БЭКАПА"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        print_error "Бэкапы не найдены"
        read -p "Нажмите Enter..."
        show_main_menu
        return
    fi
    
    echo -e "${CYAN}Доступные бэкапы:${NC}"
    ls -lh "$BACKUP_DIR" | tail -n +2
    
    echo ""
    read -p "Введите имя файла для восстановления: " BACKUP_FILE
    
    if [ -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
        cp "$BACKUP_DIR/$BACKUP_FILE" "$CONFIG_FILE"
        restart_ssh
        print_success "Конфигурация восстановлена"
    else
        print_error "Файл не найден"
    fi
    
    read -p "Нажмите Enter..."
    show_main_menu
}

# ============================================================
# 6. ПОКАЗАТЬ КОНФИГУРАЦИЮ
# ============================================================

show_config() {
    print_header "ТЕКУЩАЯ КОНФИГУРАЦИЯ SSH"
    
    echo -e "${CYAN}Активные настройки:${NC}"
    echo ""
    grep -E "^(Port|PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|MaxAuthTries|MaxSessions|ClientAliveInterval)" "$CONFIG_FILE" | grep -v "^#" || echo "Стандартные настройки"
    echo ""
    
    echo -e "${CYAN}Установленные ключи:${NC}"
    if [ -f /root/.ssh/authorized_keys ]; then
        cat /root/.ssh/authorized_keys
    else
        echo "Ключи не найдены"
    fi
    echo ""
    
    read -p "Нажмите Enter..."
    show_main_menu
}

# ============================================================
# 7. ДОПОЛНИТЕЛЬНЫЕ НАСТРОЙКИ
# ============================================================

advanced_settings() {
    print_header "ДОПОЛНИТЕЛЬНЫЕ НАСТРОЙКИ"
    
    echo ""
    echo -e "  ${GREEN}1)${NC} Установка и настройка Fail2ban"
    echo -e "  ${GREEN}2)${NC} Настройка SSH баннера (предупреждение)"
    echo -e "  ${GREEN}3)${NC} Ограничение пользователей (AllowUsers/DenyUsers)"
    echo -e "  ${GREEN}4)${NC} Настройка TCP Wrappers"
    echo -e "  ${GREEN}5)${NC} Назад"
    echo ""
    read -p "$(echo -e ${YELLOW}👉 Выберите действие [1-5]:${NC} )" ADV_ACTION
    
    case $ADV_ACTION in
        1)
            print_info "Установка Fail2ban..."
            apt update && apt install fail2ban -y
            cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = $(grep -E "^Port" "$CONFIG_FILE" | awk '{print $2}' || echo "22")
logpath = %(sshd_log)s
backend = %(sshd_backend)s
EOF
            systemctl restart fail2ban
            print_success "Fail2ban установлен и настроен"
            ;;
        2)
            print_info "Настройка баннера..."
            cat > /etc/ssh/ssh-banner << 'EOF'
********************************************************************
    ВНИМАНИЕ! ТОЛЬКО АВТОРИЗОВАННЫЙ ДОСТУП!
    Все действия логируются. Несанкционированный доступ запрещён.
********************************************************************
EOF
            set_ssh_param "Banner" "/etc/ssh/ssh-banner" "$CONFIG_FILE"
            restart_ssh
            print_success "Баннер настроен"
            ;;
        3)
            print_info "Ограничение пользователей..."
            read -p "Разрешить только конкретных пользователей (через пробел): " ALLOW_USERS
            set_ssh_param "AllowUsers" "$ALLOW_USERS" "$CONFIG_FILE"
            restart_ssh
            print_success "Доступ разрешён только для: $ALLOW_USERS"
            ;;
        4)
            print_info "TCP Wrappers..."
            echo "sshd: ALL" >> /etc/hosts.deny
            echo "sshd: $(hostname -I | awk '{print $1}')" >> /etc/hosts.allow
            print_success "TCP Wrappers настроены"
            ;;
        5) show_main_menu ;;
        *) print_error "Неверный выбор" ;;
    esac
    
    read -p "Нажмите Enter..."
    show_main_menu
}

# ============================================================
# ЗАПУСК
# ============================================================

main() {
    check_root
    mkdir -p "$BACKUP_DIR"
    touch "$LOG_FILE"
    show_main_menu
}

main
