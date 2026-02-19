#!/bin/bash
set -euo pipefail

# Updates the static fallback values in web/index.html with live data from GitHub.
# The page also hydrates at runtime via JS, but this keeps the initial HTML fresh
# for SEO, no-JS visitors, and avoiding flash of stale numbers.

REPO="vjeantet/alerter"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HTML_FILE="$(dirname "$SCRIPT_DIR")/web/index.html"

if [ ! -f "$HTML_FILE" ]; then
    echo "Error: $HTML_FILE not found."
    exit 1
fi

echo "==> Fetching data from GitHub ($REPO)..."

# Fetch repo metadata, releases, and contributors
REPO_JSON=$(gh api "repos/$REPO")
RELEASES_JSON=$(gh api "repos/$REPO/releases?per_page=100")
CONTRIBUTORS_JSON=$(gh api "repos/$REPO/contributors?per_page=100")

# Extract values
STARS=$(echo "$REPO_JSON" | jq -r '.stargazers_count')
FORKS=$(echo "$REPO_JSON" | jq -r '.forks_count')
WATCHERS=$(echo "$REPO_JSON" | jq -r '.subscribers_count')
RELEASES_COUNT=$(echo "$RELEASES_JSON" | jq -r 'length')
LATEST_TAG=$(echo "$RELEASES_JSON" | jq -r '.[0].tag_name // empty')

# Format numbers with commas (1033 -> 1,033)
fmt() { python3 -c "print(f'{int($1):,}')"; }

STARS_FMT=$(fmt "$STARS")
FORKS_FMT=$(fmt "$FORKS")
WATCHERS_FMT=$(fmt "$WATCHERS")
RELEASES_FMT=$(fmt "$RELEASES_COUNT")

echo "    Stars:    $STARS_FMT"
echo "    Forks:    $FORKS_FMT"
echo "    Watchers: $WATCHERS_FMT"
echo "    Releases: $RELEASES_FMT"
echo "    Latest:   $LATEST_TAG"

# ── Update static fallback values in HTML ─────────────────

# Hero badges
sed -i '' -E "s|(id=\"hero-version\">)[^<]*(</span>)|\1${LATEST_TAG}\2|" "$HTML_FILE"
sed -i '' -E "s|(id=\"hero-stars\">)[^<]*(</span>)|\1${STARS_FMT} stars\2|" "$HTML_FILE"

# Stats section
sed -i '' -E "s|(id=\"stat-stars\">)[^<]*(</div>)|\1${STARS_FMT}\2|" "$HTML_FILE"
sed -i '' -E "s|(id=\"stat-forks\">)[^<]*(</div>)|\1${FORKS_FMT}\2|" "$HTML_FILE"
sed -i '' -E "s|(id=\"stat-watchers\">)[^<]*(</div>)|\1${WATCHERS_FMT}\2|" "$HTML_FILE"
sed -i '' -E "s|(id=\"stat-releases\">)[^<]*(</div>)|\1${RELEASES_FMT}\2|" "$HTML_FILE"

# ── Update contributors list ──────────────────────────────

echo "==> Updating contributors..."

CONTRIB_COUNT=$(echo "$CONTRIBUTORS_JSON" | jq -r 'length')
echo "    Found $CONTRIB_COUNT contributors"

# Write contributors HTML to a temp file (avoids awk newline issues)
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

for i in $(seq 0 $((CONTRIB_COUNT - 1))); do
    LOGIN=$(echo "$CONTRIBUTORS_JSON" | jq -r ".[$i].login")
    AVATAR=$(echo "$CONTRIBUTORS_JSON" | jq -r ".[$i].avatar_url")
    PROFILE=$(echo "$CONTRIBUTORS_JSON" | jq -r ".[$i].html_url")

    cat >> "$TMPFILE" <<CONTRIBUTOR
      <a href="${PROFILE}" class="contributor" target="_blank" rel="noopener">
        <img src="${AVATAR}&amp;s=104" alt="${LOGIN}" loading="lazy" width="52" height="52">
        <span>${LOGIN}</span>
      </a>
CONTRIBUTOR
done

# Replace the contributors block: everything between
# <div class="contributors fade-in"> and the next </div>
awk '
    /class="contributors fade-in">/ {
        print
        while ((getline line < "'"$TMPFILE"'") > 0) print line
        skip = 1
        next
    }
    skip && /^[[:space:]]*<\/div>/ {
        skip = 0
        print
        next
    }
    !skip { print }
' "$HTML_FILE" > "${HTML_FILE}.tmp" && mv "${HTML_FILE}.tmp" "$HTML_FILE"

echo "==> Done. Updated $HTML_FILE"
