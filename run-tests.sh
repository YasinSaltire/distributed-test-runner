#!/bin/bash

ALL_LISTS="/path/to/all-lists.txt"          
DOWNLOADS_DIR="/path/to/downloads"         
NETWORK_STORAGE="//192.168.50.73/ForReview/Casio/fx-CG100 emulator/automated-testing/"
LOG_FILE="$NETWORK_STORAGE/$(date +"%Y-%m-%d_%H-%M-%S")/log.txt"
PASSED_DIR="$NETWORK_STORAGE/$(date +"%Y-%m-%d_%H-%M-%S")/passed"
FAILED_DIR="$NETWORK_STORAGE/$(date +"%Y-%m-%d_%H-%M-%S")/failed"
CAN_RUN_NEW_TEST=1

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

generate_hyperlink() {
    local last_line="$1"
    local state=$2
    local test_title
    local id
    local BASE_URL='https://paperapi.demo-classpad.net/fx-CG100-test/index.html'
    local OPTIONS='stop_on_fail=Screen&annotated_log=true'
    
    test_title=$(basename "${last_line//./_}")
    echo "Test title is $test_title"
    id=$(date +"%Y-%m-%dT%H_%M_%SZ")
    
    if [[ $state -eq 1 ]]; then
        echo "${BASE_URL}?slo_mo=2&test=${test_title}&${OPTIONS}&report_id=${id}"
    elif [[ $state -eq 0 ]]; then
        echo "${BASE_URL}?slo_mo=2&test=${test_title}&${OPTIONS}&special_flag=true&report_id=${id}"
    elif [[ $state -eq -2 ]]; then
        echo "${BASE_URL}?slo_mo=2&test=${test_title}&${OPTIONS}&different_flag=true&report_id=${id}"
    else
        echo "${BASE_URL}?slo_mo=2&test=${test_title}&${OPTIONS}&report_id=${id}"
    fi
}

trap 'echo "[$(date +"%Y-%m-%dT%H:%M:%S")] Script terminated. Exiting..."; exit 1' SIGINT SIGTERM

while true; do
    if [[ ! -s "$ALL_LISTS" ]]; then
        echo "No more test in all-lists.txt. Exiting..."
        exit 0
    fi

    last_line=$(tail -n 1 "$ALL_LISTS")
    sed -i '$d' "$ALL_LISTS"

    timestamp=$(date +"%Y-%m-%dT%H_%M_%SZ")
    echo "[$timestamp] Read the line '$last_line' and updated master list" >> "$LOG_FILE"
    echo "[$timestamp] Read the line '$last_line' and updated master list"

    hyperlink=$(generate_hyperlink "$last_line")
    echo "URL = $hyperlink"

    case $CAN_RUN_NEW_TEST in
        1)
            echo "$hyperlink" | xargs -n 1 start chrome
            CAN_RUN_NEW_TEST=0
            ;;
        -1)
            ;;
        0)
            hyperlink_with_flag="${hyperlink}&special_flag=true"
            echo "$hyperlink_with_flag" | xargs -n 1 start chrome
            CAN_RUN_NEW_TEST=1
            ;;
        -2)
            hyperlink_with_different_flag="${hyperlink}&different_flag=true"
            echo "$hyperlink_with_different_flag" | xargs -n 1 start chrome
            CAN_RUN_NEW_TEST=1
            ;;
    esac

    previous_files=$(ls "$DOWNLOADS_DIR")
    while true; do
        echo "Scanning downloads folder"
        current_files=$(ls "$DOWNLOADS_DIR")
        new_files=$(comm -13 <(echo "$previous_files") <(echo "$current_files"))

        if [[ -n "$new_files" ]]; then
            for new_file in $new_files; do
                if [[ -f "$DOWNLOADS_DIR/$new_file" ]]; then
                    if [[ "$new_file" == Log-* ]]; then
                        report_file="${new_file#Log-}"
                        report_file="$DOWNLOADS_DIR/$report_file"
                        log_file="$DOWNLOADS_DIR/$new_file"
                        
                        if [[ -f "$report_file" ]]; then
                            if grep -q "FAILED" "$report_file"; then
                                destination="$FAILED_DIR"
                                CAN_RUN_NEW_TEST=-1
                            else
                                destination="$PASSED_DIR"
                                CAN_RUN_NEW_TEST=0
                            fi

                            
                            timestamped_dir="$NETWORK_STORAGE/$(date +"%Y-%m-%d_%H-%M-%S")"
                            mkdir -p "$timestamped_dir/failed" "$timestamped_dir/passed"
                            
                            echo "[$timestamp] Copying '$log_file' and '$report_file' to '$destination'" >> "$LOG_FILE"
                            echo "[$timestamp] Copying '$log_file' and '$report_file' to '$destination'"
                            cp "$log_file" "$destination"
                            cp "$report_file" "$destination"
                            echo "[$timestamp] Finished copying files" >> "$LOG_FILE"
                        fi
                        echo "Log file: $log_file"
                        echo "Report file: $report_file"
                    fi
                fi
            done
        fi

        previous_files="$current_files"
        sleep 10  
    done
done
