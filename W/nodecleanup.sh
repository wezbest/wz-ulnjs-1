#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}🗑️  Node_modules Cleaner - Parallel Deletion Mode${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"

# Find all node_modules directories
echo -e "${YELLOW}🔍 Scanning for node_modules directories...${NC}"
mapfile -t dirs < <(find . -name "node_modules" -type d -prune 2>/dev/null)

# Check if any found
if [ ${#dirs[@]} -eq 0 ]; then
	echo -e "${GREEN}✅ No node_modules directories found.${NC}"
	exit 0
fi

# Show what was found
echo -e "\n${YELLOW}📁 Found ${#dirs[@]} node_modules director(ies):${NC}\n"
for dir in "${dirs[@]}"; do
	size=$(du -sh "$dir" 2>/dev/null | cut -f1)
	echo -e "  ${BLUE}•${NC} $dir ${GREEN}($size)${NC}"
done

# Calculate total size
echo -e "\n${YELLOW}📊 Calculating total disk usage...${NC}"
total_size=$(du -shc "${dirs[@]}" 2>/dev/null | tail -1 | cut -f1)
echo -e "${GREEN}   Total space to be freed: $total_size${NC}"

# Single confirmation prompt
echo ""
read -p "⚠️  PERMANENTLY DELETE all ${#dirs[@]} node_modules directories? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
	echo -e "${RED}❌ Operation cancelled.${NC}"
	exit 1
fi

# Parallel deletion
echo -e "\n${YELLOW}🚀 Deleting in parallel (4 processes)...${NC}\n"

# Export function for parallel
delete_dir() {
	local dir="$1"
	if [ -d "$dir" ]; then
		local size=$(du -sh "$dir" 2>/dev/null | cut -f1)
		if rm -rf "$dir" 2>/dev/null; then
			echo -e "  ${GREEN}✓${NC} Deleted: $dir ${GREEN}($size)${NC}"
			return 0
		else
			echo -e "  ${RED}✗${NC} Failed: $dir"
			return 1
		fi
	else
		echo -e "  ${YELLOW}○${NC} Skipped (already gone): $dir"
		return 0
	fi
}
export -f delete_dir

# Run parallel deletion (4 processes at once)
printf "%s\n" "${dirs[@]}" | xargs -P 4 -I {} bash -c 'delete_dir "$@"' _ {}

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Cleanup complete!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "  ${YELLOW}📁 Directories removed:${NC} ${#dirs[@]}"
echo -e "  ${YELLOW}💾 Space reclaimed:${NC} $total_size"
echo ""
echo -e "${GREEN}✨ All node_modules directories have been deleted.${NC}"
