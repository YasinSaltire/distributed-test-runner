#!/bin/bash

DOWNLOADS_DIR="$HOME/Downloads"
CXT=$1
IP=$2
DEV="--dev"
dev="-d"
PROD="--prod"
prod="-p"
NETWORK_STORAGE="//192.168.50.73/ForReview/Casio/fx-CG100 emulator/automated-testing"

if [[ $CXT == $DEV || $CXT == $dev ]]; then
    echo "in dev"
    NETWORK_STORAGE="/c/Users/yasin/dev"
    echo "Setting storage location to $NETWORK_STORAGE"
fi

echo $IP
TIMESTAMP=$(date +"%Y-%m-%dT%H_%M_%SZ")
ALL_LISTS="$NETWORK_STORAGE/all-tests.txt"
LOG_FILE="$NETWORK_STORAGE/$IP/$TIMESTAMP/log.txt"
TIMED_OUT_LIST="$NETWORK_STORAGE/$IP/$TIMESTAMP/timed-out.txt"
FAILED_DIR="$NETWORK_STORAGE/$IP/$TIMESTAMP/failed"
PASSED_DIR="$NETWORK_STORAGE/$IP/$TIMESTAMP/passed"
LOCAL_LOG_FILE=".logfilelocation"
MASTER_LIST=".masterlist"
touch "$LOCAL_LOG_FILE"
echo "$LOG_FILE" >> "$LOCAL_LOG_FILE"
echo "local .log file created"
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$TIMED_OUT_LIST")"
mkdir -p "$FAILED_DIR"
mkdir -p "$PASSED_DIR"
touch "$LOG_FILE"
touch "$TIMED_OUT_LIST"
touch .state
echo "1" >> .state
echo "$ALL_LISTS" >> "$MASTER_LIST"

log_action() {
    local logLine="$1"
    local timestamp=$(date +"[%M:%H:%S %m-%d-%y]")
    echo "$timestamp $1" >> "$LOG_FILE"
}

get_most_recent_test_state() {
    echo $(tail -n 1 ".state")
}

upload_files() {
    local log_file="$1"
    local report_file="$2"
    local destination="$3"

    echo ""
    echo ""
    echo "$destination"

    mkdir -p "$destination"
    mv "$log_file" "$destination/"
    mv "$report_file" "$destination/"
}

POLL_INTERVAL=3

update_state() {
    state="$1"
    start_next="1"
    second_attempt="2"
    third_attempt="3"
    fourth_attempt="4"
    fifth_attempt="5"
    if [[ $state == "1*" ]]; then 
        log_action "First attempt failed; updating test status to run second attempt ($second_attempt)"
        echo "$second_attempt" >> .state
    elif [[ $state == "2*" ]]; then
        log_action "Second attempt failed; updating test status to run third attempt ($third_attempt)"
        echo "$third_attempt" >> .state
    elif [[ $state == "3*" ]]; then
        log_action "Third attempt failed; updating test status to run fourth attempt ($fourth_attempt)"
        echo "$fourth_attempt" >> .state
    elif [[ $state == "4*" ]]; then
        log_action "Fourth attempt failed; updating test status to run fifth attempt ($fifth_attempt)"
        echo "$fifth_attempt" >> .state
    elif [[ $state == "5*" ]]; then
        log_action "Fifth attempt failed; updating test status to run next test ($fourth_attempt)"
        echo "$start_next" >> .state
    elif [[ $state == "passed" ]]; then
        log_action "Test passed; updating test status to run next test"
        echo "$start_next" >> .state
    elif [[ $state == "timed-out" ]]; then
        log_action "Test timed-out; updating test status to run next test"
        echo "$start_next" >> .state
    fi
}

find_html_pairs() {
    html_files=$(find "$DOWNLOADS_DIR" -maxdepth 1 -type f -name "*.html")
    
    for file in $html_files; do
        file_name=$(basename "$file")
        destination=""
        
        if [[ $file_name == Log-* ]]; then # A log file was downloaded
            log_file=$file_name 
            log_file_path="$DOWNLOADS_DIR/$log_file"
            report_file="${file_name#Log-}"
            report_file_path="$DOWNLOADS_DIR/$report_file"
            
            if [[ -f "$report_file_path" ]]; then # Corresponding report was also found
                echo "Pair found: Log file '$file_name' and report file '$report_file'"
                last_test_state=$(tail -n 1 ".state")
                log_action "Both files downloaded; last test state: $last_test_state"
                state=""
                if grep -q "FAILED" "$report_file_path"; then 
                    destination="$FAILED_DIR"
                    state="$last_test_state"
                else 
                    destination="$PASSED_DIR"
                    state="passed"
                fi
                echo "destination is $destination"
                upload_files "$report_file_path" "$log_file_path" "$destination"
                update_state "$state"
            else
                # report and log-pair not ready yet
                echo "Log file '$file_name' found but report file '$report_file' is missing"
            fi
        else
            log_file="Log-$file_name"
            log_file_path="$DOWNLOADS_DIR/$log_file"
            last_test_state=$(tail -n 1 ".state")
            log_action "Both files downloaded; last test state: $last_test_state"
            
            if [[ -f "$log_file_path" ]]; then
                echo "Pair found: Log file '$log_file' and report file '$file_name'"
                state=""
                if grep -q "FAILED" "$report_file_path"; then 
                    destination="$FAILED_DIR"
                    state="$last_test_state"
                else 
                    destination="$PASSED_DIR"
                    state="passed"
                fi
                echo "destination is $destination"
                upload_files "$report_file_path" "$log_file_path" "$destination"
                update_state "$state"
            else
                echo "Report file '$file_name' found but log file '$log_file' is missing"
            fi
        fi
    done
}

if [[ -e .state ]]; then 
    rm .state
fi 

touch .state
touch .time
touch .current
echo 1 >> .state

log_action "Starting to monitor ~/Downloads"

while true; do
    find_html_pairs
    sleep "$POLL_INTERVAL"
    t0=$(tail -n 1 .time)
    t1=$(date +%s%3N)


    if [[ "$t0" -gt 0 ]]; then 
        elapsed_time=$(($t1 - $t0))
        elapsed_seconds=$(($elapsed_time / 1000))
        echo "elapsed time = $elapsed_seconds"
        if [[ "$elapsed_seconds" -gt 1800 ]]; then 
            last_test=$(tail -n 1 ".current")
            echo "$last_test" >> "$TIMED_OUT_LIST"
            log_action "Last test has timed out"
            echo "1" >> .state
        fi
    fi
done
