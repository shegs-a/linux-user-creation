# Bash Script for creating Linux Users and Groups

This Bash script automates the process of creating Linux users and groups based on information provided in an input file. It generates random passwords for users, sets up user groups, creates home directories, and logs all activities in a designated log file.

## Features
- Creates users and groups from a specified input file
- Generates random passwords for users
- Sets up user groups and personal groups
- Logs all activities to a log file for auditing purposes
- Ensures secure permissions for log files and password storage

## Usage
1. Ensure the script is executed with root privileges.
2. Specify the input file containing user information as the first command line argument.
3. The input file must be in .txt format.
4. Run the script to create users and groups based on the input file.

## Logging
The script logs all activities to the log file located at `/var/log/user_management.log`. Ensure only the root user has read and write permissions for this file.

## Password Storage
User passwords are stored securely in the file `/var/secure/user_passwords.txt`. The file permissions are set to ensure only the root user can read and write to it.

## Error Handling
The script checks for various conditions such as input file existence, readability, correct file format, and user privileges. Errors are logged in the log file for troubleshooting.

## Directory Management
The script creates necessary directories for log files and password storage if they do not already exist. Permissions are set to restrict access to these directories.

## User Setup
- New users are created with disabled passwords for security.
- Users are added to specified groups and personal groups.
- Home directories are created for each user with appropriate permissions.

## Completion
Upon completion, the script displays a message indicating that all users and groups have been successfully created. Passwords are stored in the designated file for reference.

For detailed error checking and user/group creation logs, refer to the log file at `/var/log/user_management.log`.
