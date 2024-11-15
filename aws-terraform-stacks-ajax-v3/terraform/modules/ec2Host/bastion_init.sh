#!/bin/bash -xe

# Updating the system
yum update -y

# Installing Git
echo "Installing git"
yum install -y git

# Installing kubectl
echo "Installing kubectl"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install aws cli
echo "Installing aws-cli"
yum remove -y awscli
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -qo awscliv2.zip
./aws/install --update

# Installing helm
echo "Installing helm"
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Installing tfenv to manage multiple terraform versions
if [ -d "/usr/local/tfenv" ]; then
  echo "tfenv is already installed in /usr/local/tfenv"
else
  git clone --depth=1 https://github.com/tfutils/tfenv.git /usr/local/tfenv
  ln -s /usr/local/tfenv/bin/* /usr/local/bin
  chmod -R 777 /usr/local/tfenv
  echo 'export PATH="/usr/local/bin:$PATH"' > /etc/profile.d/tfenv.sh
  chmod +x /etc/profile.d/tfenv.sh
fi

echo "Installing docker"
yum install -y docker
systemctl start docker
systemctl enable docker