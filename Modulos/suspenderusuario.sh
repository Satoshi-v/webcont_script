#!/bin/bash

# Caminho do diretório do SSHPLUS
sshplus_DIR="/etc/sshplus"

# Verificar se o SSHPLUS está instalado
if [ ! -d "$sshplus_DIR" ]; then
    echo -e "${RED}O SSHPLUS não está instalado no diretório esperado (${sshplus_DIR}).${NC}"
    exit 1
fi

# Cores para mensagens
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sem cor

# Função para suspender usuário
suspender_usuario() {
    read -p "Digite o nome do usuário que deseja suspender: " usuario
    if id "$usuario" &>/dev/null; then
        usermod -L "$usuario"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Usuário '$usuario' foi suspenso com sucesso.${NC}"
        else
            echo -e "${RED}Falha ao suspender o usuário '$usuario'.${NC}"
        fi
    else
        echo -e "${RED}Usuário '$usuario' não encontrado.${NC}"
    fi
}

# Função para reativar usuário
reativar_usuario() {
    read -p "Digite o nome do usuário que deseja reativar: " usuario
    if id "$usuario" &>/dev/null; then
        usermod -U "$usuario"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Usuário '$usuario' foi reativado com sucesso.${NC}"
        else
            echo -e "${RED}Falha ao reativar o usuário '$usuario'.${NC}"
        fi
    else
        echo -e "${RED}Usuário '$usuario' não encontrado.${NC}"
    fi
}

# Função para exibir o menu de suspender os usuários
menu_suspenderusuario() {
    while true; do
        clear
        echo -e "${BLUE}=========================================${NC}"
        echo -e "${YELLOW}      SUSPENDER USUÁRIOS                     ${NC}"
        echo -e "${BLUE}=========================================${NC}"
        echo -e "${YELLOW}1. SUSPENDER USUÁRIO${NC}"
        echo -e "${YELLOW}2. REATIVAR USUARIO${NC}"
        echo -e "${YELLOW}3. RETORNAR AO MENU${NC}"
        echo -e "${BLUE}=========================================${NC}"

        read -p "Escolha uma opção: " opcao

        case $opcao in
            1)
                suspender_usuario
                ;;
            2)
                reativar_usuario
                ;;
            3)
                menu
                ;;
            *)
                echo -e "${RED}Opção inválida. Por favor, tente novamente.${NC}"
                ;;
        esac
        read -p "Pressione Enter para continuar..." enter
    done
}

# Baixar o script de gerenciamento de usuários
echo "Criando script de suspender os usuários..."
cat << 'EOF' > "$sshplus_DIR/suspenderusuario.sh"
#!/bin/bash

# Cores para mensagens
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sem cor

# Função para suspender usuário
suspender_usuario() {
    read -p "Digite o nome do usuário que deseja suspender: " usuario
    if id "$usuario" &>/dev/null; then
        usermod -L "$usuario"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Usuário '$usuario' foi suspenso com sucesso.${NC}"
        else
            echo -e "${RED}Falha ao suspender o usuário '$usuario'.${NC}"
        fi
    else
        echo -e "${RED}Usuário '$usuario' não encontrado.${NC}"
    fi
}

# Função para reativar usuário
reativar_usuario() {
    read -p "Digite o nome do usuário que deseja reativar: " usuario
    if id "$usuario" &>/dev/null; then
        usermod -U "$usuario"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Usuário '$usuario' foi reativado com sucesso.${NC}"
        else
            echo -e "${RED}Falha ao reativar o usuário '$usuario'.${NC}"
        fi
    else
        echo -e "${RED}Usuário '$usuario' não encontrado.${NC}"
    fi
}

# Função para exibir o menu de suspender os usuários
menu_suspenderusuario() {
    while true; do
        clear
        echo -e "${BLUE}=========================================${NC}"
        echo -e "${YELLOW}      SUSPENDER USUÁRIOS                     ${NC}"
        echo -e "${BLUE}=========================================${NC}"
        echo -e "${YELLOW}1. SUSPENDER USUÁRIO${NC}"
        echo -e "${YELLOW}2. REATIVAR USUÁRIO${NC}"
        echo -e "${YELLOW}3. RETORNAR AO MENU${NC}"
        echo -e "${BLUE}=========================================${NC}"

        read -p "Escolha uma opção: " opcao

        case $opcao in
            1)
                suspender_usuario
                ;;
            2)
                reativar_usuario
                ;;
            3)
                menu
                ;;
            *)
                echo -e "${RED}Opção inválida. Por favor, tente novamente.${NC}"
                ;;
        esac
        read -p "Pressione Enter para continuar..." enter
    done
}

menu_gerenciamento_usuarios
EOF

# Tornar o script executável
chmod +x "$sshplus_DIR/suspenderusuario.sh"

# Adicionar a chamada ao menu principal do SSHPLUS
if ! grep -q "menu_suspenderusuario" "$sshplus_DIR/menu"; then
    echo "funcoes+=(menu_suspenderusuario)" >> "$sshplus_DIR/menu"
    echo "alias 7='$sshplus_DIR/suspenderusuario.sh'" >> "$sshplus_DIR/menu"
    echo -e "${GREEN}Opção de gerenciamento de usuários adicionada ao menu principal do SSHPLUS.${NC}"
else
    echo -e "${YELLOW}O menu de suspender usuário já está integrado ao menu principal do SSHPLUS.${NC}"
fi

echo -e "${GREEN}Instalação concluída.${NC}"
