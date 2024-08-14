#!/bin/bash
# Autor: Jrohy
# GitHub: https://github.com/Jrohy/multi-v2ray

# Registra o caminho onde o script foi iniciado
begin_path=$(pwd)

# Método de instalação, 0 para nova instalação, 1 para atualizar mantendo a configuração do V2Ray
install_way=0

# Definição de variáveis de operação, 0 para não, 1 para sim
help=0

remove=0

chinese=0

base_source_path="https://multi.netlify.app"

util_path="/etc/v2ray_util/util.cfg"

util_cfg="$base_source_path/v2ray_util/util_core/util.cfg"

bash_completion_shell="$base_source_path/v2ray"

clean_iptables_shell="$base_source_path/v2ray_util/global_setting/clean_iptables.sh"

# CentOS: Temporariamente remove alias
[[ -f /etc/redhat-release && -z $(echo $SHELL|grep zsh) ]] && unalias -a

[[ -z $(echo $SHELL|grep zsh) ]] && env_file=".bashrc" || env_file=".zshrc"

####### Códigos de cor ########
red="31m"
green="32m"
yellow="33m"
blue="36m"
fuchsia="35m"

colorEcho(){
    color=$1
    echo -e "\033[${color}${@:2}\033[0m"
}

####### Obter parâmetros #########
while [[ $# > 0 ]];do
    key="$1"
    case $key in
        --remove)
        remove=1
        ;;
        -h|--help)
        help=1
        ;;
        -k|--keep)
        install_way=1
        colorEcho ${blue} "mantendo a configuração para atualizar\n"
        ;;
        --zh)
        chinese=1
        colorEcho ${blue} "Instalando versão em Português..\n"
        ;;
        *)
                # opção desconhecida
        ;;
    esac
    shift # passa para o próximo argumento ou valor
done
#############################

help(){
    echo "bash v2ray.sh [-h|--help] [-k|--keep] [--remove]"
    echo "  -h, --help           Mostrar ajuda"
    echo "  -k, --keep           Manter o config.json para atualizar"
    echo "      --remove         Remover v2ray, xray e multi-v2ray"
    echo "                       Sem parâmetros para nova instalação"
    return 0
}

