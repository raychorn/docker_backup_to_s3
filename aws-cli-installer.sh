#!/usr/bin/env bash

BASENAME="$(basename ${BASH_SOURCE[0]} | cut -d '.' -f 1 | cut -d ' ' -f 2)"

tdir="/tmp/@$BASENAME"
echo "tdir:$tdir"
if [[ -d "$tdir" ]]
then
	rm -R -f $tdir
else
	mkdir $tdir
fi
cd $tdir

# apt  install awscli -y

cpu_arch=$(uname -m)

curl "https://awscli.amazonaws.com/awscli-exe-linux-$cpu_arch.zip" -o "awscliv2.zip"
sudo apt-get install unzip zip -y
echo -ne 'A' | unzip awscliv2.zip

aws_cli_current=/usr/local/aws-cli/v2/current
if [[ -d $aws_cli_current ]]
then
	echo "Updating the current aws cli."
	sudo ./aws/install --update
else
	echo "Installing the current aws cli."
	sudo ./aws/install
fi

aws_version=$(aws --version)

if [[ "$aws_version" == "." ]]
then
	echo "aws cli has not been installed."
else
	echo "aws cli has been installed :: $aws_version."
fi
