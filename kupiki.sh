#!/bin/sh

if [ $# -lt 1 ]; then
  >&2 echo "Missing parameters"
  exit 1
fi

KUPIKI_PATH="/home/chris/Kupiki-Hotspot-Admin"
HOSTNAME=`hostname`

DEFAULT_STATS_RANGE="AVERAGE -r 60 -s -1h"

case ${1} in
  "freeradius")
    RADIUSSECRET=`grep '^[[:space:]]secret =' /etc/freeradius/3.0/clients.conf | awk -F '=' '{print $2}' | tr -d ' '`
    if [ $# -eq 4 -a $2 = "check" ]; then
      echo User-Name="$3",User-Password="$4" | radclient -c '1' -n '3' -r '3' -t '3' -x '127.0.0.1:1812' 'auth' "$RADIUSSECRET" 2>&1
      exit $?
    fi
    if [ $# -eq 3 -a $2 = "disconnect" ]; then
      echo "User-Name=$3" | radclient -x localhost:3779 disconnect $RADIUSSECRET 2>&1
      exit $?
    fi
    ;;
  "data")
    if [ $# -eq 2 -a $2 = "disk" ]; then
      /usr/bin/rrdtool fetch /var/lib/collectd/rrd/$HOSTNAME/df-root/df_complex-used.rrd $DEFAULT_STATS_RANGE
      exit $?
    fi
    if [ $# -eq 2 -a $2 = "memory" ]; then
      /usr/bin/rrdtool fetch /var/lib/collectd/rrd/$HOSTNAME/memory/memory-used.rrd $DEFAULT_STATS_RANGE
      exit $?
    fi
    if [ $# -eq 2 -a $2 = "cpu" ]; then
      /usr/bin/rrdtool fetch /var/lib/collectd/rrd/$HOSTNAME/processes/ps_state-running.rrd $DEFAULT_STATS_RANGE
      exit $?
    fi
    ;;
  "portal")
    if [ $# -eq 2 -a $2 = "getConfiguration" ]; then
      cat /usr/share/nginx/portal/js/configuration.json
      exit $?
    fi
    if [ $# -eq 2 -a $2 = "saveConfiguration" ]; then
      cp /tmp/portal.conf /usr/share/nginx/portal/js/configuration.json
      exit $?
    fi
    ;;
  "background")
    if [ $# -eq 2 -a $2 = "default" ]; then
      cp $KUPIKI_PATH/client/assets/upload/default.jpg $KUPIKI_PATH/client/assets/upload/background.jpg
      exit $?
    fi
    ;;
  "hostapd")
    if [ $# -eq 2 -a $2 = "load" ]; then
      cat /etc/hostapd/hostapd.conf
      exit $?
    fi
    if [ $# -eq 2 -a $2 = "save" ]; then
      cp /tmp/hostapd.conf /etc/hostapd/hostapd.conf
      exit $?
    fi
    ;;
  "services")
    if [ $# -eq 1 ]; then
      /usr/sbin/service --status-all
      exit $?
    fi
    ;;
  "service")
    if [ $# -eq 3 -a \( $3 = "start" -o $3 = "stop" -o $3 = "restart" \) ]; then
      /usr/sbin/service $2 $3
      exit $?
    fi
    ;;
  "system")
    if [ $# -eq 2 -a $2 = "check" ]; then
      /usr/bin/apt-get upgrade -s | /bin/grep -v 'Const\|Inst' | /usr/bin/tail -1 | /usr/bin/cut -f1 -d ' '
      exit $?
    fi
    if [ $# -eq 2 -a $2 = "reboot" ]; then
      /sbin/shutdown -r -t 1
      exit $?
    fi
    if [ $# -eq 2 -a $2 = "shutdown" ]; then
      /sbin/shutdown -t 1
      exit $?
    fi
    if [ $# -eq 2 -a $2 = "update" ]; then
      /usr/bin/apt-get update -y -qq
      exit $?
    fi
    if [ $# -eq 2 -a $2 = "upgrade" ]; then
      /usr/bin/apt-get -qq -y -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" upgrade
      exit $?
    fi
    ;;
  *)
    >&2 echo "Call of the Kupiki script with wrong parameters"
    exit 1
    ;;
esac
>&2 echo "Call of the Kupiki script with wrong parameters"
exit 1
