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
    return 1
}

get_last_line() {
    if [[ ! -s "$ALL_LISTS" ]]; then
        local message="Error: $ALL_LISTS is empty or does not exist."
     
        log_action "$message"
    fi

    last_line=$(tail -n 1 "$ALL_LISTS")

    sed -i '$ d' "$ALL_LISTS"

    log_action "Fetched $last_line and removed it from list"

    echo "$last_line"
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

do_test_with_url() {
    url="$1"
    log_action "URL is $url"
    if [[ -n "$url" ]]; then 
        echo "$url"
    fi 
}

do_test() {
    last_state="$1"
    log_action "Last test status = $last_state"
    last_line=$(get_last_line)
    if [[ -n "$last_line" ]]; then 
        echo "$last_line" >> .current
        echo "last line = $last_line"
        url=$(generate_hyperlink "$last_line" "$last_state")
        sleep 3
        #start chrome "$url"
        echo "$url" >> .urls
        echo "Starting Chrome..."
        set_time
        sleep 3
        log_action "$url"
        echo "$last_state*" >> .state
        log_action "Updated test status to $last_state*"
    fi
}

do_test_with_special_flag() {
    last_state="$1"
    log_action "Last test status = $last_state"
    last_line=$(tail -n 1 .current)
    $url=$(generate_hyperlink "$last_line" "$last_state")
    echo "$url" >> .urls
    sleep 3
    #start chrome "$url"
    echo "Starting Chrome..."
    set_time
    sleep 3
    log_action "$url"
    echo "$last_state*" >> .state
    log_action "Updated test status to $last_state*"
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
        last_line=$(get_last_line)
        echo "$last_line" >> .current
        url="$BASE_URL?test=$last_line&$OPTIONS_1&report_id=$id"
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
