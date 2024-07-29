#!/bin/bash

context="$1"
run_name="$2"
./monitor_downloads_folder.sh "$context" "$run_name" &
child_pid=$! 
sleep 12
MASTER_LIST=".masterlist"
ALL_LISTS=$(tail -n 1 "$MASTER_LIST")
LOCAL_LOG_FILE=".logfilelocation"
LOG_FILE=$(tail -n 1 "$LOCAL_LOG_FILE")

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

log_action() {
    local logLine="$1"
    local timestamp=$(date +"[%M:%H:%S %m-%d-%y]")
    echo "$timestamp $1" >> "$LOG_FILE"
}

get_last_line() {
    if [[ ! -s "$ALL_LISTS" ]]; then
        local message="Error: $ALL_LISTS is empty or does not exist."
     
        log_action "$message"

        exit 1
    fi

    last_line=$(tail -n 1 "$ALL_LISTS")

    sed -i '$ d' "$ALL_LISTS"

    log_action "Fetched $last_line and removed it from list"

    echo "$last_line"
}

get_last_line_ext() {
    if [[ ! -s "$ALL_LISTS" ]]; then
        local message="Error: $ALL_LISTS is empty or does not exist."

        log_action "$message"

        exit 1
    fi

    while [[ -s "$ALL_LISTS" ]]; do
        last_line=$(tail -n 1 "$ALL_LISTS")

        if [[ "$last_line" =~ ^// ]]; then
            log_action "Ignoring commented line: $last_line"
            sed -i '$ d' "$ALL_LISTS"
        else
            last_line=$(urlencode "$last_line")
            sed -i '$ d' "$ALL_LISTS"
            log_action "Fetched and removed the last line from list: $last_line"
            echo "$last_line"
            return 0
        fi
    done

    log_action "Error: $ALL_LISTS is empty or does not exist."
    exit 1
}

get_most_recent_test_state() {
    echo $(tail -n 1 ".state")
}

update_most_recent_test_state() {
    echo "$1" >> ".state"
}

cleanup() {
    echo "Cleaning up..."
    log_action "Shutting down scripts"
    kill "$child_pid"  
    exit 0
}

generate_hyperlink() {
    line="$1"
    state="$2"
    BASE_URL="https://paperapi.demo-classpad.net/fx-CG100-test/index.html"
    OPTIONS='stop_on_fail=Screen&annotated_log=true'
    OPTIONS_1="stop_on_fail=Screen&annotated_log=true"
    OPTIONS_2="stop_on_fail=Screen&annotated_log=true&ignore_status_bar=true"
    OPTIONS_3="stop_on_fail=Screen&annotated_log=true&slo_mo=2"
    OPTIONS_4="stop_on_fail=Screen&annotated_log=true&slo_mo=2&ignore_status_bar=true"
    OPTIONS_5="stop_on_fail=Screen&annotated_log=true&slo_mo=3"

    id=$(date +"%Y-%m-%dT%H_%M_%SZ")
    
    if [[ "$state" -eq 1 ]]; then
        echo "$BASE_URL?test=$line&$OPTIONS&report_id=$id&x=1"
    elif [[ "$state" -eq 2 ]]; then
        echo "$BASE_URL?test=$line&$OPTIONS&report_id=$id&ignore_status_bar=true"
    elif [[ "$state" -eq 3 ]]; then
        echo "$BASE_URL?test=$line&$OPTIONS&report_id=$id&slo_mo=2"
    elif [[ "$state" -eq 4 ]]; then
        echo "$BASE_URL?test=$line&$OPTIONS&report_id=$id&slo_mo=2&ignore_status_bar=true"
    elif [[ "$state" -eq 5 ]]; then
        echo "$BASE_URL?test=$line&$OPTIONS&report_id=$id&slo_mo=3"
    else
        echo "Error"
    fi
    
}

trap "cleanup" EXIT SIGINT

log_action "Starting a new test run"

set_time() {
    > .time
    time=$(date +%s%3N)
    echo "$time" >> .time
}

urlencode() {
    local raw_string="$1"
    local encoded_string=$(printf "$raw_string" | jq -sRr @uri)
    echo "$encoded_string"
}

echo 1 >> .state

BASE_URL="https://paperapi.demo-classpad.net/fx-CG100-test/index.html"
OPTIONS_1="stop_on_fail=Screen&annotated_log=true"
OPTIONS_2="stop_on_fail=Screen&annotated_log=true&ignore_status_bar=true"
OPTIONS_3="stop_on_fail=Screen&annotated_log=true&slo_mo=2"
OPTIONS_4="stop_on_fail=Screen&annotated_log=true&slo_mo=2&ignore_status_bar=true"
OPTIONS_5="stop_on_fail=Screen&annotated_log=true&slo_mo=3"

while true; do
    last_test_state=$(get_most_recent_test_state)
    id=$(date +"%Y-%m-%dT%H_%M_%SZ")
    if [[ $last_test_state == 1 ]]; then 
        last_line=$(get_last_line_ext)
        echo "$last_line" >> .current
        url="$BASE_URL?test=$last_line&$OPTIONS_1&report_id=$id"
        log_action "Going to $url"
        echo "$url" >> .urls
        start chrome "$url"
        set_time
        echo "$last_test_state*" >> .state
    elif [[ $last_test_state == "1*" ]]; then
        echo "Test in progress"
    elif [[ $last_test_state == 2 ]]; then
        last_line=$(tail -n 1 .current)
        echo "$last_line" >> .current
        url="$BASE_URL?test=$last_line&$OPTIONS_2&report_id=$id"
        log_action "Going to $url"
        echo "$url" >> .urls
        start chrome "$url"
        set_time
        echo "$last_test_state*" >> .state
    elif [[ $last_test_state == "2*" ]]; then
        echo "Test in progress"
    elif [[ $last_test_state == 3 ]]; then
        last_line=$(tail -n 1 .current)
        echo "$last_line" >> .current
        url="$BASE_URL?test=$last_line&$OPTIONS_3&report_id=$id"
        log_action "Going to $url"
        echo "$url" >> .urls
        start chrome "$url"
        set_time
        echo "$last_test_state*" >> .state
    elif [[ $last_test_state == "3*" ]]; then
        echo "Test in progress"
    elif [[ $last_test_state == 4 ]]; then
        last_line=$(tail -n 1 .current)
        echo "$last_line" >> .current
        url="$BASE_URL?test=$last_line&$OPTIONS_4&report_id=$id"
        log_action "Going to $url"
        echo "$url" >> .urls
        start chrome "$url"
        set_time
        echo "$last_test_state*" >> .state
    elif [[ $last_test_state == "4*" ]]; then
        echo "Test in progress"
    elif [[ $last_test_state == 5 ]]; then
        last_line=$(tail -n 1 .current)
        echo "$last_line" >> .current
        url="$BASE_URL?test=$last_line&$OPTIONS_5&report_id=$id"
        log_action "Going to $url"
        echo "$url" >> .urls
        start chrome "$url"
        set_time
        echo "$last_test_state*" >> .state
    elif [[ $last_test_state == "5*" ]]; then
        echo "Test in progress"
    else 
        echo "unknown flag"
    fi
    sleep 2
done
