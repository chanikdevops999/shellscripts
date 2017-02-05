#!/usr/bin/env bash

reset_db_vars() {
    DB_NAME=
    DB_HOST=
    DB_USER=
    DB_PASSWORD=
}

check_db_vars() {
    local path=$1
    if ! [[ $DB_NAME && $DB_USER ]]; then
        msg "error: could not find DB_NAME and DB_USER variables in file $path; aborting."
        return 1
    fi
}

extract_db_vars() {
    local path=$1
    if ! test -f "$path"; then
        error "no such file: $path"
        return 1
    fi
    while read -r line; do
        value=${line#*=}
        case "$line" in
            DB_NAME=*) DB_NAME="$value" ;;
            DB_HOST=*) DB_HOST="$value" ;;
            DB_USER=*) DB_USER="$value" ;;
            DB_PASSWORD=*) DB_PASSWORD="$value" ;;
        esac
    done < <(tr -d '\r' < "$path" | sed -ne 's/^define..\(DB_[A-Z]*\)....\(.*\)..;/\1=\2/p')
}

create_my_cnf() {
    my_cnf_path=~/.my.cnf.$DB_NAME
    msg "creating file: $my_cnf_path"
    cat << EOF | tee "$my_cnf_path"
# you can connect to this database with the command:
# mysql --defaults-file=$my_cnf_path
[client]
database=$DB_NAME
host=$DB_HOST
user=$DB_USER
password=$DB_PASSWORD
EOF
}

wp_config_to_my_cnf() {
    local path=$1
    reset_db_vars
    extract_db_vars "$path" && check_db_vars "$path" && create_my_cnf
}

msg() {
    echo "*" "$@"
}

error() {
    msg "error:" "$@"
}

for path; do
    wp_config_to_my_cnf "$path"
done
