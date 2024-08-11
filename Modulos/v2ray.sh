#!/bin/bash
# Author: Jrohy
# github: https://github.com/Jrohy/multi-v2ray

# Registra o caminho inicial de execução do script
begin_path=$(pwd)

# Método de instalação, 0 para instalação limpa, 1 para atualizar mantendo a configuração do v2ray
install_way=0

# Define variáveis de operação, 0 para não, 1 para sim
help=0

remove=0

chinese=0

base_source_path="https://multi.netlify.app"

util_path="/etc/v2ray_util/util.cfg"

util_cfg="$base_source_path/v2ray_util/util_core/util.cfg"

bash_completion_shell="$base_source_path/v2ray"

clean_iptables_shell="$base_source_path/v2ray_util/global_setting/clean_iptables.sh"

# Centos desativa temporariamente alias
[[ -f /etc/redhat-release && -z $(echo $SHELL|grep zsh) ]] && unalias -a

[[ -z $(echo $SHELL|grep zsh) ]] && env_file=".bashrc" || env_file=".zshrc"

#######código de cor########
red="31m"
green="32m"
yellow="33m"
blue="36m"
fuchsia="35m"

colorEcho(){
    color=$1
    echo -e "\033[${color}${@:2}\033[0m"
}

#######obtém parâmetros#########
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
        colorEcho ${blue} "Manter configuração para atualização\n"
        ;;
        --zh)
        chinese=1
        colorEcho ${blue} "Instalando versão chinesa..\n"
        ;;
        *)
                # opção desconhecida
        ;;
    esac
    shift # passa o argumento ou valor
done
#############################

help(){
    echo "bash v2ray.sh [-h|--help] [-k|--keep] [--remove]"
    echo "  -h, --help           Mostrar ajuda"
    echo "  -k, --keep           Manter config.json para atualização"
    echo "      --remove         Remover v2ray, xray e multi-v2ray"
    echo "                       sem parâmetros para nova instalação"
    return 0
}

