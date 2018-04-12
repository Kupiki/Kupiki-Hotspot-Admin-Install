#!/usr/bin/env bash

NODE_VERSION=node_8.x
DISTRO="$(lsb_release -s -c)"

# Name of the log file
LOGNAME="pihotspot_admin.log"
# Path where the logfile will be stored
# be sure to add a / at the end of the path
LOGPATH="/var/log/"

MY_IP=`ip -4 route get 8.8.8.8 | awk {'print $7'} | tr -d '\n'`
OS_RELEASE=`cat /etc/os-release | grep ^ID= | awk -F '=' '{print $2}'`

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
display_message "Install default packages"
apt-get install -y build-essential libfontconfig1 curl apt-transport-https
check_returned_code $?

display_message "Get key for Node repository"
curl --silent https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -
check_returned_code $?

display_message "Add source for Node package"
echo "deb https://deb.nodesource.com/$NODE_VERSION $DISTRO main" | tee /etc/apt/sources.list.d/nodesource.list
check_returned_code $?

display_message "Add source for Node package"
echo "deb-src https://deb.nodesource.com/$NODE_VERSION $DISTRO main" | tee -a /etc/apt/sources.list.d/nodesource.list
check_returned_code $?

display_message "Update repositories list (will add node repo)"
apt-get update
check_returned_code $?

display_message "Installing Node"
apt-get install -y nodejs
check_returned_code $?

display_message "Installing gulp and CLI"
npm install -g gulp-cli node-gyp
check_returned_code $?

# Install PhantomJS for Raspberry Pi
#display_message "Checking we are installing on Raspbian via /etc/os-release"
#if [ $OS_RELEASE = "raspbian" ]; then
#    display_message "Getting PhantomJS for Raspberry Pi"
#    wget https://github.com/fg2it/phantomjs-on-raspberry/blob/master/rpi-2-3/wheezy-jessie/v2.1.1/phantomjs_2.1.1_armhf.deb?raw=true
#    check_returned_code $?
#
#    display_message "Renaming archive"
#    mv "phantomjs_2.1.1_armhf.deb?raw=true" phantomjs_2.1.1_armhf.deb
#    check_returned_code $?
#
#    display_message "Installing PhantomJS"
#    dpkg -i phantomjs_2.1.1_armhf.deb
#    check_returned_code $?
#fi

#display_message "Avoid next updates or upgrades of PhantomJS"
#apt-mark hold phantomjs
#check_returned_code $?


id -u kupiki > /dev/null
if [ $? -ne 0 ]; then
    display_message "Create dedicated user kupiki"
    adduser --disabled-password --gecos "" kupiki
    check_returned_code $?
fi

display_message "Cloning Backend project"
if [ -d "/home/kupiki/Kupiki-Hotspot-Admin-Backend" ]; then
    rm -rf /home/kupiki/Kupiki-Hotspot-Admin-Backend
fi
cd /home/kupiki && git clone https://github.com/kupiki/Kupiki-Hotspot-Admin-Backend.git
check_returned_code $?
display_message "Changing rights of backend folder"
chown -R kupiki:kupiki /home/kupiki/Kupiki-Hotspot-Admin-Backend
check_returned_code $?

display_message "Starting packages installation with npm"
su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Backend && export NODE_ENV= && npm install"
check_returned_code $?

#display_message "Rebuilding node-sass for Raspberry Pi"
#su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Backend && npm rebuild node-sass"
#check_returned_code $?

display_message "Installing PM2"
npm install -g pm2
check_returned_code $?

#su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Backend && gulp serve:dist"
#su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Backend && pm2 start ecosystem.config.js --env production"
#su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Backend && pm2 list"
#su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Backend && pm2 show 0"
#su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Backend && pm2 restart 0"
#su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Backend && pm2 start npm -- run --env production"

display_message "Configuring IP of Kupiki Admin Backend"
sed -i "s/192.168.10.160/$MY_IP/g" /home/kupiki/Kupiki-Hotspot-Admin-Backend/src/config.json
check_returned_code $?

display_message "Starting backend using PM2"
su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Backend && pm2 start --name backend npm -- start"
check_returned_code $?

display_message "Cloning Frontend project"
if [ -d "/home/kupiki/Kupiki-Hotspot-Admin-Frontend" ]; then
    rm -rf /home/kupiki/Kupiki-Hotspot-Admin-Frontend
fi
cd /home/kupiki && git clone https://github.com/kupiki/Kupiki-Hotspot-Admin-Frontend.git
check_returned_code $?

display_message "Creating .babelrc file to allow compilation"
echo '
{
  "presets": [
    ["react"], ["env"]
  ],
  "plugins": ["transform-object-rest-spread"]
}
' > /home/kupiki/Kupiki-Hotspot-Admin-Frontend/.babelrc
check_returned_code $?

