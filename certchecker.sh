#!/bin/bash

# Display help message with ASCII art
display_help() {
    echo "
   ____                 _         ____   _                     _
  / ___|   ___   _ __  | |_      / ___| | |__     ___    ___  | | __   ___   _ __
 | |      / _ \ | '__| | __|    | |     | '_ \   / _ \  / __| | |/ /  / _ \ | '__|
 | |___  |  __/ | |    | |_     | |___  | | | | |  __/ | (__  |   <  |  __/ | |
  \____|  \___| |_|     \__|     \____| |_| |_|  \___|  \___| |_|\_\  \___| |_|

Usage: $0 <domain_name> [-v]

This script finds subdomains for the given domain using subfinder by projectdiscovery.io,
then checks the SSL certificate expiration status for each subdomain.
All outputs are stored in a directory named after the domain (e.g., example_com).

Arguments:
  <domain_name>   The root domain for which to find subdomains and check SSL certificates.
  -v              Enable verbose output, showing individual subdomain checks on screen.

Example:
  $0 example.com
  $0 example.com -v
"
}

# Get the current date in seconds since the epoch
current_date_sec=$(date +%s)

# Initialize verbose flag
verbose_mode=false

# Parse arguments
temp_main_domain=""
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -v)
            verbose_mode=true
            shift
            ;;
        *)
            if [ -z "$temp_main_domain" ]; then
                temp_main_domain="$1"
            else
                echo "Error: Too many arguments provided."
                display_help
                exit 1
            fi
            shift
            ;;
    esac
done

main_domain="$temp_main_domain" # Assign to main_domain after parsing

# Check if a domain was provided as an argument
if [ -z "$main_domain" ]; then
    display_help
    exit 1
fi

# Create a directory name from the domain by replacing '.' with '_'
domain_dir_name=$(echo "$main_domain" | sed 's/\./_/g')

# Create the domain-specific directory if it doesn't exist
if [ ! -d "$domain_dir_name" ]; then
    mkdir -p "$domain_dir_name"
    if [ $? -ne 0 ]; then
        echo "Error: Could not create directory '$domain_dir_name'."
        exit 1
    fi
fi

# Define paths for subdomain list and output file within the new directory
subdomain_list_file="$domain_dir_name/${main_domain}_subdomains.txt"
timestamp=$(date +"%Y%m%d_%H%M%S")
output_file="$domain_dir_name/${main_domain}_ssl_report_${timestamp}.txt"

    echo "
   ____                 _         ____   _                     _
  / ___|   ___   _ __  | |_      / ___| | |__     ___    ___  | | __   ___   _ __
 | |      / _ \ | '__| | __|    | |     | '_ \   / _ \  / __| | |/ /  / _ \ | '__|
 | |___  |  __/ | |    | |_     | |___  | | | | |  __/ | (__  |   <  |  __/ | |
  \____|  \___| |_|     \__|     \____| |_| |_|  \___|  \___| |_|\_\  \___| |_|
"
echo -e "\e[34m[INF]\e[0m Finding subdomains for: $main_domain using subfinder by projectdiscovery.io"
echo -e "\e[34m[INF]\e[0m Subdomains will be saved to: $subdomain_list_file"
echo -e "\e[34m[INF]\e[0m SSL report will be saved to: $output_file"
echo ""

# Run subfinder. Its output is conditional based on verbose_mode.
if "$verbose_mode"; then
    # If verbose, subfinder's output goes to screen
    subfinder -d "$main_domain" -o "$subdomain_list_file"
else
    # If not verbose, subfinder's output is suppressed
    subfinder -d "$main_domain" -o "$subdomain_list_file" >/dev/null 2>&1
fi

if [ ! -f "$subdomain_list_file" ] || [ ! -s "$subdomain_list_file" ]; then
    echo "Error: No subdomains found for '$main_domain' or subfinder failed."
    echo "Please check subfinder installation and network connectivity."
    rmdir "$domain_dir_name" 2>/dev/null # Clean up empty directory if no subdomains
    exit 1
fi

echo "Subdomain discovery complete. Checking SSL certificates..."
echo ""

# Initialize counters
expired_count=0
active_count=0
unreachable_count=0

# Write header to the report file (this will overwrite any previous content in this run)
echo "SSL Certificate Expiration Report for $main_domain - $(date)" > "$output_file"
echo "-------------------------------------------------------------------------------------------------------------" >> "$output_file"

# Function to print a line to the report file and conditionally to the screen
# This replaces direct `echo` for the detailed output
report_line() {
    local line="$1"
    echo "$line" >> "$output_file" # Always append to the report file
    if "$verbose_mode"; then
        echo "$line"             # Echo to screen only if verbose
    fi
}

# Read subdomains from the generated file and process them
while IFS= read -r subdomain; do
    # Skip empty lines
    if [ -z "$subdomain" ]; then
        continue
    fi

    # Get the IP address using dig
    ip_address=$(dig +short "$subdomain" A | head -n 1)

    # Run the curl command with a 1-second timeout and insecure flag
    # We capture stderr to /dev/null for cleaner output as curl -vI outputs to stderr
    expiration_date_output=$(curl -sk -m 1 "https://$subdomain" -vI --stderr - | grep "expire date" | cut -d":" -f 2- | sed 's/^[[:space:]]*//' | xargs -I {} date -d "{}" +"%s" 2>/dev/null)
    curl_exit_code=$? # Get the exit code of the curl command

    # Check if an expiration date was found and successfully converted
    if [ -n "$expiration_date_output" ] && [ "$expiration_date_output" -ge 0 ]; then
        if [ "$expiration_date_output" -lt "$current_date_sec" ]; then
            report_line "$subdomain ($ip_address), $(date -d "@$expiration_date_output" +"%Y-%m-%d"), Expired"
            ((expired_count++))
        else
            report_line "$subdomain ($ip_address), $(date -d "@$expiration_date_output" +"%Y-%m-%d"), Active"
            ((active_count++))
        fi
    else
        # If no expiration date is found, it could be due to timeout, no HTTPS, or other issues
        # Check curl exit code to differentiate between no cert and unreachable (e.g., DNS error, connection refused)
        if [ -n "$ip_address" ] && [ "$curl_exit_code" -eq 0 ]; then
             report_line "$subdomain ($ip_address), Unreachable, N/A"
             ((unreachable_count++))
        else
            report_line "$subdomain ($ip_address), Unreachable, N/A"
            ((unreachable_count++))
        fi
    fi
done < "$subdomain_list_file"
# --- End detailed report content ---

# --- Start final summary output (always visible on screen and appended to file) ---

# Prepare the summary output string
summary_text="-------------------------------------------------------------------------------------------------------------
Summary For $main_domain:
Total Subdomains Processed: $((expired_count + active_count + unreachable_count))
Subdomains With Expired Certificate: $expired_count
Subdomains With Active Certificate: $active_count
Subdomains Unreachable: $unreachable_count
Detailed Report Saved To: $output_file
-------------------------------------------------------------------------------------------------------------"

# Always display the summary on screen
echo "$summary_text"

# Always append the summary to the report file
echo "$summary_text" >> "$output_file"
