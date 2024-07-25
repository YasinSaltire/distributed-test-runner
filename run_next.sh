#!/bin/bash

context="$1"
run_name="$2"
./monitor_downloads_folder.sh "$context" "$run_name" &
child_pid=$! 
sleep 10
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
    wait "$child_pid" 
}

generate_hyperlink() {
    local last_line="$1"
    local state=$2
    local test_title
    local id
    local BASE_URL='https://paperapi.demo-classpad.net/fx-CG100-test/index.html'
    local OPTIONS='stop_on_fail=Screen&annotated_log=true'
    
    
    test_title=$(basename "${last_line//./_}")
    # echo "Test title is $test_title"
    id=$(date +"%Y-%m-%dT%H_%M_%SZ")
    
    if [[ $state -eq 1 ]]; then
        echo "${BASE_URL}?test=${last_line}&${OPTIONS}&report_id=${id}"
    elif [[ $state -eq 2 ]]; then
        echo "${BASE_URL}?test=${last_line}&${OPTIONS}&report_id=${id}&ignore_status_bar=true"
    elif [[ $state -eq 3 ]]; then
        echo "${BASE_URL}?test=${last_line}&${OPTIONS}&report_id=${id}&slo_mo=2"
    elif [[ $state -eq 4 ]]; then
        echo "${BASE_URL}?test=${last_line}&${OPTIONS}&report_id=${id}&slo_mo=2&ignore_status_bar=true"
    elif [[ $state -eq 5 ]]; then
        echo "${BASE_URL}?test=${last_line}&${OPTIONS}&report_id=${id}&slo_mo=3"
    else
        echo "Error"
    fi
    
}

trap cleanup EXIT SIGINT

log_action "Starting a new test run"

set_time() {
    > .time
    time=$(date +%s%3N)
    echo "$time" >> .time
}

do_test() {
    last_state="$1"
    log_action "Last test status = $last_state"
    last_line=$(get_last_line)
    echo "$last_line" >> .current
    url=$(generate_hyperlink "$last_line" "$last_state")
    generate_hyperlink "$last_line" "$last_state" | xargs -n 1 start chrome
    echo "Starting Chrome..."
    set_time
    sleep 3
    log_action "$url"
    echo "$last_state*" >> .state
    log_action "Updated test status to $last_state*"
}

while true; do
    last_test_state=$(get_most_recent_test_state)
    if [[ $last_test_state == 1 ]]; then 
        do_test "$last_test_state"
    elif [[ $last_test_state == "1*" ]]; then
        echo "Test in progress"
    elif [[ $last_test_state == 2 ]]; then
        do_test "$last_test_state"
    elif [[ $last_test_state == "2*" ]]; then
        echo "Test in progress"
    elif [[ $last_test_state == 3 ]]; then
        do_test "$last_test_state"
    elif [[ $last_test_state == "3*" ]]; then
        echo "Test in progress"
    elif [[ $last_test_state == 4 ]]; then
        do_test "$last_test_state"
    elif [[ $last_test_state == "4*" ]]; then
        echo "Test in progress"
    elif [[ $last_test_state == 5 ]]; then
        do_test "$last_test_state"
    elif [[ $last_test_state == "5*" ]]; then
        echo "Test in progress"
    else 
        echo "unknown flag"
    fi
    sleep 2
done
