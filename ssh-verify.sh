#!/usr/bin/env bash

CUSTOMHOSTS=~/.ssh/custom_known_hosts
TMPFILE=${CUSTOMHOSTS}.tmp # I don't know why I'm unable to accomplish this with variables...

USAGE="Add keys to your custom known hosts file: ssh-verify.sh -a \$SERVERNAME
Add keys plus provide a friendly name for the keys: ssh-verify.sh -a -n \$FRIENDLYNAME $SERVERNAME
Check server identity against your custom known hosts: ssh-verify.sh -c \$SERVERNAME
Rename a friendly name in custom known hosts: ssh-verify.sh -r \$OLDNAME \$NEWNAME"

# Parse options
#  -a Add key to custom known hosts file. You can use -n to provide a friendly name.
#  -c Check a server's identity against your custom known hosts file
#  -r Rename the friendly name for a server, and if there are duplicates clear the duplicates
#  -p Set the port of the SSH server
#  -d Debugging information will print with the normal output

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
      name="$OPTARG"
      ;;
    p)
      port="-p $OPTARG"
      ;;
    r)
      mode="rename"
      ;;
    *)
      echo "Invalid argument: $OPTARG" 2>&1
      echo "$USAGE"
      exit 1
  esac
done
shift $((OPTIND-1))

# Function to change friendly names in custom known hosts file
function rename() {
  # Substitute first field (server name)
  awk -v oldname=$1 -v newname=$2 '{ gsub(oldname,newname,$1); print }' $CUSTOMHOSTS > $TMPFILE
  # Clean any duplicate entries (i.e. if the renamed pubkey matches another entry's name)
  sort -u $TMPFILE > $CUSTOMHOSTS
}

# Print debugging information abou the inputs
if [ -n "$debug" ]; then
  echo "Debug ON ($debug)"
  echo "Mode: $mode"
  echo "Port: $port"
fi

# Run
case $mode in
  'add')
    ssh-keyscan "$port" "$@" >> "$CUSTOMHOSTS" 2> /dev/null
    # This doesn't help because ssh-keyscan exits success when it can't find the server
    if [ $? ]; then
      echo "ssh-keyscan exited successfully."
    else
      echo "ssh-keyscan failed."
    fi
    if [ -n "$name" ]; then
      rename $1 $name
    fi
    ;;
  'check')
    # Check for each key type
    for keytype in rsa1 dsa ecdsa ed25519 rsa; do
      if [ -n "$debug" ]; then
        echo
        echo "Keytype: $keytype"
        echo "Command: ssh-keyscan $port -t $keytype $@"
        echo "----------------"
      fi
      (ssh-keyscan -t "$keytype" "$port" "$@" | awk '{print $3}') > "$TMPFILE" 2>/dev/null
      grep -F -f "$TMPFILE" "$CUSTOMHOSTS" | awk -v keyvar="$keytype" '{print "Matched " keyvar ": " $1}'
    done
    ;;
  'rename')
    rename $1 $2
    ;;
  *)
    echo "$USAGE"
esac
