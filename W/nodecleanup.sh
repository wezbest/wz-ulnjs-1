#!/bin/bash

#===============================================================================
# Node Modules Cleaner - Parallel Deletion with Audit Trail
#===============================================================================
# Description: Recursively finds and deletes all node_modules directories
#              with parallel processing and comprehensive logging
# Author: System Admin
# Version: 2.1
#===============================================================================

#---------------------------------------
# Configuration Constants
#---------------------------------------
readonly SCRIPT_VERSION="2.1"
readonly LOG_BASE_DIR="./node_cleaner_logs" # Changed to current directory
readonly PARALLEL_PROCESSES=4
readonly DATE_FORMAT="+%Y-%m-%d %H:%M:%S"
readonly LOG_DATE_FORMAT="+%Y-%m"

#---------------------------------------
# Color Codes for Terminal Output
#---------------------------------------
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

#===============================================================================
# Utility Functions
#===============================================================================

#---------------------------------------
# Get current timestamp
#---------------------------------------
get_timestamp() {
	date "$DATE_FORMAT"
}

#---------------------------------------
# Get current date for log filename
#---------------------------------------
get_log_date() {
	date "$LOG_DATE_FORMAT"
}

#---------------------------------------
# Initialize logging system
#---------------------------------------
init_logging() {
	# Create log directory in current location if it doesn't exist
	if [[ ! -d "$LOG_BASE_DIR" ]]; then
		mkdir -p "$LOG_BASE_DIR"
		echo "Created log directory: $LOG_BASE_DIR"

		# Create .gitignore to keep logs out of git (optional)
		local gitignore_file="$LOG_BASE_DIR/.gitignore"
		if [[ ! -f "$gitignore_file" ]]; then
			echo "# Ignore all log files but keep the directory" >"$gitignore_file"
			echo "*.log" >>"$gitignore_file"
			echo "!.gitignore" >>"$gitignore_file"
			echo "Created .gitignore in log directory (logs won't be committed)"
		fi
	fi

	# Generate log file path (monthly rotation)
	local log_month=$(get_log_date)
	LOG_FILE="$LOG_BASE_DIR/cleanup_${log_month}.log"

	# Ensure log file exists
	touch "$LOG_FILE"
}

#---------------------------------------
# Write to both console and log file
# Args:
#   $1 - Log level (INFO, WARNING, ERROR, HEADER, SUCCESS)
#   $2 - Message to log
#---------------------------------------
log_write() {
	local level="$1"
	local message="$2"
	local timestamp=$(get_timestamp)

	# Strip color codes for log file
	local plain_message=$(echo -e "$message" | sed 's/\x1b\[[0-9;]*m//g')

	# Write to log file
	echo "[$timestamp] [$level] $plain_message" >>"$LOG_FILE"

	# Write to console with color
	case "$level" in
	"INFO") echo -e "${GREEN}$message${NC}" ;;
	"WARNING") echo -e "${YELLOW}$message${NC}" ;;
	"ERROR") echo -e "${RED}$message${NC}" ;;
	"HEADER") echo -e "${BLUE}$message${NC}" ;;
	"SUCCESS") echo -e "${GREEN}$message${NC}" ;;
	*) echo -e "$message" ;;
	esac
}

#---------------------------------------
# Write session header to log file
#---------------------------------------
write_session_header() {
	echo "" >>"$LOG_FILE"
	echo "════════════════════════════════════════════════════════════════════════════" >>"$LOG_FILE"
	echo "CLEANUP SESSION STARTED: $(get_timestamp)" >>"$LOG_FILE"
	echo "Script Version: $SCRIPT_VERSION" >>"$LOG_FILE"
	echo "Working Directory: $(pwd)" >>"$LOG_FILE"
	echo "User: $(whoami)" >>"$LOG_FILE"
	echo "Host: $(hostname)" >>"$LOG_FILE"
	echo "════════════════════════════════════════════════════════════════════════════" >>"$LOG_FILE"
}

#---------------------------------------
# Write session footer to log file
# Args:
#   $1 - Exit status (0 for success, non-zero for error)
#---------------------------------------
write_session_footer() {
	local exit_status=$1
	echo "" >>"$LOG_FILE"
	echo "Session ended: $(get_timestamp)" >>"$LOG_FILE"
	echo "Exit Status: $exit_status" >>"$LOG_FILE"
	echo "════════════════════════════════════════════════════════════════════════════" >>"$LOG_FILE"
	echo "" >>"$LOG_FILE"
}

#===============================================================================
# Core Business Logic Functions
#===============================================================================

#---------------------------------------
# Find all node_modules directories
# Returns:
#   Array of directory paths
#---------------------------------------
find_node_modules_dirs() {
	local found_dirs=()

	log_write "INFO" "🔍 Scanning for node_modules directories..."

	# Use mapfile to populate array
	mapfile -t found_dirs < <(find . -name "node_modules" -type d -prune 2>/dev/null)

	echo "${found_dirs[@]}"
}

