sudo apt update
sudo apt upgrade
printf '\nInstalling packages...\n'
sudo apt install docker docker-compose vim curl
printf '\nSetting up docker group\n'
sudo groupadd docker
sudo usermod -aG docker $USER

sudo mkdir -p /volumes/{mariadb-persistence,wordpress-persistence,nginx-persistence/certificates,bitnami-persistence}

printf "\nEnter the server name you would like to use: example.org www.example.org\n"
SERVER_NAME=""
while [[ $SERVER_NAME == "" ]]; do
  read -p ": " SERVER_NAME
done

SETUP_ENV_VARS_COMPLETE="false"
while [[ $SETUP_ENV_VARS_COMPLETE == "false" ]]; do
  printf "\nHave you updated the environment variables in the .env file? (y/N)\n"
  read -p ": " answer
  if [[ $answer == "y" ]]; then
    SETUP_ENV_VARS_COMPLETE="true"
  else
    vim .env
  fi
done

printf "\nDo you want to create a user with the correct uid for the docker container, this is useful when uploading files over a SFTP client to set the correct permissions (y/N)\n"
SETUP_UID_USER_COMPLETE="false"
while [[ $SETUP_UID_USER_COMPLETE == "false" ]]; do
  read -p ": " answer
  if [[ $answer == "y" ]]; then
    read -p "Enter the username [bitnami]: " username
    username=${username:-'bitnami'}
    printf 'Adding user: %s\n' $username
    # sudo useradd -m -u 1001 $username
    sudo adduser --uid 1001 $username
    # printf 'Set password for %s\n' $username
    # sudo passwd $username
  fi
  SETUP_UID_USER_COMPLETE="true"
done

printf "\nDo you want to use HTTPS?\nIf so have you pointed the dns records to this server (y/N)\n"
SETUP_HTTPS_COMPLETE="false"
use_https=""
while [[ $SETUP_HTTPS_COMPLETE == "false" ]]; do
  read -p ": " use_https
  if [[ $use_https == "y" ]]; then

    if [[ ! -f "/usr/local/bin/lego" ]]; then
      BASEDIR=$(pwd)
      cd /tmp
      curl -Ls https://api.github.com/repos/xenolf/lego/releases/latest | grep browser_download_url | grep linux_amd64 | cut -d '"' -f 4 | wget -i -
      tar xf lego_v*_linux_amd64.tar.gz
      sudo mv lego /usr/local/bin/lego
      cd $BASEDIR
    fi
    domains=""
    for i in "$SERVER_NAME"; do
      domains+=$(printf " --domains=%s" $i)
    done

    printf "Insert certificate holder email\n"
    cert_email=""
    while [[ $cert_email == "" ]]; do
      read -p ": " cert_email
    done

    ISSUE_CERT_COMPLETE="false"
    while [[ $ISSUE_CERT_COMPLETE == "false" ]]; do
      {
        sudo lego --tls --email=$cert_email $domains run --run-hook="./cert-hook.sh"
        sudo lego --tls --email=$cert_email $domains renew --days 90 --renew-hook="./cert-hook.sh"
        ISSUE_CERT_COMPLETE="true"
      } || {
        printf "Could not issue certificate have you pointed the dns records for ${SERVER_NAME} to this server?\nexiting\n"
        exit 1
      }
    done
  fi
  SETUP_HTTPS_COMPLETE="true"
done

printf '\nCreating nginx config\n'
sed "s/<<SERVER_NAME>>/$SERVER_NAME/g" ./wordpress-server-block.base.conf >./wordpress-server-block.conf
if [[ $use_https == "y" ]]; then
  sed "s/<<SERVER_NAME>>/$SERVER_NAME/g" ./wordpress-server-block.base.ssl.conf >>./wordpress-server-block.conf
fi
sudo mv ./wordpress-server-block.conf /volumes/nginx-persistence/wordpress-server-block.conf

printf '\nCopying bitnami-php.ini\n'
sudo cp ./bitnami-php.ini /volumes/bitnami-persistence/bitnami-php.ini

printf '\nSetting owner of volumes\n'
sudo chown -R 1001:root /volumes

if [[ ! $(getent group docker) ]]; then
  printf '\nCreating docker group\n'
  newgrp docker
fi

printf '\nEnabling autostart of docker\n'
sudo systemctl enable docker
printf '\nStarting docker\n'
docker-compose up -d
printf '\nSetup done service\n'
