#!/usr/bin/env bash

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

MY_IP=`ip -4 route get 8.8.8.8 | awk {'print $7'} | tr -d '\n'`

CLIENT_PROTOCOL=http
CLIENT_HOST=$MY_IP
CLIENT_PORT=8080
SERVER_PROTOCOL=http
SERVER_HOST=$MY_IP
SERVER_PORT=4000

FRONTEND_URL="https://github.com/Kupiki/Kupiki-Hotspot-Admin-Frontend.git"
BACKEND_URL="https://github.com/Kupiki/Kupiki-Hotspot-Admin-Backend.git"
BACKEND_SCRIPT_URL="https://github.com/Kupiki/Kupiki-Hotspot-Admin-Backend-Script.git"

display_message "Cloning Kupiki Admin Frontend"
cd $HOME
git clone $FRONTEND_URL
check_returned_code $?

display_message "Building Kupiki Admin Frontend image"
cd Kupiki-Hotspot-Admin-Frontend
docker build --build-arg CLIENT_HOST=$CLIENT_HOST --build-arg CLIENT_PORT=$CLIENT_PORT --build-arg SERVER_HOST=$SERVER_HOST --build-arg SERVER_PORT=$SERVER_PORT . -t admin-frontend
check_returned_code $?

display_message "Creating Kupiki Admin Frontend service"
cat > /etc/systemd/system/kupiki.admin.frontend.service << EOT
[Unit]
Description=Kupiki Administration Frontend
After=docker.service
Requires=docker.service
After=mariadb.service
Requires=mariadb.service

[Service]
TimeoutStartSec=0
Restart=always
ExecStartPre=/usr/bin/docker stop -t 5 admin-frontend
ExecStart=/usr/bin/docker start -a admin-frontend
ExecStop=/usr/bin/docker stop -t 5 admin-frontend

[Install]
WantedBy=multi-user.target
EOT

display_message "Activating Kupiki Admin Frontend service"
chmod +x /etc/systemd/system/kupiki.admin.frontend.service
check_returned_code $?
/bin/systemctl enable /etc/systemd/system/kupiki.admin.frontend.service
check_returned_code $?

display_message "Starting Kupiki Admin Frontend container"
/usr/bin/docker run -d -p $CLIENT_PORT:80 --name=admin-frontend admin-frontend
check_returned_code $?

# display_message "Cleaning unwanted Docker images"
# docker rmi $(docker images --filter dangling=true -q) --force
# check_returned_code $?

display_message "Cloning Kupiki Admin Backend"
cd $HOME
git clone $BACKEND_URL
check_returned_code $?

display_message "Building Kupiki Admin Backend image"
cd Kupiki-Hotspot-Admin-Backend
docker build --build-arg CLIENT_HOST=$CLIENT_HOST --build-arg CLIENT_PORT=$CLIENT_PORT --build-arg SERVER_HOST=$SERVER_HOST --build-arg SERVER_PORT=$SERVER_PORT . -t admin-backend
check_returned_code $?

display_message "Creating Kupiki Admin Backend service"
cat > /etc/systemd/system/kupiki.admin.backend.service << EOT
[Unit]
Description=Kupiki Administration Backend
After=docker.service
Requires=docker.service
After=mariadb.service
Requires=mariadb.service

[Service]
TimeoutStartSec=0
Restart=always
ExecStartPre=/usr/bin/docker stop -t 5 admin-backend
ExecStart=/usr/bin/docker start -a admin-backend
ExecStop=/usr/bin/docker stop -t 5 admin-backend

[Install]
WantedBy=multi-user.target
EOT

display_message "Activating Kupiki Admin Backend service"
chmod +x /etc/systemd/system/kupiki.admin.backend.service
check_returned_code $?
/bin/systemctl enable /etc/systemd/system/kupiki.admin.backend.service
check_returned_code $?

display_message "Starting Kupiki Admin Backend container"
/usr/bin/docker run -d -p $SERVER_PORT:$SERVER_PORT --network="host" --name=admin-backend admin-backend
check_returned_code $?

# display_message "Cleaning unwanted Docker images"
# docker rmi $(docker images --filter dangling=true -q) --force
# check_returned_code $?

display_message "Cloning Kupiki Admin Backend Script"
cd $HOME
git clone $BACKEND_SCRIPT_URL
check_returned_code $?

display_message "Creating Kupiki Admin rabbitmq service"
cat > /etc/systemd/system/kupiki.admin.rabbitmq.service << EOT
[Unit]
Description=Kupiki Administration RabbitMQ
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=0
Restart=always
ExecStartPre=/usr/bin/docker stop -t 5 rabbitmq
ExecStart=/usr/bin/docker start -a rabbitmq
ExecStop=/usr/bin/docker stop -t 5 rabbitmq

[Install]
WantedBy=multi-user.target
EOT

display_message "Activating Kupiki Admin rabbitmq service"
chmod +x /etc/systemd/system/kupiki.admin.rabbitmq.service
check_returned_code $?
/bin/systemctl enable /etc/systemd/system/kupiki.admin.rabbitmq.service
check_returned_code $?

display_message "Starting RabbitMQ"
/usr/bin/docker run -d -p 5672:5672 -p 15672:15672 --name=rabbitmq rabbitmq:management-alpine
check_returned_code $?

display_message "Copy of Kupiki Admin Script"
cp $HOME/Kupiki-Hotspot-Admin-Backend-Script/Script/kupikiListener.py /etc/kupiki/kupikiListener.py
check_returned_code $?

display_message "Creating Kupiki Admin Script service"
cat > /etc/systemd/system/kupiki.admin.script.service << EOT
[Unit]
Description=Kupiki Administration Script
After=kupiki.admin.rabbitmq.service

[Service]
Type=simple
Restart=always
RestartSec=20
ExecStart=/usr/bin/python /etc/kupiki/kupikiListener.py

[Install]
WantedBy=default.target
EOT

display_message "Activating Kupiki Admin script service"
chmod +x /etc/systemd/system/kupiki.admin.script.service
check_returned_code $?
/bin/systemctl enable /etc/systemd/system/kupiki.admin.script.service
check_returned_code $?

display_message "Waiting for RabbitMQ to be ready"
sleep 15
/bin/systemctl start kupiki.admin.script.service
