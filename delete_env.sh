#!/bin/bash -x

user_name="developer"
if [ -n "$1" ]; then
    user_name="$1"
fi

echo "WARNING! THIS SCRIPT WILL REMOVE USER ${user_name} AND IT'S HOMEDIR (/home/${user_name}/) WITH TEMPEST REPORTS, PREPARED VENV ETC."
read -p "Are you sure you want to continue? <yes/no> " prompt

if [[ $prompt =~ [yY](es)* ]]
then
    userdel ${user_name}
    rm -rf /home/${user_name}/
else
  exit 0
fi



