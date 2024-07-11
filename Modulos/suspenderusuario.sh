#!/bin/bash
#====================================================
#   @GERENCIAMENTO DE USUÁRIOS
#====================================================
# Função para suspender um usuário
suspend_user() {
    local username="$1"

    # Verifica se o usuário existe
    if id "$username" &>/dev/null; then
        echo -e "\n\033[1;32mSuspensão do usuário $username iniciada...\033[0m"

        # Desativa a conta do usuário
        usermod -L "$username"
        if [[ $? -ne 0 ]]; then
            echo -e "\033[1;31mErro ao desativar o usuário.\033[0m"
            return 1
        fi

        # Opcional: Remover ou desativar arquivos de configuração (exemplo para OpenVPN)
        if [[ -e /etc/openvpn/easy-rsa/pki/issued/$username.crt ]]; then
            rm -f /etc/openvpn/easy-rsa/pki/issued/$username.crt
            rm -f /etc/openvpn/easy-rsa/pki/private/$username.key
            rm -f /etc/openvpn/easy-rsa/pki/crl.pem
            echo -e "\033[1;32mArquivos de configuração do OpenVPN removidos.\033[0m"
        fi

        echo -e "\033[1;32mUsuário $username suspenso com sucesso.\033[0m"
    else
        echo -e "\033[1;31mUsuário $username não encontrado.\033[0m"
        return 1
    fi
}

# Função para reativar um usuário
reactivate_user() {
    local username="$1"

    # Verifica se o usuário existe
    if id "$username" &>/dev/null; then
        echo -e "\n\033[1;32mReativação do usuário $username iniciada...\033[0m"

        # Reativa a conta do usuário
        usermod -U "$username"
        if [[ $? -ne 0 ]]; then
            echo -e "\033[1;31mErro ao reativar o usuário.\033[0m"
            return 1
        fi

        # Opcional: Restaurar arquivos de configuração do OpenVPN (se necessário)
        # Adapte este bloco conforme sua necessidade
        echo -e "\033[1;32mUsuário $username reativado com sucesso.\033[0m"
    else
        echo -e "\033[1;31mUsuário $username não encontrado.\033[0m"
        return 1
    fi
}

# Função de menu para selecionar opções
menu() {
    clear
    echo -e "\033[1;44m\033[1;37m            MENU DE GERENCIAMENTO DE USUÁRIOS            \033[0m\033[0m"
    echo -e "\033[1;44m\033[1;37m=========================================================\033[0m\033[0m"
    echo ""
    echo -e "\033[1;36m[\033[1;32m1\033[1;36m]\033[1;37m SUSPENDER USUÁRIO"
    echo -e "\033[1;36m[\033[1;32m2\033[1;36m]\033[1;37m REATIVAR USUÁRIO"
    echo -e "\033[1;36m[\033[1;32m0\033[1;36m]\033[1;37m SAIR"
    echo ""
    echo -ne "\033[1;34mEscolha uma opção: \033[1;37m"
    read opcao
    case "$opcao" in
        1)
            echo -ne "\033[1;34mDigite o nome do usuário para suspender: \033[1;37m"
            read username
            suspend_user "$username"
            ;;
        2)
            echo -ne "\033[1;34mDigite o nome do usuário para reativar: \033[1;37m"
            read username
            reactivate_user "$username"
            ;;
        0)
            echo -e "\n\033[1;32mSaindo...\033[0m"
            menu
            ;;
        *)
            echo -e "\n\033[1;31mOpção inválida. Por favor, escolha uma opção válida.\033[0m"
            sleep 2
            ;;
    esac
}

# Executa o menu
while true; do
    menu
done
