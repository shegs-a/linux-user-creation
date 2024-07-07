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

# Read from the input file
# The while loop reads each line from the input file and assigns it to the variable line.
while IFS= read -r line || [[ -n "$line" ]]; do 
    # IFS= : Temporarily clears the Internal Field Separator to prevent word splitting on spaces
    # read -r: Reads a line from the input file into the 'line' variable
    # || [[ -n "$line" ]]: Ensures the last line is processed even without a newline

   # Trimming leading spaces and whitespaces
    trimmed_line=$(echo "$line" | tr -d '[:space:]')  

    # Checking for Valid Line Format (semicolon presence)
    if [[ "$trimmed_line" == *";"* ]]; then  # Check if the line contains a semicolon

        # Extracting Username and Groups
        IFS=';' read -r username groups <<< "$trimmed_line"  # Split the line into username and groups using ';'
        IFS=',' read -ra group_array <<< "$groups"  # Split the groups string into an array using ','

       # Displaying the Results
        echo "Username: $username" 
        echo "Groups: ${group_array[@]}"  # Print all elements of the groups array
    else
        # Step 7: Handling Invalid Line Format
        echo "Invalid format: $line"  # Print an error message if the format is incorrect
        log_message "Invalid format in input file: $line"
    fi

    # Create user passwords
    if ! getent passwd "$username" &>/dev/null; then
        useradd -m -s /bin/bash -G "${group_array[*]}" "$username"
        log_message "User created: $username"
        password=$(generate_password)  # Generate a password for the user
        echo "$username:$password" | chpasswd
        echo "$username:$password" >> "$PASSWORD_FILE"
        log_message "Password set for user: $username"
    fi

    # Check if user already exists
    if getent passwd "$username" &>/dev/null; then
        log_message "User $username already exists. Skipping user creation."
        continue
    fi

    # Add user to groups
    # If group exists, add the user to the group.
    # If group doesn't exist, create the group and add the user to it.
    for group in "${group_array[@]}"; do  # Loop through the groups
        if getent group "$group" &>/dev/null; then  # Check if the group exists
            log_message "Group already exists."
            usermod -aG "$group" "$username"  # Add the user to the group
            log_message "User added to existing group: $group"
        else
            groupadd "$group"  # Create the group if it doesn't exist.
            log_message "Group created: $group"
            usermod -aG "$group" "$username"  # Add the user to the group
            log_message "User added to new group: $group"
        fi
    done

    # Create personal group for the user and add the user to it
    personal_group="$username"
    if ! getent group "$personal_group" &>/dev/null; then
        groupadd "$personal_group"
        log_message "Personal group created: $personal_group"
    fi
    usermod -aG "$personal_group" "$username"
    log_message "User added to personal group: $personal_group"

    # Create user's home directory and set necessary permissions
    mkdir -p "/home/$username"
    chown "$username:$personal_group" "/home/$username"
    chmod 700 "/home/$username"
    log_message "Home directory created for user: $username"

done < "$INPUT_FILE" # Tells the loop to read from the specified input file


