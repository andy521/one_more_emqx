#!/bin/bash

###############
## args and env validation
###############

if ! [ -d "emqx" ]; then
  echo "[error] this script must be run at the same dir as the emqx"
  exit 1
fi

if [ $# -eq 0 ]
  then
    echo "[error] a new emqx name should be provided!"
    echo "Usage: ./one_more_emqx <new_name>"
    echo "  e.g. ./one_more_emqx emqx2"
    exit 1
fi

NEW_EMQX=$1
if [ -d "$NEW_EMQX" ]; then
  echo "[error] a dir named ${NEW_EMQX} already exists!"
  exit 2
fi
echo creating $NEW_EMQX ...

SED_REPLACE="sed -i "
case $(sed --help 2>&1) in
    *GNU*) SED_REPLACE="sed -i ";;
    *) SED_REPLACE="sed -i ''";;
esac

PORT_INC_=`cksum <<< "$NEW_EMQX" | cut -f 1 -d ' '`
PORT_INC=$(($PORT_INC_ % 1000))
echo using increment factor: $PORT_INC

###############
## helpers
###############
process_emqx_conf() {
  echo "processing config file: $1"
  $SED_REPLACE '/^#/d' $1
  $SED_REPLACE '/^$/d' $1
  $SED_REPLACE 's|.*node\.name.*|node.name='"$NEW_EMQX"'@127.0.0.1|g' $1

  for entry_ in "${entries_to_be_inc[@]}"
  do
    echo inc port for $entry_
    ip_port_=`egrep "$entry_"'[ \t]*=' $1 2> /dev/null | tail -1 | cut -d = -f 2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'`
    echo -- from: $ip_port_
    ip_=$(echo "$ip_port_" | cut -sd : -f 1)
    port_=$(echo "$ip_port_" | cut -sd : -f 2)
    if [ -z "$ip_" ]
      then
        new_ip_port=$(( $ip_port_ + $PORT_INC ))
      else
        new_ip_port="${ip_}:$(( $port_ + $PORT_INC ))"
    fi
    echo -- to: $new_ip_port
    $SED_REPLACE 's|'"$entry_"'[ \t]*=.*|'"$entry_"' = '"$new_ip_port"'|g' $1
  done
}

###############
## main
###############

cp -r emqx $NEW_EMQX

conf_ext=*.conf
find $NEW_EMQX -name "${conf_ext}" | while read conf; do
    if [ "${conf##*/}" = 'emqx.conf' ]
      then
        declare -a entries_to_be_inc=("node.dist_listen_min"
                                      "dist_listen_max"
                                      "tcp_server_port"
                                      "tcp_client_port"
                                      "listener.tcp.external"
                                      "listener.tcp.internal"
                                      "listener.ssl.external"
                                      "listener.ws.external"
                                      "listener.wss.external"
                                      "listener.tcp.internal")
        process_emqx_conf $conf $entries_to_be_inc
    elif [ "${conf##*/}" = 'emqx_management.conf' ]
      then
        declare -a entries_to_be_inc=("management.listener.http"
                                      "management.listener.https")
        process_emqx_conf $conf $entries_to_be_inc
    elif [ "${conf##*/}" = 'emqx_dashboard.conf' ]
      then
        declare -a entries_to_be_inc=("dashboard.listener.http"
                                      "dashboard.listener.https")
        process_emqx_conf $conf $entries_to_be_inc
    else
        echo "."
    fi
done