removeV2Ray() {
    # Desinstala o V2Ray
    bash <(curl -L -s https://raw.githubusercontent.com/PhoenixxZ2023/PLUS/Modulo/go.sh) --remove >/dev/null 2>&1
    rm -rf /etc/v2ray >/dev/null 2>&1
    rm -rf /var/log/v2ray >/dev/null 2>&1

    # Desinstala o Xray
    bash <(curl -L -s https://raw.githubusercontent.com/PhoenixxZ2023/PLUS/Modulo/go.sh) --remove -x >/dev/null 2>&1
    rm -rf /etc/xray >/dev/null 2>&1
    rm -rf /var/log/xray >/dev/null 2>&1

    # Limpa as regras do iptables relacionadas ao V2Ray
    bash <(curl -L -s $clean_iptables_shell)

    # Desinstala o multi-v2ray
    pip uninstall v2ray_util -y
    rm -rf /usr/share/bash-completion/completions/v2ray.bash >/dev/null 2>&1
    rm -rf /usr/share/bash-completion/completions/v2ray >/dev/null 2>&1
    rm -rf /usr/share/bash-completion/completions/xray >/dev/null 2>&1
    rm -rf /etc/bash_completion.d/v2ray.bash >/dev/null 2>&1
    rm -rf /usr/local/bin/v2ray >/dev/null 2>&1
    rm -rf /etc/v2ray_util >/dev/null 2>&1
    rm -rf /etc/profile.d/iptables.sh >/dev/null 2>&1
    rm -rf /root/.iptables >/dev/null 2>&1

    # Remove a tarefa cron de atualização do V2Ray
    crontab -l|sed '/SHELL=/d;/v2ray/d'|sed '/SHELL=/d;/xray/d' > crontab.txt
    crontab crontab.txt >/dev/null 2>&1
    rm -f crontab.txt >/dev/null 2>&1

    if [[ ${package_manager} == 'dnf' || ${package_manager} == 'yum' ]];then
        systemctl restart crond >/dev/null 2>&1
    else
        systemctl restart cron >/dev/null 2>&1
    fi

    # Remove as variáveis de ambiente do multi-v2ray
    sed -i '/v2ray/d' ~/$env_file
    sed -i '/xray/d' ~/$env_file
    source ~/$env_file

    rc_service=`systemctl status rc-local|grep loaded|egrep -o "[A-Za-z/]+/rc-local.service"`

    rc_file=`cat $rc_service|grep ExecStart|awk '{print $1}'|cut -d = -f2`

    sed -i '/iptables/d' ~/$rc_file

    colorEcho ${green} "Desinstalação concluída com sucesso!"
}

closeSELinux() {
    # Desativa o SELinux
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

checkSys() {
    # Verifica se o usuário é root
    [ $(id -u) != "0" ] && { colorEcho ${red} "Erro: Você precisa ser root para executar este script"; exit 1; }

    if [[ `command -v apt-get` ]];then
        package_manager='apt-get'
    elif [[ `command -v dnf` ]];then
        package_manager='dnf'
    elif [[ `command -v yum` ]];then
        package_manager='yum'
    else
        colorEcho $red "Sistema operacional não suportado!"
        exit 1
    fi
}

# Instala as dependências
installDependent(){
    if [[ ${package_manager} == 'dnf' || ${package_manager} == 'yum' ]];then
        ${package_manager} install socat crontabs bash-completion which -y
    else
        ${package_manager} update
        ${package_manager} install socat cron bash-completion ntpdate gawk -y
    fi

    # Instala Python3 e pip
    source <(curl -sL https://python3.netlify.app/install.sh)
}

updateProject() {
    [[ ! $(type pip 2>/dev/null) ]] && colorEcho $red "pip não instalado!" && exit 1

    [[ -e /etc/profile.d/iptables.sh ]] && rm -f /etc/profile.d/iptables.sh

    rc_service=`systemctl status rc-local|grep loaded|egrep -o "[A-Za-z/]+/rc-local.service"`

    rc_file=`cat $rc_service|grep ExecStart|awk '{print $1}'|cut -d = -f2`

    if [[ ! -e $rc_file || -z `cat $rc_file|grep iptables` ]];then
        local_ip=`curl -s http://api.ipify.org 2>/dev/null`
        [[ `echo $local_ip|grep :` ]] && iptable_way="ip6tables" || iptable_way="iptables" 
        if [[ ! -e $rc_file || -z `cat $rc_file|grep "/bin/bash"` ]];then
            echo "#!/bin/bash" >> $rc_file
        fi
        if [[ -z `cat $rc_service|grep "\[Install\]"` ]];then
            cat >> $rc_service << EOF

[Install]
WantedBy=multi-user.target
EOF
            systemctl daemon-reload
        fi
        echo "[[ -e /root/.iptables ]] && $iptable_way-restore -c < /root/.iptables" >> $rc_file
        chmod +x $rc_file
        systemctl restart rc-local
        systemctl enable rc-local

        $iptable_way-save -c > /root/.iptables
    fi

    pip install -U v2ray_util

    if [[ -e $util_path ]];then
        [[ -z $(cat $util_path|grep lang) ]] && echo "lang=en" >> $util_path
    else
        mkdir -p /etc/v2ray_util
        curl $util_cfg > $util_path
    fi

    [[ $chinese == 1 ]] && sed -i "s/lang=en/lang=pt/g" $util_path

    rm -f /usr/local/bin/v2ray >/dev/null 2>&1
    ln -s $(which v2ray-util) /usr/local/bin/v2ray
    rm -f /usr/local/bin/xray >/dev/null 2>&1
    ln -s $(which v2ray-util) /usr/local/bin/xray

    # Remove os scripts antigos de autocompletar
    rm -f /etc/bash_completion.d/v2ray.bash
    rm -f /usr/share/bash-completion/completions/v2ray.bash >/dev/null 2>&1
    rm -f /usr/share/bash-completion/completions/v2ray >/dev/null 2>&1
    rm -f /usr/share/bash-completion/completions/xray >/dev/null 2>&1

    curl -o /usr/share/bash-completion/completions/v2ray $bash_completion_shell
    cp /usr/share/bash-completion/completions/v2ray /usr/share/bash-completion/completions/xray
}

timeSync() {
    if [[ $package_manager == "apt-get" ]];then
        service cron stop 2>&1
        service cron start 2>&1
    else
        timedatectl set-ntp true
        systemctl restart crond
    fi

    ntpdate time.cloudflare.com
    if [[ $? == 0 ]];then
        colorEcho ${green} "Sincronização da hora bem-sucedida"
        echo "*/30 * * * * $(which ntpdate) time.cloudflare.com &> /dev/null" >> crontab.txt
    else
        colorEcho ${red} "Falha na sincronização da hora"
        echo "*/30 * * * * $(which ntpdate) time.nist.gov &> /dev/null" >> crontab.txt
    fi
    crontab crontab.txt >/dev/null 2>&1
    rm -f crontab.txt
}

# Função de inicialização de perfil
profileInit() {
    # Remove variáveis antigas do ambiente
    sed -i '/v2ray/d' ~/$env_file
    sed -i '/xray/d' ~/$env_file

    # Variáveis de ambiente de inicialização do Python
    cat >> ~/$env_file << EOF
# Configurações do V2Ray
export V2RAY_VMESS_AEAD_FORCED=false
export V2RAY_VMESS_AEAD_DISABLED=true
EOF
    source ~/$env_file

    if [[ $install_way == 0 ]];then
        v2ray new config
        [ $? == 0 ] && v2ray info || exit 1
    fi
}

# Nova instalação ou atualização, após a execução, retorna ao diretório inicial
cd /root
closeSELinux
checkSys
installDependent
updateProject
timeSync
profileInit
cd $begin_path

if [[ $install_way == 0 ]];then
    echo -e "\033[31mInstalação concluída!\033[0m\n"
    echo -e "\033[33mPor favor, execute o comando \033[34mv2ray info\033[33m para verificar as informações de configuração do V2Ray\033[0m"
else
    colorEcho ${green} "Atualização concluída!"
fi
