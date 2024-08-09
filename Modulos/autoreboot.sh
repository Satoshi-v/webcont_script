#!/bin/bash

# Funções para exibir mensagens coloridas
function imprimir_verde() { echo -e "\e[32m$1\e[0m"; }
function imprimir_vermelho() { echo -e "\e[31m$1\e[0m"; }
function imprimir_amarelo() { echo -e "\e[33m$1\e[0m"; }

# Função para criar o script de reboot automático
function criar_script_reboot() {
    if [ ! -e /usr/local/bin/reboot_otomatis ]; então
        cat <<EOL > /usr/local/bin/reboot_otomatis
#!/bin/bash
data=\$(date +"%m-%d-%Y")
hora=\$(date +"%T")
echo "Servidor reiniciado com sucesso em \$data às \$hora." >> /root/log-reboot.txt
/sbin/shutdown -r now
EOL
        chmod +x /usr/local/bin/reboot_otomatis
    fi
}

# Função para exibir o menu
function mostrar_menu() {
    clear
    imprimir_amarelo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "\e[0;100;33m       • MENU DE AUTO-REBOOT •        \e[0m"
    imprimir_amarelo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e ""
    echo -e "[\e[36m•1\e[0m] Definir Auto-Reboot a Cada 1 Hora"
    echo -e "[\e[36m•2\e[0m] Definir Auto-Reboot a Cada 6 Horas"
    echo -e "[\e[36m•3\e[0m] Definir Auto-Reboot a Cada 12 Horas"
    echo -e "[\e[36m•4\e[0m] Definir Auto-Reboot a Cada 1 Dia"
    echo -e "[\e[36m•5\e[0m] Definir Auto-Reboot a Cada 1 Semana"
    echo -e "[\e[36m•6\e[0m] Definir Auto-Reboot a Cada 1 Mês"
    echo -e "[\e[36m•7\e[0m] Desativar Auto-Reboot"
    echo -e "[\e[36m•8\e[0m] Ver log de reboot"
    echo -e "[\e[36m•9\e[0m] Remover log de reboot"
    echo -e ""
    echo -e " [\e[31m•0\e[0m] \e[31mVOLTAR AO MENU\033[0m"
    echo -e ""
    echo -e "Pressione x ou [ Ctrl+C ] • Para sair"
    echo -e ""
    imprimir_amarelo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e ""
}

# Função para lidar com a seleção do usuário
function lidar_com_selecao() {
    read -p "Selecione o menu: " escolha
    case $escolha in
        1) definir_cron "10 * * * *"; imprimir_verde "Auto-Reboot definido a cada hora." ;;
        2) definir_cron "10 */6 * * *"; imprimir_verde "Auto-Reboot definido a cada 6 horas." ;;
        3) definir_cron "10 */12 * * *"; imprimir_verde "Auto-Reboot definido a cada 12 horas." ;;
        4) definir_cron "10 0 * * *"; imprimir_verde "Auto-Reboot definido uma vez por dia." ;;
        5) definir_cron "10 0 */7 * *"; imprimir_verde "Auto-Reboot definido uma vez por semana." ;;
        6) definir_cron "10 0 1 * *"; imprimir_verde "Auto-Reboot definido uma vez por mês." ;;
        7) remover_cron; imprimir_verde "Auto-Reboot desativado com sucesso." ;;
        8) ver_log ;;
        9) limpar_log; imprimir_verde "Log de Auto-Reboot apagado com sucesso!" ;;
        0) clear; m-system ;;
        *) imprimir_vermelho "Opção inválida. Por favor, tente novamente." ;;
    esac
}

# Funções auxiliares
function definir_cron() {
    echo "$1 root /usr/local/bin/reboot_otomatis" > /etc/cron.d/reboot_otomatis
}

function remover_cron() {
    rm -f /etc/cron.d/reboot_otomatis
}

function ver_log() {
    if [ ! -e /root/log-reboot.txt ]; então
        imprimir_amarelo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo -e "\e[0;100;33m        • LOG DE AUTO-REBOOT •        \e[0m"
        imprimir_amarelo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo -e ""
        echo "Nenhuma atividade de reboot encontrada"
        echo -e ""
        imprimir_amarelo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
    else
        imprimir_amarelo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo -e "\e[0;100;33m        • LOG DE AUTO-REBOOT •        \e[0m"
        imprimir_amarelo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo -e ""    
        echo 'LOG DE REBOOT'
        cat /root/log-reboot.txt
        echo -e ""
        imprimir_amarelo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
    fi
    read -n 1 -s -r -p "Pressione qualquer tecla para voltar ao menu"
    auto-reboot
}

function limpar_log() {
    > /root/log-reboot.txt
}

# Função principal
function principal() {
    criar_script_reboot
    while true; do
        mostrar_menu
        lidar_com_selecao
    done
}

# Limpar variáveis temporárias no final do script
trap 'unset meu_ip hoje data_expiracao permissao' EXIT

# Iniciar script
principal
