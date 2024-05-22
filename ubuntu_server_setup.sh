GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${GREEN}Setting timezone to Moscow${NC}"
sudo timedatectl set-timezone Europe/Moscow


echo -e "${GREEN}Updating packages"
sudo apt update
sudo apt upgrade -y


echo -e "${GREEN}Installing Anaconda3${NC}"
CONDA_PATH="/opt/anaconda3"
if [ -d "$CONDA_PATH" ]; then
    echo -e "${YELLOW}Anaconda3 is already installed${NC}"
else
    CONDA_ARCHIVE_PATH="https://repo.anaconda.com/archive"
    CONDA_LATEST_NAME=$(wget -qO- https://repo.anaconda.com/archive/ | grep -Eo "(href=\")(Anaconda3-.*-Linux-x86_64.sh)*\"" | sed 's/href=//g' | sed 's/\"//g' | head -n 1)
    #Anaconda dependences
    apt install libgl1-mesa-glx libegl1-mesa libxrandr2 libxrandr2 libxss1 libxcursor1 libxcomposite1 libasound2 libxi6 libxtst6
    #Download anaconda
    wget $CONDA_ARCHIVE_PATH/$CONDA_LATEST_NAME
    #Allow
    chmod 700 $CONDA_LATEST_NAME
    #Install anaconda
    bash ./$CONDA_LATEST_NAME -b -p $CONDA_PATH
    #Remove anaconda installer
    rm ./$CONDA_LATEST_NAME
    #Switch default shell to anaconda promt
    $CONDA_PATH/conda init
fi


JUPYTERHUB_CONFIG_DIR_PATH="/etc/jupyterhub"
echo -e "${GREEN}Installing jupyterhub${NC}"
if [ -d "$JUPYTERHUB_CONFIG_DIR_PATH" ]; then
    echo -e "${YELLOW}Jupyterhub is already installed${NC}"
else
    apt install nodejs npm
    npm install -g configurable-http-proxy
    $CONDA_PATH/bin/conda install jupyter jupyterhub
    mkdir $JUPYTERHUB_CONFIG_DIR_PATH
    cat \
    'c = get_config()  #noqa

    c.JupyterHub.authenticate_prometheus = False

    c.Authenticator.admin_users = set(["user"])' >> $JUPYTERHUB_CONFIG_DIR_PATH/jupyterhub_config.py
    

    echo -e "${GREEN}Making jupyterhub system server${NC}"
    cat > /etc/systemd/system/jupyterhub.service << EOF
[Unit]
Description=Jupyterhub
After=syslog.target network.target

[Service]
User=root
Environment="PATH=/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/opt/anaconda3/bin"
ExecStart=/opt/anaconda3/bin/jupyterhub -f /etc/jupyterhub/jupyterhub_config.py

[Install]
WantedBy=multi-user.target
EOF
    systemctl enable jupyterhub
    systemctl start jupyterhub
fi


echo -e "${GREEN}Installing Node exporter${NC}"
apt install prometheus-node-exporter -y


echo -e "${GREEN}Installing qsweepy${NC}"
BRANCH="DR2"
$CONDA_PATH/bin/pip install git+https://github.com/ooovector/qsweepy.git@$BRANCH


echo -e "${GREEN}Mounting shared folders with measurements${NC}"
MEASUREMENTS_DIR_PATH="/media/measurements"
if [ ! -d "$MEASUREMENTS_DIR_PATH" ]; then
    mkdir $MEASUREMENTS_DIR_PATH
fi
MEASURER_IP_LIST=("10.1.0.83" "10.1.0.82")
SAMBA_USERNAME="user"
SAMBA_PASSWD="superconductivity"
for i in ${!MEASURER_IP_LIST[@]}; do
    if [ ! -d "$MEASUREMENTS_DIR_PATH/measurer-$((i+1))" ]; then
        mkdir $MEASUREMENTS_DIR_PATH/measurer-$((i+1))
    fi
    # add to etc/fstab in order to mount after reboot
    IP=${MEASURER_IP_LIST[$i]}
    echo -e "Mounting measurements data from $IP at $MEASUREMENTS_DIR_PATH/measurer-$((i+1))${NC}"
    ENTRY="//$IP/data $MEASUREMENTS_DIR_PATH/measurer-$((i+1)) cifs username=$SAMBA_USERNAME,password=$SAMBA_PASSWD,file_mode=0444,dir_mode=0555 0 0"
    if ! grep -Fxq "$ENTRY" /etc/fstab; then
        echo $ENTRY >> /etc/fstab
        echo -e "${GREEN}Succes${NC}"
    else
        echo -e "${YELLOW}Already added to fstab${NC}"
    fi
done
mount -a
