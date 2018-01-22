#!/usr/bin/env bash

NODE_VERSION=node_8.x
DISTRO="$(lsb_release -s -c)"

# Name of the log file
LOGNAME="pihotspot_admin.log"
# Path where the logfile will be stored
# be sure to add a / at the end of the path
LOGPATH="/var/log/"


check_returned_code() {
    RETURNED_CODE=$@
    if [ $RETURNED_CODE -ne 0 ]; then
        display_message ""
        display_message "Something went wrong with the last command. Please check the log file"
        display_message ""
        exit 1
    fi
}

display_message() {
    MESSAGE=$@
    # Display on console
    echo "::: $MESSAGE"
    # Save it to log file
    echo "::: $MESSAGE" >> $LOGPATH$LOGNAME
}

execute_command() {
    display_message "$3"
    COMMAND="$1 >> $LOGPATH$LOGNAME 2>&1"
    eval $COMMAND
    COMMAND_RESULT=$?
    if [ "$2" != "false" ]; then
        check_returned_code $COMMAND_RESULT
    fi
}

# ***************************
#
# For collectd
# apt-get install -y collectd-utils
# Activate unix-socket plugin for collectd
# Activate df plugin for collectd
#
# ***************************

# Install packages
apt-get install -y build-essential libfontconfig1 curl apt-transport-https
# Install nodejs / npm
#curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -

curl --silent https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -
echo "deb https://deb.nodesource.com/$NODE_VERSION $DISTRO main" | tee /etc/apt/sources.list.d/nodesource.list
echo "deb-src https://deb.nodesource.com/$NODE_VERSION $DISTRO main" | tee -a /etc/apt/sources.list.d/nodesource.list

apt-get update

apt-get install -y nodejs
npm install -g gulp-cli node-gyp
#npm install -g n
#n 8.5.0
# Install PhantomJS for Raspberry Pi
wget https://github.com/fg2it/phantomjs-on-raspberry/blob/master/rpi-2-3/wheezy-jessie/v2.1.1/phantomjs_2.1.1_armhf.deb?raw=true
mv "phantomjs_2.1.1_armhf.deb?raw=true" phantomjs_2.1.1_armhf.deb
dpkg -i phantomjs_2.1.1_armhf.deb
apt-mark hold phantomjs
# Create dedicated user kupiki
adduser --disabled-password --gecos "" kupiki
# Clone Kupiki-Hotspot-Admin project
cd /home/kupiki
git clone https://github.com/kupiki/Kupiki-Hotspot-Admin-Backend.git
chown -R kupiki:kupiki /home/kupiki/Kupiki-Hotspot-Admin-Backend
# Start packages installation with npm
# cd Kupiki-Hotspot-Admin
su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Backend && export NODE_ENV= && npm install"
# Rebuild node-sass for Raspberry Pi
su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Backend && npm rebuild node-sass"
# Configure database connection

# Build project
su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Backend && gulp build"
# Install PM2
#npm install -g pm2
# Configure startup of Kupiki Admin
#echo "
#module.exports = {
#  apps : [{
#    name   : \"KupikiBackend\",
#    script : \"./dist/src/index.js\",
#    \"env_production\" : {
#	\"PORT\": 4000,
#	\"NODE_ENV\": \"production\"
#    }
#  }]
#}
#" > /home/kupiki/Kupiki-Hotspot-Admin-Backend/ecosystem.config.js
#chmod 666 /home/kupiki/Kupiki-Hotspot-Admin-Backend/ecosystem.config.js
#chown kupiki:kupiki /home/kupiki/Kupiki-Hotspot-Admin-Backend/ecosystem.config.js
# Start interface via PM2
#su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Backend && gulp serve:dist"
#su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Backend && pm2 start ecosystem.config.js --env production"
#su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Backend && pm2 list"
#su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Backend && pm2 show 0"
#su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Backend && pm2 restart 0"
#su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Backend && pm2 start npm -- run --env production"

su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Backend && pm2 start --name backend npm -- start"

