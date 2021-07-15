#!/bin/bash
# @skkodali

_usage()
{
    echo  "bash -x gitlab-setup.sh <S3_PATH>"
}
_setEnv()
{
    echo "1st Argument is : ${1}"
    echo "2nd argument is : ${2}"

    AWS_ARTIFACTS_APP_BUCKET="aws-bigdata-blog"
    AWS_ARTIFACTS_APP_KEY="artifacts/awsblog-beanstalk-gitlab/baseline-application"
    AWS_ARTIFACTS_APP_ZIP_FILE="sample-nodejs-app.zip"

    GITLAB_INITIAL_ROOT_PASSWD="changeme"
    SAMPLE_PROJECT_TOKEN="AbCdEfGXyZ"
    SAMPLE_PRJ_DIR="sample-nodejs-app"
    DOCKER_USER=root

    MY_PUBLIC_IP=`curl http://169.254.169.254/latest/meta-data/public-ipv4`
    echo $MY_PUBLIC_IP

    MY_PUBLIC_HOSTNAME=`curl http://169.254.169.254/latest/meta-data/public-hostname`
    echo ${MY_PUBLIC_HOSTNAME}

    ETC_HOSTS_FILE="/etc/hosts"

    #URL="registry.beangitlab.com"
    URL=${2}
    CERT_DIR_PATH="/etc/gitlab/trusted-certs/"
    CERT_KEY="${URL}.key"
    CERT_CRT="${URL}.crt"
    AWS=aws
    S3_COPY="s3 cp"
    GIT_CE_URL="https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh"
    BASH="/bin/bash"
    OPENSSL_OPTIONS="/C=US/ST=London/L=London/O=BeangitlabInc/OU=DEV/CN=${URL}"
    OPENSSL_ADDEXT_OPTIONS="subjectAltName=DNS:${URL}"
    GITLAB_HOME="/etc/gitlab"
    GITLAB_CERTS_DIR=${GITLAB_HOME}/trusted-certs
    GITLAB_CONFIG_FILE="gitlab.rb"

    DOCKER_HOME="/etc/docker"

    GITLAB_RUNNER_HOME="/etc/gitlab-runner/"

}

_installPreRequiredPackages()
{
  sudo apt-get -y update
  sudo apt-get -y openssh-server postfix
  sudo apt install -y unzip
}

_installGitLabCE()
{
  curl -sS ${GIT_CE_URL} | sudo ${BASH}
  sudo GITLAB_ROOT_EMAIL="example@example.com" GITLAB_ROOT_PASSWORD="changeme" apt-get install gitlab-ce -y
}

_setupSSLCerts()
{
  cd /etc/gitlab/
  sudo chmod -R 755 /etc/gitlab/trusted-certs/
  cd ${GITLAB_CERTS_DIR}
  sudo openssl req -newkey rsa:4096 -nodes -sha256 -keyout ${GITLAB_CERTS_DIR}/${CERT_KEY} -x509 -days 365 -out ${GITLAB_CERTS_DIR}/${CERT_CRT} -subj ${OPENSSL_OPTIONS} -addext ${OPENSSL_ADDEXT_OPTIONS}
  sudo chmod 600 ${GITLAB_CERTS_DIR}/${CERT_KEY}
  sudo chmod 600 ${GITLAB_CERTS_DIR}/${CERT_CRT}
}

_upLoadToS3Path()
{
  echo "Copying cert file to s3 - s3://${1}/myca.crt"
  ${AWS} ${S3_COPY} ${GITLAB_CERTS_DIR}/${CERT_CRT} s3://${1}/myca.crt
  echo "Copying of cert file completed successfully."
}

_updateGitLabConfig()
{

  REGISTRY_URL_ENTRY="registry_external_url 'https:\/\/${URL}'"
  sudo sed -i "1i ${REGISTRY_URL_ENTRY}" ${GITLAB_HOME}/${GITLAB_CONFIG_FILE}
  echo ${REGISTRY_URL_ENTRY}

  # gitlab_rails['registry_path'] = "/var/opt/gitlab/gitlab-rails/shared/registry"
  REGISTRY_PATH="gitlab_rails[\'registry_path\'] = \"\/var\/opt\/gitlab\/gitlab-rails\/shared\/registry\""
  echo ${REGISTRY_PATH}
  sudo sed -i "1i ${REGISTRY_PATH}" ${GITLAB_HOME}/${GITLAB_CONFIG_FILE}

  REGISTRY_ENABLE="registry[\'enable\'] = true"
  echo ${REGISTRY_ENABLE}
  sudo sed -i "1i ${REGISTRY_ENABLE}" ${GITLAB_HOME}/${GITLAB_CONFIG_FILE}

  REGISTRY_NGINX_ENABLE="registry_nginx[\'enable\'] = true"
  echo ${REGISTRY_NGINX_ENABLE}
  sudo sed -i "1i ${REGISTRY_NGINX_ENABLE}" ${GITLAB_HOME}/${GITLAB_CONFIG_FILE}

  REGISTRY_CRT="registry_nginx['ssl_certificate'] = \"${GITLAB_CERTS_DIR}/${CERT_CRT}\""
  echo ${REGISTRY_CRT}
  sudo sed -i "1i ${REGISTRY_CRT}" ${GITLAB_HOME}/${GITLAB_CONFIG_FILE}

  REGISTRY_KEY="registry_nginx['ssl_certificate_key'] = \"${GITLAB_CERTS_DIR}/${CERT_KEY}\""
  echo ${REGISTRY_KEY}
  sudo sed -i "1i ${REGISTRY_KEY}" ${GITLAB_HOME}/${GITLAB_CONFIG_FILE}

  LFS_ENABLED="gitlab_rails[\'lfs_enabled\'] = true"
  echo ${LFS_ENABLED}
  sudo sed -i "1i ${LFS_ENABLED}" ${GITLAB_HOME}/${GITLAB_CONFIG_FILE}

}