removeV2Ray() {
    # Remove o script V2ray
    bash <(curl -L -s https://multi.netlify.app/go.sh) --remove >/dev/null 2>&1
    rm -rf /etc/v2ray >/dev/null 2>&1
    rm -rf /var/log/v2ray >/dev/null 2>&1

    # Remove o script Xray
    bash <(curl -L -s https://multi.netlify.app/go.sh) --remove -x >/dev/null 2>&1
    rm -rf /etc/xray >/dev/null 2>&1
    rm -rf /var/log/xray >/dev/null 2>&1

    # Limpa regras de iptables relacionadas ao v2ray
    bash <(curl -L -s $clean_iptables_shell)

    # Remove multi-v2ray
    pip uninstall v2ray_util -y
    rm -rf /usr/share/bash-completion/completions/v2ray.bash >/dev/null 2>&1
    rm -rf /usr/share/bash-completion/completions/v2ray >/dev/null 2>&1
    rm -rf /usr/share/bash-completion/completions/xray >/dev/null 2>&1
    rm -rf /etc/bash_completion.d/v2ray.bash >/dev/null 2>&1
    rm -rf /usr/local/bin/v2ray >/dev/null 2>&1
    rm -rf /etc/v2ray_util >/dev/null 2>&1
    rm -rf /etc/profile.d/iptables.sh >/dev/null 2>&1
    rm -rf /root/.iptables >/dev/null 2>&1

    # Remove tarefas agendadas de v2ray
    crontab -l|sed '/SHELL=/d;/v2ray/d'|sed '/SHELL=/d;/xray/d' > crontab.txt
    crontab crontab.txt >/dev/null 2>&1
    rm -f crontab.txt >/dev/null 2>&1

    if [[ ${package_manager} == 'dnf' || ${package_manager} == 'yum' ]];then
        systemctl restart crond >/dev/null 2>&1
    else
        systemctl restart cron >/dev/null 2>&1
    fi

    # Remove variáveis de ambiente do multi-v2ray
    sed -i '/v2ray/d' ~/$env_file
    sed -i '/xray/d' ~/$env_file
    source ~/$env_file

    rc_service=`systemctl status rc-local|grep loaded|egrep -o "[A-Za-z/]+/rc-local.service"`

    rc_file=`cat $rc_service|grep ExecStart|awk '{print $1}'|cut -d = -f2`

    sed -i '/iptables/d' ~/$rc_file

    colorEcho ${green} "Desinstalação bem-sucedida!"
}

closeSELinux() {
    # Desativa SELinux
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

checkSys() {
    # Verifica se é root
    [ $(id -u) != "0" ] && { colorEcho ${red} "Erro: Você deve ser root para executar este script"; exit 1; }

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

# Instala dependências
installDependent(){
    if [[ ${package_manager} == 'dnf' || ${package_manager} == 'yum' ]];then
        ${package_manager} install socat crontabs bash-completion which -y
    else
        ${package_manager} update
        ${package_manager} install socat cron bash-completion ntpdate gawk -y
    fi

    # Instala python3 e pip
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

    [[ $chinese == 1 ]] && sed -i "s/lang=en/lang=zh/g" $util_path

    rm -f /usr/local/bin/v2ray >/dev/null 2>&1
    ln -s $(which v2ray-util) /usr/local/bin/v2ray
    rm -f /usr/local/bin/xray >/dev/null 2>&1
    ln -s $(which v2ray-util) /usr/local/bin/xray

    # Remove o antigo script de conclusão bash do v2ray
    [[ -e /etc/bash_completion.d/v2ray.bash ]] && rm -f /etc/bash_completion.d/v2ray.bash
    [[ -e /usr/share/bash-completion/completions/v2ray.bash ]] && rm -f /usr/share/bash-completion/completions/v2ray.bash

    # Atualiza o script de conclusão bash do v2ray
    curl $bash_completion_shell > /usr/share/bash-completion/completions/v2ray
    curl $bash_completion_shell > /usr/share/bash-completion/completions/xray
    if [[ -z $(echo $SHELL|grep zsh) ]];then
        source /usr/share/bash-completion/completions/v2ray
        source /usr/share/bash-completion/completions/xray
    fi
    
    # Instala o programa principal do V2ray
    [[ ${install_way} == 0 ]] && bash <(curl -L -s https://multi.netlify.app/go.sh)
}

# Sincroniza o tempo
timeSync() {
    if [[ ${install_way} == 0 ]];then
        echo -e "Sincronizando hora.. "
        if [[ `command -v ntpdate` ]];then
            ntpdate pool.ntp.org
        elif [[ `command -v chronyc` ]];then
            chronyc -a makestep
        fi

        if [[ $? -eq 0 ]];then 
            colorEcho $green "Sincronização de hora bem-sucedida"
            colorEcho $blue "agora: `date -R`"
        fi
    fi
}

profileInit() {

    # Limpa variáveis de ambiente do módulo v2ray
    [[ $(grep v2ray ~/$env_file) ]] && sed -i '/v2ray/d' ~/$env_file && source ~/$env_file

    # Resolve problema de exibição em chinês do Python3
    [[ -z $(grep PYTHONIOENCODING=utf-8 ~/$env_file) ]] && echo "export PYTHONIOENCODING=utf-8" >> ~/$env_file && source ~/$env_file

    # Nova configuração para instalação limpa
    [[ ${install_way} == 0 ]] && v2ray new

    echo ""
}

installFinish() {
    # Retorna ao ponto inicial
    cd ${begin_path}

    [[ ${install_way} == 0 ]] && WAY="instalação" || WAY="atualização"
    colorEcho  ${green} "multi-v2ray ${WAY} bem-sucedida!\n"

    if [[ ${install_way} == 0 ]]; then
        clear

        v2ray info

        echo -e "Por favor, digite o comando 'v2ray' para gerenciar o v2ray\n"
    fi
}

main() {

    [[ ${help} == 1 ]] && help && return

    [[ ${remove} == 1 ]] && removeV2Ray && return

    [[ ${install_way} == 0 ]] && colorEcho ${blue} "nova instalação\n"

    checkSys

    installDependent

    closeSELinux

    timeSync

    updateProject

    profileInit

    installFinish
}

main
