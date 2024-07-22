#!/bin/bash

DOWNLOADS_DIR="$HOME/Downloads"
NETWORK_STORAGE="//192.168.50.73/ForReview/automated-testing"
PASSED_DIR="$NETWORK_STORAGE/passed"
FAILED_DIR="$NETWORK_STORAGE/failed"

mkdir -p "$PASSED_DIR" "$FAILED_DIR"

check_failed() {
    local file_path="$1"
    if grep -q "FAILED" "$file_path"; then
        return 0
    else
        return 1
    fi
}

for file in "$DOWNLOADS_DIR"/*.html; do
    file_name=$(basename "$file")
    
    if [[ "$file_name" == Log-* ]]; then
        report_name="${file_name#Log-}"
    else
        report_name="$file_name"
    fi
    
    log_file="$DOWNLOADS_DIR/Log-$report_name"
    report_file="$DOWNLOADS_DIR/$report_name"

    if [[ -f "$log_file" && -f "$report_file" ]]; then
        if check_failed "$report_file"; then
            target_dir="$FAILED_DIR"
        else
            target_dir="$PASSED_DIR"
        fi

        cp "$log_file" "$target_dir/"
        cp "$report_file" "$target_dir/"
        
        echo "Copied $log_file and $report_file to $target_dir"
    fi
done