_updateEtcHostsFile()
{
  ETC_HOSTS_ENTRY="${MY_PUBLIC_IP}    ${MY_PUBLIC_HOSTNAME}        ${URL}"
  sudo sed -i "1i ${ETC_HOSTS_ENTRY}" ${ETC_HOSTS_FILE}
}

_updateGitLabInitialPassword()
{
  sudo sed -i"" "s#\# gitlab_rails\['initial_root_password.*#gitlab_rails\['initial_root_password'\] = \""${GITLAB_INITIAL_ROOT_PASSWD}"\"#g" ${GITLAB_HOME}/${GITLAB_CONFIG_FILE}
}

_executeUpdateGitLabConfigSettings()
{
  # echo "hi"
  #sudo kill -9 `ps -u root -o pid=`
  #sudo gitlab-rake -s gitlab:setup force=yes DISABLE_DATABASE_ENVIRONMENT_CHECK=1
  #sudo -u git -H bundle exec rake gitlab:setup RAILS_ENV=production GITLAB_ROOT_PASSWORD=yourpassword GITLAB_ROOT_EMAIL=youremail GITLAB_LICENSE_FILE="/path/to/license"
  sudo gitlab-ctl reconfigure
}

_createASampleProjectInGit()
{
  echo `id`;
  cd /root
  echo "The current directory is ::: "
  echo `pwd`
  echo "Copying sample application zip from  - s3://${AWS_ARTIFACTS_APP_BUCKET}/${AWS_ARTIFACTS_APP_KEY}/${AWS_ARTIFACTS_APP_ZIP_FILE}"
  ${AWS} ${S3_COPY} s3://${AWS_ARTIFACTS_APP_BUCKET}/${AWS_ARTIFACTS_APP_KEY}/${AWS_ARTIFACTS_APP_ZIP_FILE} /root
  echo "Copying of sample application zip completed successfully."
  echo "The current directory is ::: "
  echo `pwd`
  unzip ${AWS_ARTIFACTS_APP_ZIP_FILE}
  #mkdir ${SAMPLE_PRJ_DIR}
  chmod -R 755 ${SAMPLE_PRJ_DIR}
  cd ${SAMPLE_PRJ_DIR}
  touch README1.md
  echo "The current directory from env variable is: $PWD"
  unset GIT_DIR
  echo "Sleeping for 60 seconds to make sure gitlab is up and running after reconfiguring."
  sleep 60 # To make sure gitlab is up and running after reconfiguring.
  echo "Sleep completed and pushing the code to repo."
  git init
  ls
  #GIT='git --git-dir='$PWD'/.git'
  git add README1.md
  echo "Git commit with initial repo."
  git commit -m "initial commit";
  echo "Creating branch with the name 'initial'."
  git branch initial-branch;
  echo "Checking out the branch 'initial'"
  git checkout initial-branch;
  git add .
  echo "Git commit with initial repo."
  git commit -m "initial repo";
  echo "Pushing code to http://root:${GITLAB_INITIAL_ROOT_PASSWD}@${MY_PUBLIC_IP}/root/${SAMPLE_PRJ_DIR}.git"
  git push --set-upstream http://root:${GITLAB_INITIAL_ROOT_PASSWD}@${MY_PUBLIC_IP}/root/${SAMPLE_PRJ_DIR}.git initial-branch
  echo "Push complete."
}

_installAndSetupDocker()
{
  sudo apt-get -y update
  sudo apt-get -y install apt-transport-https ca-certificates curl software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
  sudo apt-get -y update
  sudo apt-get -y install docker-ce
  sudo usermod -aG docker ${USER}
  sudo usermod -aG docker ubuntu
  newgrp docker
  sudo chown "$USER":"$USER" /home/"$USER"/.docker -R
  sudo chmod g+rwx "/home/$USER/.docker" -R
}

