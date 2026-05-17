#!/usr/bin/env bash

#---------------------------------
#  initz.sh - Initialization script for various commands
#---------------------------------

# /// Housekeeping ///

# Error Handling
set -euo pipefail

# Colors
BBLACK='\033[1;90m'
BRED='\033[1;91m'
BGREEN='\033[1;92m'
BYELLOW='\033[1;93m'
BBLUE='\033[1;94m'
BMAGENTA='\033[1;95m'
BCYAN='\033[1;96m'
BWHITE='\033[1;97m'
RESET='\033[0m'

# /// Variables ///

# /// Functions ///

# Function Single
pussy1() {
	declare -a CMD=(

		#0 - Make a new vite project
		"bun create vite"

		#1- Use truss to optimize image to avif
		"truss convert src/assets/fem1.jpg --format avif --quality 35 -o src/assets/fem1.avif"

		#2- Use truss to optimize image to webp - Webp best
		"truss optimize src/assets/fem1.jpg -o src/assets/fem1.webp"

	)

	CMDEXEC="${CMD[1]}"
	echo -e ""
	echo -e "${BBLUE} · · ────── ꒰ঌ·✦·໒꒱ ────── · ·"
	echo -e "${BBLUE} · · ────── Vite Init Coomands ────── · ·"
	echo -e "${BBLUE} · · ────── ꒰ঌ·✦·໒꒱ ────── · ·"
	date
	echo -e "Executing:${BMAGENTA}${CMDEXEC}${RESET}"
	eval "${CMDEXEC}"
	echo -e "${BGREEN}Done!"
	echo -e "───── ⋆⋅☆⋅⋆ ─────${RESET}"
	echo -e "───── ⋆⋅☆⋅⋆ ─────${RESET}"
	echo -e "───── ⋆⋅☆⋅⋆ ─────${RESET}"
	echo -e ""
	echo -e ""
	echo -e ""
}

# Looping Booties
booty1() {
	declare -a CMD=(

		#0 - Make a new vite project
		"bun create vite"
	)

	for CMDEXEC in "${CMD[@]}"; do
		echo -e ""
		echo -e ""
		echo -e ""
		echo -e "${BBLUE}────── ꒰ঌ·✦·໒꒱ ──────${RESET}"
		echo -e "${BBLUE}────── Woman Ass Poop Eating ──────${RESET}"
		echo -e "${BBLUE}────── ꒰ঌ·✦·໒꒱ ──────${RESET}"
		echo -e "Executing: ${CMDEXEC}"
		eval "${CMDEXEC}"
		echo -e "${BGREEN}Done!${RESET}"
		echo -e "${BBLUE}───── ⋆⋅☆⋅⋆ ─────${RESET}"
		echo -e "${BBLUE}───── ⋆⋅☆⋅⋆ ─────${RESET}"
		echo -e "${BBLUE}───── ⋆⋅☆⋅⋆ ─────${RESET}"
		echo # Add blank line between commands
	done
}

# /// Execiton ///

panty() {
	pussy1 2>&1 | tee -a initz.sh.txt
	# booty1 2>&1 | tee -a initz.sh.txt

}
panty
