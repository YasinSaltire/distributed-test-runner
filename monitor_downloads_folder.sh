#!/bin/bash

trap "cleanup" EXIT SIGINT

cleanup() {
    echo "Cleaning up..."
    log_action "Shutting down scripts"
    exit 0 
}

DOWNLOADS_DIR="$HOME/Downloads"
NETWORK_STORAGE="//192.168.50.73/ForReview/Casio/fx-CG100 emulator/automated-testing"
CXT=$1
NICKNAME=$2
DEV="--dev"
dev="-d"
PROD="--prod"
prod="-p"

if [[ ! -f .env && ( "$CXT" == "$DEV" || "$CXT" == "$dev" ) ]]; then 
    echo "Error: no .env file found. Exiting"
    exit 1
fi 

if [[ $CXT == $DEV || $CXT == $dev ]]; then
    NETWORK_STORAGE=$(grep -m 1 '^dev=' .env | sed 's/^dev=//')
    echo "Setting storage location to $NETWORK_STORAGE"
fi

TIMESTAMP=$(date +"%Y-%m-%dT%H_%M_%SZ")
LOG_FILE="$NETWORK_STORAGE/$NICKNAME/$TIMESTAMP/log.txt"
TIMED_OUT_LIST="$NETWORK_STORAGE/$NICKNAME/$TIMESTAMP/timed-out.txt"
FAILED_DIR="$NETWORK_STORAGE/$NICKNAME/$TIMESTAMP/failed"
PASSED_DIR="$NETWORK_STORAGE/$NICKNAME/$TIMESTAMP/passed"
ALL_LISTS="$NETWORK_STORAGE/all-tests.txt"
LOCAL_LOG_FILE=".logfilelocation"
MASTER_LIST=".masterlist"
FAILED_LIST="$NETWORK_STORAGE/$NICKNAME/$TIMESTAMP/failed-list.txt"
PASSED_LIST="$NETWORK_STORAGE/$NICKNAME/$TIMESTAMP/passed-list.txt"
mkdir -p ~/backup/passed ~/backup/failed
> "$MASTER_LIST"
touch "$LOCAL_LOG_FILE"
> "$LOCAL_LOG_FILE"
echo "$LOG_FILE" >> "$LOCAL_LOG_FILE"
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$TIMED_OUT_LIST")"
touch "$LOG_FILE"
touch "$TIMED_OUT_LIST"
touch .state
> .state
echo "1" >> .state
echo "$ALL_LISTS" >> "$MASTER_LIST"
touch .urls
> .urls
touch "$FAILED_LIST" "$PASSED_LIST"
mkdir -p "$FAILED_DIR"
mkdir -p "$PASSED_DIR"

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

    mv "$log_file" "$destination/"
    mv "$report_file" "$destination/"

    log_action "Uploaded $log_file and $report_file to $destination"
}

POLL_INTERVAL=3

update_state() {
    state="$1"
    start_next="1"
    second_attempt="2"
    third_attempt="3"
    fourth_attempt="4"
    fifth_attempt="5"
    echo "updating from $state"
    if [[ "$state" == "1*" ]]; then 
        log_action "First attempt failed; updating test status to run second attempt ($second_attempt)"
        echo "$second_attempt" >> .state
    elif [[ "$state" == "2*" ]]; then
        log_action "Second attempt failed; updating test status to run third attempt ($third_attempt)"
        echo "$third_attempt" >> .state
    elif [[ "$state" == "3*" ]]; then
        log_action "Third attempt failed; updating test status to run fourth attempt ($fourth_attempt)"
        echo "$fourth_attempt" >> .state
    elif [[ "$state" == "4*" ]]; then
        log_action "Fourth attempt failed; updating test status to run fifth attempt ($fifth_attempt)"
        echo "$fifth_attempt" >> .state
    elif [[ "$state" == "5*" ]]; then
        log_action "Fifth attempt failed; updating test status to run next test ($start_next)"
        echo "$start_next" >> .state
    elif [[ "$state" == "passed" ]]; then
        log_action "Test passed; updating test status to run next test"
        echo "$start_next" >> .state
    elif [[ "$state" == "timed-out" ]]; then
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
                taskkill //IM chrome.exe //F
                log_action "Shutting down Chrome"
                last_test_state=$(tail -n 1 ".state")
                log_action "Both files downloaded; last test state: $last_test_state"
                state=""
                current_test=$(tail -n 1 .current)
                if grep -q "FAILED" "$report_file_path"; then 
                    destination="$FAILED_DIR"
                    state="$last_test_state"
                    if [[ "$state" == "5*" ]]; then 
                        echo "$current_test" >> "$FAILED_LIST"
                    fi
                    log_action "$current_test failed"
                else 
                    destination="$PASSED_DIR"
                    state="passed"
                    echo "$current_test" >> "$PASSED_LIST"
                    log_action "$current_test passed"
                fi
                echo "destination is $destination"
                upload_files "$report_file_path" "$log_file_path" "$destination"
                update_state "$state"
            else
                # report and log-pair not ready yet
                echo "Log file '$file_name' found but report file '$report_file' is missing"
            fi
        fi
    done
}

number_of_html_files=$(ls -l "~/Downloads/*html" 2>/dev/null | wc -l)

check_html_files() {
    current_number_of_html_files=$(ls -l "~/Downloads/*html" 2>/dev/null | wc -l)
    if [[ $(("$current_number_of_html_files" - "")) == "" ]]; then
        echo ""
    fi
}

if [[ -e .state ]]; then 
    rm .state
fi 

touch .time
> .time # clear the file in case it has data from a previous run
touch .current
> .current # clear the file in case it has data from a previous run 

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
        last_test=$(tail -n 1 ".current")
        if [[ "$elapsed_seconds" -gt 1800 && -n "$last_test" ]]; then 
            echo "$last_test" >> "$TIMED_OUT_LIST"
            log_action "Last test ($last_test) has timed out ($elapsed_seconds s); shutting down Chrome"
            taskkill //IM chrome.exe //F
            echo "$last_test timed out"
            echo "1" >> .state
        fi
    fi
done