_creatACopyOfCerts()
{
  cd;
  sudo mkdir -p ${DOCKER_HOME}/certs.d/
  sudo chown -R 755 ${DOCKER_HOME}/certs.d/
  cd ${DOCKER_HOME}/certs.d/
  sudo cp -r -p ${GITLAB_CERTS_DIR}/${CERT_CRT} ${DOCKER_HOME}/certs.d/
  sudo cp -r -p ${DOCKER_HOME}/certs.d/${CERT_CRT} ${DOCKER_HOME}/certs.d/ca.crt
  sudo chown -R 755 ${DOCKER_HOME}/certs.d/
  sudo cp -r -p ${DOCKER_HOME}/certs.d/ca.crt /usr/local/share/ca-certificates/
  sudo update-ca-certificates
}

_reloadDockerService()
{
  sudo service docker reload
}

_loginToDocker()
{
  #sudo docker login registry.beangitlab.com
  sudo docker login --username=${DOCKER_USER} --password=${GITLAB_INITIAL_ROOT_PASSWD} ${URL}
}

_setupGitLabRunner()
{
  cd;
  mkdir gitlab-runner
  cd gitlab-runner
  curl -LJO https://gitlab-runner-downloads.s3.amazonaws.com/latest/deb/gitlab-runner_amd64.deb
  sudo dpkg -i gitlab-runner_amd64.deb
  sudo gitlab-runner status
}

_registerRunner()
{
  # sudo gitlab-rails runner -e production "proj=Project.find_by(name:'${SAMPLE_PRJ_DIR}'); proj.runners_token='${SAMPLE_PROJECT_TOKEN}'; proj.save!"
  # sudo gitlab-rails runner -e production "proj=Project.find_by(name:'sample-node-app'); proj.runners_token='AbCdEfGyXZ'; proj.save!"
  GITLAB_TOKEN=`sudo gitlab-rails runner -e production "puts Gitlab::CurrentSettings.current_application_settings.runners_registration_token"`
  GITLAB_SERVER="http://"${MY_PUBLIC_IP}"/"
  echo ${GITLAB_TOKEN}
  echo ${GITLAB_SERVER}
  sudo gitlab-runner register --non-interactive --url ${GITLAB_SERVER} --registration-token ${GITLAB_TOKEN} --executor "docker" --docker-image alpine:latest --description "docker-runner" --tag-list "docker,aws" --run-untagged="true" --locked="false" --access-level="not_protected"
}

_creatACopyOfCertsForRunner()
{
  sudo chmod -R 755 /etc/gitlab-runner/
  cd ${GITLAB_RUNNER_HOME}
  sudo mkdir -p config/certs
  cd ${GITLAB_RUNNER_HOME}/config/certs
  sudo cp -r -p ${GITLAB_CERTS_DIR}/${CERT_CRT} ${GITLAB_RUNNER_HOME}/config/certs/ca.crt
  #sudo mv ${GITLAB_RUNNER_HOME}/config/certs/${CERT_CRT} ${GITLAB_RUNNER_HOME}/config/certs/ca.crt
}

_updateConfigToml()
{
  sudo sed -i '/volumes.*/d' ${GITLAB_RUNNER_HOME}/config.toml
  sudo sed -i -e '$a\ \ \ \ volumes = ["/certs/client", "/cache", "/var/run/docker.sock:/var/run/docker.sock", "/etc/docker/certs.d:/etc/docker/certs.d", "/etc/gitlab-runner/config/certs/ca.crt:/etc/gitlab-runner/config/certs/ca.crt"]' ${GITLAB_RUNNER_HOME}/config.toml
}

_restartGitLabRunner()
{
  sudo gitlab-runner status
  sudo gitlab-runner stop
  sudo gitlab-runner start
  sudo gitlab-runner status
}

_test()
{
  MAIL="admin@example.com"
  sudo gitlab-rails console production " user = User.where(id: 1).first user.password = '$GITLAB_INITIAL_ROOT_PASSWD' user.password_confirmation = '$GITLAB_INITIAL_ROOT_PASSWD' user.save!"
  sudo gitlab-ctl reconfigure
  #sudo gitlab-rails console production  user = User.where(id: 1).first user.password = 'secret_pass' user.password_confirmation = 'secret_pass' user.save!
}
################################################################################
################################# MAIN #########################################
################################################################################

if [ "$#" -ne 3 ]; then
    echo "usage :::: sh -x gitlab-setup.sh <S3_PATH> <DNS_URL>" #
    echo "Provide a valid s3 bucket and path to store the certificate files."
    exit -1
fi
echo $1
echo $2
echo $3
_setEnv $1 $2
_installPreRequiredPackages
_installGitLabCE
_setupSSLCerts
_upLoadToS3Path $1
_updateGitLabConfig
_updateEtcHostsFile
_updateGitLabInitialPassword
_executeUpdateGitLabConfigSettings
_createASampleProjectInGit
_installAndSetupDocker
_creatACopyOfCerts
_reloadDockerService
_loginToDocker
_setupGitLabRunner
_registerRunner
_creatACopyOfCertsForRunner
_updateConfigToml
_restartGitLabRunner