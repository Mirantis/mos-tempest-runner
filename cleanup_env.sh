#!/bin/bash -x

user_name="developer"
if [ -n "$1" ]; then
    user_name="$1"
fi

userdel ${user_name}
rm -rf /home/${user_name}/
