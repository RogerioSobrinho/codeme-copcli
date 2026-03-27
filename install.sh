#!/bin/bash
# install.sh — Everything Copilot CLI Installer
#
# Two modes:
#   LOCAL:  ./install.sh                          (from a cloned repo)
#   REMOTE: curl -fsSL <raw-url>/install.sh | bash  (downloads everything via curl)
#
# Safe to run multiple times (idempotent).
# Preserved: ~/.copilot/skills/company-*/  (company-specific, never overwritten)
# MCP config: existing mcp-config.json renamed to mcp-config.json.old

set -euo pipefail

TARGET_DIR="${HOME}/.copilot"
PRESERVED_PATTERN="company-*"
REPO_RAW="https://raw.githubusercontent.com/RogerioSobrinho/copilot-cli-skills-template/main"

# ─── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[info]${NC}  $*"; }
success() { echo -e "${GREEN}[ok]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[skip]${NC}  $*"; }
error()   { echo -e "${RED}[err]${NC}   $*"; }

# ─── File manifest ─────────────────────────────────────────────────────────────
# All files that compose the template. Update this list when adding new files.
ROOT_FILES=(
  "copilot-instructions.md"
  "mcp-config.json"
)

AGENTS=(
  "code-review.agent.md"
  "doc-writer.agent.md"
  "explore.agent.md"
  "fix.agent.md"
  "init-project.agent.md"
  "new-feature.agent.md"
  "new-project.agent.md"
  "refactor.agent.md"
  "secure.agent.md"
  "write-a-commit.agent.md"
)

SKILLS=(
  "angular-patterns"
  "angular-security"
  "angular-tdd"
  "api-design"
  "continuous-learning"
  "database-migrations"
  "debugging-playbook"
  "deployment-patterns"
  "docker-patterns"
  "e2e-testing"
  "flutter-patterns"
  "flutter-tdd"
  "frontend-principles"
  "git-workflow"
  "iterative-retrieval"
  "java-coding-standards"
  "jpa-patterns"
  "messaging-patterns"
  "observability-patterns"
  "postgres-patterns"
  "resilience-patterns"
  "search-first"
  "skill-authoring"
  "springboot-patterns"
  "springboot-scaffold"
  "springboot-security"
  "springboot-tdd"
  "springboot-verification"
  "strategic-compact"
  "verification-loop"
)

# ─── Detect mode ───────────────────────────────────────────────────────────────
SCRIPT_DIR=""
LOCAL_MODE=false

if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [ -f "$SCRIPT_DIR/copilot-instructions.md" ] && [ -d "$SCRIPT_DIR/agents" ] && [ -d "$SCRIPT_DIR/skills" ]; then
    LOCAL_MODE=true
  fi
fi

echo ""
echo -e "${BLUE}Everything Copilot CLI — Install${NC}"
if $LOCAL_MODE; then
  echo "  Mode   : local (from cloned repo)"
  echo "  Source : $SCRIPT_DIR"
else
  echo "  Mode   : remote (downloading from GitHub)"
  echo "  Source : $REPO_RAW"
fi
echo "  Target : $TARGET_DIR"
echo ""

# ─── Helper: get file content ─────────────────────────────────────────────────
# In local mode, reads from disk. In remote mode, downloads via curl.
get_file() {
  local rel_path="$1"
  if $LOCAL_MODE; then
    cat "$SCRIPT_DIR/$rel_path"
  else
    curl -fsSL "$REPO_RAW/$rel_path"
  fi
}

# ─── Helper: deploy file ──────────────────────────────────────────────────────
# Downloads/reads source, writes to target only if changed.
deploy_file() {
  local rel_path="$1"
  local dest="$2"
  local label="${3:-$rel_path}"

  mkdir -p "$(dirname "$dest")"

  local tmp
  tmp=$(mktemp)
  if get_file "$rel_path" > "$tmp" 2>/dev/null; then
    if [ -f "$dest" ] && diff -q "$tmp" "$dest" &>/dev/null; then
      rm "$tmp"
      return 1
    fi
    mv "$tmp" "$dest"
    return 0
  else
    rm -f "$tmp"
    error "Failed to get: $rel_path"
    return 2
  fi
}

# ─── 1. Create target structure ───────────────────────────────────────────────
mkdir -p "$TARGET_DIR/agents" "$TARGET_DIR/skills"