#---------------------------------------
# Get size of a directory
# Args:
#   $1 - Directory path
# Returns:
#   Human readable size
#---------------------------------------
get_dir_size() {
	local dir="$1"
	du -sh "$dir" 2>/dev/null | cut -f1
}

#---------------------------------------
# Calculate total size of multiple directories
# Args:
#   $@ - Array of directory paths
# Returns:
#   Total human readable size
#---------------------------------------
calculate_total_size() {
	local dirs=("$@")
	du -shc "${dirs[@]}" 2>/dev/null | tail -1 | cut -f1
}

#---------------------------------------
# Display list of found directories with sizes
# Args:
#   $@ - Array of directory paths
#---------------------------------------
display_directory_list() {
	local dirs=("$@")

	log_write "INFO" "📁 Found ${#dirs[@]} node_modules director(ies):"
	echo ""

	for dir in "${dirs[@]}"; do
		local size=$(get_dir_size "$dir")
		log_write "INFO" "  • $dir ($size)"
		# Write unformatted to log for better readability
		echo "  • $dir ($size)" >>"$LOG_FILE"
	done

	# Calculate and display total size
	local total_size=$(calculate_total_size "${dirs[@]}")
	log_write "INFO" ""
	log_write "INFO" "📊 Total disk usage: $total_size"
}

#---------------------------------------
# Get user confirmation for deletion
# Args:
#   $1 - Number of directories to delete
# Returns:
#   0 for yes, 1 for no
#---------------------------------------
get_user_confirmation() {
	local count=$1
	local total_size=$2

	echo ""
	log_write "WARNING" "⚠️  About to delete $count node_modules director(ies) (Total: $total_size)"
	read -p "Permanently delete all? (y/N): " -n 1 -r
	echo ""

	if [[ $REPLY =~ ^[Yy]$ ]]; then
		log_write "INFO" "✅ User confirmed deletion"
		return 0
	else
		log_write "WARNING" "❌ Operation cancelled by user"
		return 1
	fi
}

#---------------------------------------
# Delete a single directory (for parallel execution)
# Args:
#   $1 - Directory path
# Outputs:
#   Status line in format: STATUS:path:size
#---------------------------------------
delete_single_dir() {
	local dir="$1"

	if [[ ! -d "$dir" ]]; then
		echo "SKIPPED:$dir:"
		return 0
	fi

	local size=$(get_dir_size "$dir")

	if rm -rf "$dir" 2>/dev/null; then
		echo "SUCCESS:$dir:$size"
		return 0
	else
		echo "FAILED:$dir:$size"
		return 1
	fi
}
export -f delete_single_dir
export -f get_dir_size

#---------------------------------------
# Execute parallel deletion of directories
# Args:
#   $@ - Array of directory paths
# Returns:
#   0 on success, non-zero on failure
#---------------------------------------
execute_parallel_deletion() {
	local dirs=("$@")

	if [[ ${#dirs[@]} -eq 0 ]]; then
		return 0
	fi

	log_write "INFO" "🚀 Deleting in parallel ($PARALLEL_PROCESSES processes)..."
	echo ""

	# Arrays to track results
	deleted_dirs=()
	failed_dirs=()
	skipped_dirs=()

	# Process directories in parallel
	while IFS= read -r result; do
		local status="${result%%:*}"
		local rest="${result#*:}"
		local dir="${rest%%:*}"
		local size="${rest#*:}"

		case "$status" in
		"SUCCESS")
			echo -e "  ${GREEN}✓${NC} Deleted: $dir ${GREEN}($size)${NC}"
			log_write "INFO" "  ✓ Deleted: $dir ($size)"
			deleted_dirs+=("$dir ($size)")
			;;
		"FAILED")
			echo -e "  ${RED}✗${NC} Failed: $dir"
			log_write "ERROR" "  ✗ Failed to delete: $dir"
			failed_dirs+=("$dir")
			;;
		"SKIPPED")
			echo -e "  ${YELLOW}○${NC} Skipped: $dir (already removed)"
			log_write "WARNING" "  ○ Skipped: $dir (directory no longer exists)"
			skipped_dirs+=("$dir")
			;;
		esac
	done < <(printf "%s\n" "${dirs[@]}" | xargs -P "$PARALLEL_PROCESSES" -I {} bash -c 'delete_single_dir "$@"' _ {})

	# Store results in global arrays for summary
	DELETED_DIRS=("${deleted_dirs[@]}")
	FAILED_DIRS=("${failed_dirs[@]}")
	SKIPPED_DIRS=("${skipped_dirs[@]}")

	return 0
}