display_message "Changing files rights"
chown -R kupiki:kupiki /home/kupiki/Kupiki-Hotspot-Admin-Frontend
check_returned_code $?

display_message "Start packages installation with npm"
su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Frontend && export NODE_ENV= && npm install"
check_returned_code $?

display_message "Rebuilding node-sass for Raspberry Pi"
su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Frontend && npm rebuild node-sass"
check_returned_code $?

display_message "Configuring IP for the backend access"
sed -i "s/127.0.0.1/$MY_IP/g" /home/kupiki/Kupiki-Hotspot-Admin-Frontend/config/config.dev.json
sed -i "s/127.0.0.1/$MY_IP/g" /home/kupiki/Kupiki-Hotspot-Admin-Frontend/config/config.prod.json
sed -i "s/192.168.10.160/$MY_IP/g" /home/kupiki/Kupiki-Hotspot-Admin-Frontend/config/config.dev.json
sed -i "s/192.168.10.160/$MY_IP/g" /home/kupiki/Kupiki-Hotspot-Admin-Frontend/config/config.prod.json
check_returned_code $?

display_message "Starting interface via PM2"
su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin-Frontend && HOST='`ip -4 route get 8.8.8.8 | awk {'print $7'} | tr -d '\n'`' pm2 start --name frontend npm -- start"
check_returned_code $?

display_message "Saving PM2 configuration"
su - kupiki -c "cd /home/kupiki && pm2 save"
check_returned_code $?

display_message "Adding server as a service"
su - kupiki -c "pm2 startup systemd"
#check_returned_code $?

display_message "Generating service files for PM2"
/usr/bin/pm2 startup systemd -u kupiki --hp /home/kupiki
check_returned_code $?

display_message "Make service executable"
chmod -x /etc/systemd/system/pm2-kupiki.service
check_returned_code $?

display_message "Creating backend script folder"
mkdir /etc/kupiki && chmod 700 /etc/kupiki

display_message "Getting backend script"
cd /root && git clone https://github.com/Kupiki/Kupiki-Hotspot-Admin-Backend-Script.git
check_returned_code $?

display_message "Cloning backend script in /etc/kupiki"
cp /root/Kupiki-Hotspot-Admin-Backend-Script/kupiki.sh /etc/kupiki/
check_returned_code $?
chmod 700 /etc/kupiki/kupiki.sh
check_returned_code $?

display_message "Removing all lines for kupiki in /etc/sudoers"
sed -i 's/^kupiki ALL.*//g' /etc/sudoers
check_returned_code $?

display_message "Updating /etc/sudoers"
echo '
kupiki ALL=(ALL) NOPASSWD:/etc/kupiki/kupiki.sh
' >> /etc/sudoers
check_returned_code $?

display_message "Creating the upgrade script for Kupiki Hotspot Admin"
echo '
su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin && pm2 stop 0"
#su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin && git pull"
su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin && git fetch --all"
su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin && git reset --hard origin/master"
su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin && export NODE_ENV= && npm install"
su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin && gulp build"
su - kupiki -c "cd /home/kupiki/Kupiki-Hotspot-Admin && pm2 start 0"

cd /root/Kupiki-Hotspot-Admin-Script/
git pull
cp /root/Kupiki-Hotspot-Admin-Script/kupiki.sh /etc/kupiki/
chmod 700 /etc/kupiki/kupiki.sh

' > /root/updateKupiki.sh
check_returned_code $?
chmod +x /root/updateKupiki.sh
check_returned_code $?

display_message "Installing some freeradius tools"
apt-get install -y freeradius-utils
check_returned_code $?

display_message "Adding Collectd plugin"
sed -i "s/^#LoadPlugin unixsock/LoadPlugin unixsock/" /etc/collectd/collectd.conf
check_returned_code $?

echo '
<Plugin unixsock>
        SocketFile "/var/run/collectd-unixsock"
        SocketGroup "collectd"
        SocketPerms "0660"
        DeleteSocket false
</Plugin>' >> /etc/collectd/collectd.conf
check_returned_code $?

display_message "Restarting Collectd"
service collectd restart
check_returned_code $?

display_message "Restarting Mysql"
service mysql restart
check_returned_code $?

# To reset local developments
#git fetch --all
#git reset --hard origin/master

# Use Nginx as a reverse proxy
#http://pm2.keymetrics.io/docs/tutorials/pm2-nginx-production-setup
#https://www.digitalocean.com/community/tutorials/how-to-set-up-a-node-js-application-for-production-on-debian-8

exit 0