# ─── 2. Discover preserved skills ─────────────────────────────────────────────
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

# ─── 3. Handle MCP config (rename existing to .old, expand $HOME) ─────────────
MCP_DEST="$TARGET_DIR/mcp-config.json"
if [ -f "$MCP_DEST" ]; then
  # Only rename if the file wasn't deployed by us (check for our expanded path)
  if ! grep -q "$HOME/.copilot/memory.jsonl" "$MCP_DEST" 2>/dev/null; then
    cp "$MCP_DEST" "${MCP_DEST}.old"
    warn "mcp-config.json  → renamed existing to mcp-config.json.old"
  fi
fi

# ─── 4. Deploy root files ─────────────────────────────────────────────────────
ROOT_UPDATED=0
for file in "${ROOT_FILES[@]}"; do
  # mcp-config.json: always deploy (diff will never match due to __HOME__ expansion)
  if [ "$file" = "mcp-config.json" ]; then
    local_tmp=$(mktemp)
    if get_file "$file" > "$local_tmp" 2>/dev/null; then
      sed "s|__HOME__|$HOME|g" "$local_tmp" > "$local_tmp.expanded"
      if [ -f "$TARGET_DIR/$file" ] && diff -q "$local_tmp.expanded" "$TARGET_DIR/$file" &>/dev/null; then
        rm -f "$local_tmp" "$local_tmp.expanded"
      else
        mv "$local_tmp.expanded" "$TARGET_DIR/$file"
        rm -f "$local_tmp"
        success "$file  (MEMORY_FILE_PATH → $HOME/.copilot/memory.jsonl)"
        ((ROOT_UPDATED++)) || true
      fi
    else
      rm -f "$local_tmp"
      error "Failed to get: $file"
    fi
    continue
  fi

  if deploy_file "$file" "$TARGET_DIR/$file" "$file"; then
    success "$file"
    ((ROOT_UPDATED++)) || true
  fi
done

if [ "$ROOT_UPDATED" -eq 0 ]; then
  info "root files — all up to date"
fi

# ─── 5. Deploy agents ─────────────────────────────────────────────────────────
AGENTS_UPDATED=0
for agent in "${AGENTS[@]}"; do
  if deploy_file "agents/$agent" "$TARGET_DIR/agents/$agent" "agents/$agent"; then
    success "agents/$agent"
    ((AGENTS_UPDATED++)) || true
  fi
done

if [ "$AGENTS_UPDATED" -eq 0 ]; then
  info "agents/  — all up to date"
fi

# ─── 6. Deploy skills (skip preserved) ────────────────────────────────────────
SKILLS_UPDATED=0
for skill in "${SKILLS[@]}"; do
  skip=false
  for preserved in "${PRESERVED[@]}"; do
    [ "$skill" = "$preserved" ] && skip=true && break
  done
  $skip && continue

  if deploy_file "skills/$skill/SKILL.md" "$TARGET_DIR/skills/$skill/SKILL.md" "skills/$skill/SKILL.md"; then
    success "skills/$skill/SKILL.md"
    ((SKILLS_UPDATED++)) || true
  fi
done

if [ "$SKILLS_UPDATED" -eq 0 ]; then
  info "skills/  — all up to date"
fi

# ─── 7. Summary ───────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}Done.${NC}"
echo ""

TOTAL_AGENTS=$(ls "$TARGET_DIR/agents"/*.agent.md 2>/dev/null | wc -l | tr -d ' ')
TOTAL_SKILLS=$(find "$TARGET_DIR/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')

echo "  Agents : $TOTAL_AGENTS"
echo "  Skills : $TOTAL_SKILLS"
echo "  MCPs   : sequential-thinking, memory"

if [ ${#PRESERVED[@]} -gt 0 ]; then
  echo ""
  echo -e "  ${YELLOW}Company-specific skills preserved (not updated):${NC}"
  for name in "${PRESERVED[@]}"; do
    echo "    ~/.copilot/skills/$name"
  done
fi

echo ""
echo -e "  ${BLUE}Tip:${NC} Company-specific skills go in:"
echo "       ~/.copilot/skills/company-{name}-{topic}/SKILL.md"
echo ""
echo -e "  ${BLUE}Tip:${NC} For per-project context, run the init-project agent:"
echo "       cd your-project && copilot  # then: /agent → init-project"
echo ""
