#!/bin/bash
# install.sh — Smart deploy: merges this template into ~/.copilot/ while preserving
# any company-specific skills you've added locally.
#
# Safe to run multiple times (idempotent).
# Preserved: ~/.copilot/skills/company-*/  (any directory starting with "company-")
# Updated:   everything else

set -euo pipefail

TEMPLATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}/.copilot"
PRESERVED_PATTERN="company-*"

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[info]${NC}  $*"; }
success() { echo -e "${GREEN}[ok]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[skip]${NC}  $*"; }

echo ""
echo -e "${BLUE}Everything Copilot CLI — Install${NC}"
echo "  Template : $TEMPLATE_DIR"
echo "  Target   : $TARGET_DIR"
echo ""

# ─── 1. Create target structure ───────────────────────────────────────────────
mkdir -p "$TARGET_DIR/agents" "$TARGET_DIR/skills"

# ─── 2. Discover preserved skills (company-specific, local-only) ──────────────
PRESERVED=()
if [ -d "$TARGET_DIR/skills" ]; then
  for dir in "$TARGET_DIR/skills"/$PRESERVED_PATTERN; do
    [ -d "$dir" ] && PRESERVED+=("$(basename "$dir")")
  done
fi

if [ ${#PRESERVED[@]} -gt 0 ]; then
  info "Preserving ${#PRESERVED[@]} company-specific skill(s):"
  for name in "${PRESERVED[@]}"; do
    warn "  ~/.copilot/skills/$name  (not overwritten)"
  done
  echo ""
fi

# ─── 3. Copy agents ───────────────────────────────────────────────────────────
AGENTS_UPDATED=0
for src in "$TEMPLATE_DIR/agents"/*.agent.md; do
  [ -f "$src" ] || continue
  dest="$TARGET_DIR/agents/$(basename "$src")"
  if ! diff -q "$src" "$dest" &>/dev/null 2>&1; then
    cp "$src" "$dest"
    success "agents/$(basename "$src")"
    ((AGENTS_UPDATED++)) || true
  fi
done

if [ "$AGENTS_UPDATED" -eq 0 ]; then
  info "agents/  — all up to date"
fi

# ─── 4. Copy skills (skip preserved) ─────────────────────────────────────────
SKILLS_UPDATED=0
for src_dir in "$TEMPLATE_DIR/skills"/*/; do
  [ -d "$src_dir" ] || continue
  skill_name="$(basename "$src_dir")"

  # Skip if this skill matches the preserved pattern
  skip=false
  for preserved in "${PRESERVED[@]}"; do
    [ "$skill_name" = "$preserved" ] && skip=true && break
  done
  $skip && continue

  dest_dir="$TARGET_DIR/skills/$skill_name"
  mkdir -p "$dest_dir"

  for src_file in "$src_dir"*; do
    [ -f "$src_file" ] || continue
    dest_file="$dest_dir/$(basename "$src_file")"
    if ! diff -q "$src_file" "$dest_file" &>/dev/null 2>&1; then
      cp "$src_file" "$dest_file"
      success "skills/$skill_name/$(basename "$src_file")"
      ((SKILLS_UPDATED++)) || true
    fi
  done
done

if [ "$SKILLS_UPDATED" -eq 0 ]; then
  info "skills/  — all up to date"
fi

# ─── 5. Copy root files ───────────────────────────────────────────────────────
for src in "$TEMPLATE_DIR/copilot-instructions.md"; do
  [ -f "$src" ] || continue
  dest="$TARGET_DIR/$(basename "$src")"
  if ! diff -q "$src" "$dest" &>/dev/null 2>&1; then
    cp "$src" "$dest"
    success "$(basename "$src")"
  else
    info "$(basename "$src")  — up to date"
  fi
done

# ─── 6. Summary ───────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}Done.${NC}"
echo ""

TOTAL_AGENTS=$(ls "$TARGET_DIR/agents"/*.agent.md 2>/dev/null | wc -l | tr -d ' ')
TOTAL_SKILLS=$(ls -d "$TARGET_DIR/skills"/*/ 2>/dev/null | wc -l | tr -d ' ')

echo "  Agents : $TOTAL_AGENTS"
echo "  Skills : $TOTAL_SKILLS"

if [ ${#PRESERVED[@]} -gt 0 ]; then
  echo ""
  echo -e "  ${YELLOW}Company-specific skills preserved (not updated):${NC}"
  for name in "${PRESERVED[@]}"; do
    echo "    ~/.copilot/skills/$name"
  done
fi

echo ""
echo -e "  ${BLUE}Tip:${NC} Company-specific skills (never committed) go in:"
echo "       ~/.copilot/skills/company-{name}-{topic}/SKILL.md"
echo ""
echo -e "  ${BLUE}Tip:${NC} For per-project context, run the init-project agent:"
echo "       cd your-project && copilot  # then type /init-project"
echo ""
