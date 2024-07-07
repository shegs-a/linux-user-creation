#!/bin/bash

# This script creates users and groups from a file containing user information.

# -------------------------------- VARIABLES --------------------------------
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"
INPUT_FILE="$1" # Assigns the input file specified as the first command line argument to the variable INPUT_FILE

# -------------------------------- FUNCTIONS --------------------------------
# Function to log messages to the log file
log_message() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> $LOG_FILE
}

# Function to generate random passwords for created users
# The tr command generates a random string of characters from the specified set (A-Z,a-z,0-9,!@#$%^&*()-_=+<>?). 
# The set represents uppercase, lowercase, numbers and symbols.
# The head command selects the first 16 characters.
generate_password() {
    tr -dc 'A-Za-z0-9!@#$%^&*()-_=+<>?' < /dev/urandom | head -c 16
}

# -------------------------------- CHECKS --------------------------------
# Check to ensure the script is executed with root privileges.
# EUID is a special variable that holds the effective user ID of the current user. 
# The -ne operator (means not equal) checks if the current user's ID is not equal to 0, which is the ID of the root user.
if [[ $EUID -ne 0 ]]; then
    error_message="This script must be run with root privileges"
    echo "$error_message"
    log_message "$error_message"
    exit 1
fi

# Check if the input file is specified
if [[ -z "$INPUT_FILE" ]]; then
    error_message="No input file specified. Usage: $0 <path_to_input_file>"
    echo "$error_message"
    log_message "$error_message"
    exit 1
else
    # Check if the input file exists
    if [[ ! -f "$INPUT_FILE" ]]; then
        error_message="Input file does not exist: $INPUT_FILE"
        echo "$error_message"
        log_message "$error_message"
        exit 1
    fi
fi

# Check if the input file has a .txt extension
if [[ "$INPUT_FILE" != *.txt ]]; then
    error_message="Input file must be a .txt file: $INPUT_FILE"
    echo "$error_message"
    log_message "$error_message"
    exit 1
fi

# Check if the input file is readable
if [[ ! -r "$INPUT_FILE" ]]; then
    error_message="Input file is not readable: $INPUT_FILE"
    echo "$error_message"
    log_message "$error_message"
    exit 1
fi

# Secure the directory of the log file ensuring only the owner can read and write to it.
LOGFILE_DIR=$(dirname "$LOG_FILE")
chmod 0700 "$LOGFILE_DIR"
log_message "Secured directory of the log file: $LOGFILE_DIR"

# Check if the log file exists, if not create it.
# Setting the permissions to 0600 means that the file is only readable and writable by the owner. In this case, root. 
# -f checks if the file specified in the $LOG_FILE variable exists.
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    chmod 0600 "$LOG_FILE"
    log_message "Log file created: $LOG_FILE"
fi

# Create the password file directory if it doesn't exist
# dirname returns the directory part of the file specified in the $PASSWORD_FILE variable.
# -d checks if the directory specified in the $PASSWORD_DIR variable exists.
# mkdir -p creates the directory specified in the $PASSWORD_DIR variable if it doesn't exist.
# chmod sets the permissions of the password file's directory to 0700 so only the owner can read and write to it.
PASSWORD_DIR=$(dirname "$PASSWORD_FILE")
if [ ! -d "$PASSWORD_DIR" ]; then
    mkdir -p "$PASSWORD_DIR"
    chmod 0700 "$PASSWORD_DIR"
    log_message "Password directory created: $PASSWORD_DIR"
fi

# Check if the password file exists, if not create it.
# -f checks if the file specified in the $PASSWORD_FILE variable exists.
# touch creates the file specified in the $PASSWORD_FILE variable if it doesn't exist.
# chmod sets the permissions of the file specified in the $PASSWORD_FILE variable to 0600.
if [ ! -f "$PASSWORD_FILE" ]; then
    touch "$PASSWORD_FILE"
    chmod 0600 "$PASSWORD_FILE"
    log_message "Password file created: $PASSWORD_FILE"
fi

# -------------------------------- MAIN SCRIPT --------------------------------

echo "Starting user and group setup..."
log_message "Starting user and group setup..."

# Process user and group information
while read line; do
    echo "Processing: $line"

    username=$(echo "$line" | cut -d ';' -f 1)
    groups=$(echo "$line" | cut -d ';' -f 2)

    # Create the user if they don't exist
    if ! id "$username" &>/dev/null; then
        adduser --disabled-password --gecos "" "$username"
        echo "User $username created!"
    fi

    # Set up groups for the user
    for group in $(echo "$groups" | tr ',' ' '); do
        if ! getent group "$group" &>/dev/null; then
            addgroup "$group"
            echo "Created new group: $group"
        fi
        adduser "$username" "$group"
        echo "Added $username to group $group"
    done

    # Create a personal group for the user
    addgroup "$username"
    adduser "$username" "$username"
    echo "Created personal group $username and added the user to it"

    # Generate and set a password
    password=$(generate_password)
    echo "$username:$password" | chpasswd
    echo "$username:$password" >> "$PASSWORD_FILE"
    echo "Password set for $username and logged in $PASSWORD_FILE"

    # Create home directory and set permissions
    mkdir -p "/home/$username"
    chown "$username:$username" "/home/$username"
    chmod 700 "/home/$username"
    echo "Set up home directory for $username"

done < "$INPUT_FILE" # Tells the loop to read from the specified input file

# Log the completion of the script.
log_message "All users and groups have been created."

# Display a message to the user.
echo "All users and groups have been created. Passwords are in $PASSWORD_FILE. Please check $LOG_FILE for errors."

