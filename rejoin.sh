#!/bin/bash

user_name="developer"
if [ -n "${USER_NAME}" ]; then
    user_name=${USER_NAME}
fi

su - ${user_name}