git clone https://github.com/kupiki/Kupiki-Hotspot-Admin-Frontend.git
chown -R kupiki:kupiki Kupiki-Hotspot-Admin-Frontend
# Start packages installation with npm
# cd Kupiki-Hotspot-Admin
su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Frontend && export NODE_ENV= && npm install"
# Rebuild node-sass for Raspberry Pi
su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Frontend && npm rebuild node-sass"
echo "
{
  "presets": [
    ["react"], ["env"]
  ],
  "plugins": ["transform-object-rest-spread"]
}
" > /home/kupiki/Kupiki-Hotspot-Admin-Frontend/.babelrc

# Build project
#su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Frontend && npm run-script build"

# Configure startup of Kupiki Admin
#echo "
#module.exports = {
#  apps : [{
#    name   : \"KupikiFrontend\",
#    script : \"./dist/src/index.js\",
#    \"env_production\" : {
#	\"PORT\": 8080,
#	\"NODE_ENV\": \"production\"
#    }
#  }]
#}
#" > /home/kupiki/Kupiki-Hotspot-Admin-Frontend/ecosystem.config.js
#chmod 666 /home/kupiki/Kupiki-Hotspot-Admin-Frontend/ecosystem.config.js
#chown kupiki:kupiki /home/kupiki/Kupiki-Hotspot-Admin-Frontend/ecosystem.config.js
# Start interface via PM2
#su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Frontend && pm2 start ecosystem.config.js --env production"

su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Frontend && HOST='`ip -4 route get 8.8.8.8 | awk {'print $7'} | tr -d '\n'`' pm2 start --name frontend npm -- start"

su - kupiki -c "cd /home/kupiki && pm2 save"
# Add server as a service
su - kupiki -c "pm2 startup systemd"
/usr/bin/pm2 startup systemd -u kupiki --hp /home/kupiki
chmod -x /etc/systemd/system/pm2-kupiki.service

# echo '
# #!/bin/sh
# /usr/bin/apt-get -qq -y -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" upgrade
# ' > /home/kupiki/Kupiki-Hotspot-Admin/upgrade.sh

# chown root:root /home/kupiki/Kupiki-Hotspot-Admin/upgrade.sh
# chmod 700 /home/kupiki/Kupiki-Hotspot-Admin/upgrade.sh

mkdir /etc/kupiki
chmod 700 /etc/kupiki

cd /root
git clone https://github.com/Kupiki/Kupiki-Hotspot-Admin-Backend-Script.git
cp /root/Kupiki-Hotspot-Admin-Backend-Script/kupiki.sh /etc/kupiki/
chmod 700 /etc/kupiki/kupiki.sh

# remove all lines for kupiki in /etc/sudoers
sed -i 's/^kupiki ALL.*//g' /etc/sudoers
# update /etc/sudoers
echo '
kupiki ALL=(ALL) NOPASSWD:/etc/kupiki/kupiki.sh
' >> /etc/sudoers

#echo '
#su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin && pm2 stop 0"
##su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin && git pull"
#su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin && git fetch --all"
#su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin && git reset --hard origin/master"
#su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin && export NODE_ENV= && npm install"
#su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin && gulp build"
#su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin && pm2 start 0"
#
#cd /root/Kupiki-Hotspot-Admin-Script/
#git pull
#cp /root/Kupiki-Hotspot-Admin-Script/kupiki.sh /etc/kupiki/
#chmod 700 /etc/kupiki/kupiki.sh
#
#' > /root/updateKupiki.sh
#chmod +x /root/updateKupiki.sh

apt-get install -y freeradius-utils
sed -i "s/^#LoadPlugin unixsock/LoadPlugin unixsock/" /etc/collectd/collectd.conf
echo '
<Plugin unixsock>
        SocketFile "/var/run/collectd-unixsock"
        SocketGroup "collectd"
        SocketPerms "0660"
        DeleteSocket false
</Plugin>' >> /etc/collectd/collectd.conf

service collectd restart

# To reset local developments

#git fetch --all
#git reset --hard origin/master

# Use Nginx as a reverse proxy
#http://pm2.keymetrics.io/docs/tutorials/pm2-nginx-production-setup

#https://www.digitalocean.com/community/tutorials/how-to-set-up-a-node-js-application-for-production-on-debian-8

exit 0
