#!/usr/bin/env bash

TMPFILE=~/Scripts/Logs/verification-key.tmp # I don't know why I'm unable to accomplish this with variables...
CUSTOMHOSTS=~/.ssh/custom_known_hosts

USAGE='Add keys to your custom known hosts file: ssh-verify.sh -a $SERVERNAME\nCheck server identity against your custom known hosts: ssh-verify.sh -c $SERVERNAME'

while getopts "acdn:p:r" opt; do
  case $opt in
    a)
      mode="add"
      ;;
    c)
      mode="check"
      ;;
    d)
      debug="true"
      ;;
    n)
      # I fucked up the naming process, it can overwrite keys, don't use for simple server names...
      name="$OPTARG"
      ;;
    p)
      port="-p $OPTARG"
      ;;
    r)
      # I fucked up the naming process, it can overwrite keys, don't use for simple server names...
      mode="rename"
      ;;
    *)
      echo "Invalid argument: $OPTARG" 2>&1
      echo "$USAGE"
      exit 1
  esac
done
shift $((OPTIND-1))

if [ -n "$debug" ]; then
  echo "Debug ON ($debug)"
  echo "Mode: $mode"
  echo "Port: $port"
fi

# I need to rewrite this with getopts...
case $mode in
  'add')
    ssh-keyscan "$port" "$@" >> "$CUSTOMHOSTS" 2> /dev/null
    if [ -n "$name" ]; then
      sed "s/$@/$name/" < "$CUSTOMHOSTS" > "$TMPFILE"
      mv "$TMPFILE" "$CUSTOMHOSTS"
    fi
    ;;
  'check')
    for keytype in rsa1 dsa ecdsa ed25519 rsa; do
      if [ -n "$debug" ]; then
        echo
        echo "Keytype: $keytype"
        echo "Temp File: $TMPFILE"
        echo "Command: ssh-keyscan $port -t $keytype $@"
        echo "----------------"
      fi
      (ssh-keyscan -t "$keytype" "$port" "$@" | awk '{print $3}') > "$TMPFILE" 2>/dev/null
      grep -F -f "$TMPFILE" "$CUSTOMHOSTS" | awk -v keyvar="$keytype" '{print "Matched " keyvar ": " $1}'
    done
    ;;
  'rename')
    sed "s/$1/$2/" < "$CUSTOMHOSTS" > "$TMPFILE"
    mv "$TMPFILE" "$CUSTOMHOSTS"
    ;;
  *)
    echo "$USAGE"
esac

sort -u "$CUSTOMHOSTS" > "$TMPFILE"
mv "$TMPFILE" "$CUSTOMHOSTS"