#---------------------------------------
# Display and log deletion summary
# Args:
#   $1 - Original count of directories
#   $2 - Total space reclaimed
#---------------------------------------
display_deletion_summary() {
	local original_count=$1
	local total_space=$2
	local deleted_count=${#DELETED_DIRS[@]}
	local failed_count=${#FAILED_DIRS[@]}
	local skipped_count=${#SKIPPED_DIRS[@]}

	echo ""
	log_write "HEADER" "═══════════════════════════════════════════════════════════"
	log_write "SUCCESS" "✅ CLEANUP COMPLETE"
	log_write "HEADER" "═══════════════════════════════════════════════════════════"
	log_write "INFO" "  📁 Directories attempted: $original_count"
	log_write "SUCCESS" "  ✓ Successfully deleted: $deleted_count"

	if [[ $failed_count -gt 0 ]]; then
		log_write "ERROR" "  ✗ Failed: $failed_count"
	fi

	if [[ $skipped_count -gt 0 ]]; then
		log_write "WARNING" "  ○ Skipped (already gone): $skipped_count"
	fi

	log_write "SUCCESS" "  💾 Space reclaimed: $total_space"

	# Write detailed list to log
	write_detailed_deletion_log
}

#---------------------------------------
# Write detailed deletion list to log file
#---------------------------------------
write_detailed_deletion_log() {
	echo "" >>"$LOG_FILE"
	echo "Detailed deletion list:" >>"$LOG_FILE"

	for deleted in "${DELETED_DIRS[@]}"; do
		echo "  ✓ $deleted" >>"$LOG_FILE"
	done

	for failed in "${FAILED_DIRS[@]}"; do
		echo "  ✗ $failed" >>"$LOG_FILE"
	done

	for skipped in "${SKIPPED_DIRS[@]}"; do
		echo "  ○ $skipped" >>"$LOG_FILE"
	done
}

#---------------------------------------
# Show historical statistics from logs
#---------------------------------------
show_historical_stats() {
	if [[ ! -f "$LOG_FILE" ]]; then
		return 0
	fi

	local current_month=$(get_log_date)
	local total_sessions=$(grep -c "CLEANUP SESSION STARTED" "$LOG_FILE" 2>/dev/null || echo "0")
	local total_deleted=$(grep -c "✓ Deleted:" "$LOG_FILE" 2>/dev/null || echo "0")

	echo ""
	log_write "INFO" "📊 Historical summary for $(date '+%B %Y'):"
	log_write "INFO" "   • Total cleanup sessions this month: $total_sessions"
	log_write "INFO" "   • Total directories deleted this month: $total_deleted"

	# Calculate total space reclaimed this month
	local total_space=$(grep "Space reclaimed:" "$LOG_FILE" 2>/dev/null | tail -1 | awk -F': ' '{print $NF}')
	if [[ -n "$total_space" ]]; then
		log_write "INFO" "   • Most recent space reclaimed: $total_space"
	fi
}

#---------------------------------------
# Display log file location and git info
#---------------------------------------
show_log_info() {
	echo ""
	log_write "INFO" "📝 Log directory: $(pwd)/$LOG_BASE_DIR/"
	log_write "INFO" "📝 Current log file: $(pwd)/$LOG_FILE"

	# Check if directory is a git repo
	if git rev-parse --git-dir >/dev/null 2>&1; then
		log_write "INFO" "🔧 Git repository detected - Logs are automatically ignored (see .gitignore in log directory)"
	fi
}

#===============================================================================
# Main Program Flow
#===============================================================================

#---------------------------------------
# Main function - orchestrates the entire cleanup process
#---------------------------------------
main() {
	# Initialize logging system
	init_logging
	write_session_header

	# Display header
	log_write "HEADER" "═══════════════════════════════════════════════════════════"
	log_write "HEADER" "🗑️  Node_modules Cleaner v$SCRIPT_VERSION - Parallel Mode"
	log_write "HEADER" "═══════════════════════════════════════════════════════════"

	# Find all node_modules directories
	local dirs_array=()
	read -ra dirs_array <<<"$(find_node_modules_dirs)"

	# Check if any directories were found
	if [[ ${#dirs_array[@]} -eq 0 ]]; then
		log_write "WARNING" "✅ No node_modules directories found."
		write_session_footer 0
		show_log_info
		exit 0
	fi

	# Display what was found
	display_directory_list "${dirs_array[@]}"

	# Calculate total size for confirmation
	local total_size=$(calculate_total_size "${dirs_array[@]}")

	# Get user confirmation
	if ! get_user_confirmation "${#dirs_array[@]}" "$total_size"; then
		write_session_footer 1
		show_log_info
		exit 1
	fi

	# Execute parallel deletion
	execute_parallel_deletion "${dirs_array[@]}"

	# Display summary
	display_deletion_summary "${#dirs_array[@]}" "$total_size"

	# Show historical statistics
	show_historical_stats

	# Write session footer
	local exit_code=0
	if [[ ${#FAILED_DIRS[@]} -gt 0 ]]; then
		exit_code=1
	fi
	write_session_footer $exit_code

	# Show log information
	show_log_info

	echo ""
	log_write "SUCCESS" "✨ Operation complete!"

	return $exit_code
}

#===============================================================================
# Script Entry Point
#===============================================================================

# Trap interrupts for clean exit
trap 'log_write "WARNING" "Script interrupted by user"; write_session_footer 130; exit 130' INT

# Run main function
main "$@"
exit $?
