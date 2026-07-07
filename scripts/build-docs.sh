#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCS_SRC="$ROOT_DIR/docs"
OUT_DIR="$ROOT_DIR/config/nginx/html/docs"
TEMPLATE="$ROOT_DIR/scripts/docs-template.html"

# Root-relative prefix for sidebar links. The nginx container serves the site
# at "/", so this defaults to empty. GitHub Pages project sites serve under
# "/<repo>/" instead (e.g. https://user.github.io/RemoteLLM/), so CI builds
# set BASE_PATH=/RemoteLLM to keep sidebar links from 404ing there.
BASE_PATH="${BASE_PATH:-}"
BASE_PATH="${BASE_PATH%/}"

command -v pandoc >/dev/null || { echo "pandoc is required (apt install pandoc / brew install pandoc)"; exit 1; }

# name:slug pairs for the top-level docs/*.md files (excludes docs/dev/ and docs/presentations/).
CORE_DOCS=(
  "GETTING_STARTED:getting-started"
  "ARCHITECTURE:architecture"
  "SETUP:setup"
  "OPERATIONS:operations"
  "LITELLM:litellm"
  "LANGFUSE:langfuse"
  "SECURITY_REVIEW:security-review"
  "TROUBLESHOOTING:troubleshooting"
)

title_of() {
  grep -m1 '^# ' "$1" | sed 's/^# *//'
}

# Rewrites cross-doc links (*.md -> *.html) and normalizes the 7 upper-case
# core doc filenames to their lower-case slugs, per docs/dev/doc-update-guide.md
# cross-linking conventions.
rewrite_links() {
  sed -e 's/GETTING_STARTED\.md/getting-started.html/g' \
      -e 's/ARCHITECTURE\.md/architecture.html/g' \
      -e 's/SETUP\.md/setup.html/g' \
      -e 's/OPERATIONS\.md/operations.html/g' \
      -e 's/LITELLM\.md/litellm.html/g' \
      -e 's/LANGFUSE\.md/langfuse.html/g' \
      -e 's/SECURITY_REVIEW\.md/security-review.html/g' \
      -e 's/TROUBLESHOOTING\.md/troubleshooting.html/g' \
      -e 's/\.md"/.html"/g' \
      -e 's/\.md#/.html#/g'
}

render() {
  local src="$1" out="$2" title
  title="$(title_of "$src")"
  mkdir -p "$(dirname "$out")"
  pandoc "$src" -f gfm -t html5 --template "$TEMPLATE" --no-highlight \
    -V title="$title" -V sidebar="$SIDEBAR_HTML" | rewrite_links > "$out"
}

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/guides"

# --- Build the sidebar shared by every page ---
core_links=""
for entry in "${CORE_DOCS[@]}"; do
  name="${entry%%:*}"; slug="${entry##*:}"
  core_links+="<a href=\"${BASE_PATH}/docs/${slug}.html\">$(title_of "$DOCS_SRC/$name.md")</a>"$'\n'
done

guide_links=""
for f in "$DOCS_SRC"/guides/*.md; do
  base="$(basename "$f" .md)"
  [[ "$base" == "README" ]] && continue
  guide_links+="<a href=\"${BASE_PATH}/docs/guides/${base}.html\">$(title_of "$f")</a>"$'\n'
done

SIDEBAR_HTML=$(cat <<EOF
<nav class="sidebar">
  <a class="home-link" href="${BASE_PATH}/docs/">RemoteLLM Docs</a>
  <div class="nav-section">
    <h3>Core Docs</h3>
    $core_links
  </div>
  <div class="nav-section">
    <h3>Guides</h3>
    <a href="${BASE_PATH}/docs/guides/">Guides overview</a>
    $guide_links
  </div>
  <a class="back" href="${BASE_PATH}/">&larr; Back to RemoteLLM</a>
</nav>
EOF
)

# --- Render core docs ---
for entry in "${CORE_DOCS[@]}"; do
  name="${entry%%:*}"; slug="${entry##*:}"
  render "$DOCS_SRC/$name.md" "$OUT_DIR/${slug}.html"
done

# --- Render guides ---
render "$DOCS_SRC/guides/README.md" "$OUT_DIR/guides/index.html"
for f in "$DOCS_SRC"/guides/*.md; do
  base="$(basename "$f" .md)"
  [[ "$base" == "README" ]] && continue
  render "$f" "$OUT_DIR/guides/${base}.html"
done

# --- Landing page at /docs/ ---
landing_src="$(mktemp)"
trap 'rm -f "$landing_src"' EXIT

{
  echo "# RemoteLLM Documentation"
  echo
  echo "Operational reference docs and per-service guides for the RemoteLLM stack."
  echo
  echo "## Core Docs"
  echo
  for entry in "${CORE_DOCS[@]}"; do
    name="${entry%%:*}"; slug="${entry##*:}"
    echo "- [$(title_of "$DOCS_SRC/$name.md")](${slug}.html)"
  done
  echo
  echo "## Guides"
  echo
  echo "[Browse all service guides →](guides/)"
} > "$landing_src"

render "$landing_src" "$OUT_DIR/index.html"

echo "Docs built into $OUT_DIR"
