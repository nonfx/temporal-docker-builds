#!/bin/bash
# Extract modified files from submodules
# This script copies any modified files from submodules to the patches directory
# preserving their folder structure

set -e

PATCH_DIR="submodule-patches"
SUBMODULES=("cli" "temporal")

# Create patch directory if it doesn't exist
mkdir -p "$PATCH_DIR"

echo "Extracting modified files from submodules..."

for submodule in "${SUBMODULES[@]}"; do
    echo ""
    echo "Processing submodule: $submodule"

    if [ ! -d "$submodule" ]; then
        echo "  ⚠️  Submodule directory '$submodule' not found, skipping..."
        continue
    fi

    cd "$submodule"

    # Check if there are any changes (staged, unstaged, or untracked)
    if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
        echo "  ✓ No changes detected in $submodule"
        cd ..
        continue
    fi

    # Create submodule directory in patches
    SUBMODULE_PATCH_DIR="../$PATCH_DIR/$submodule"
    mkdir -p "$SUBMODULE_PATCH_DIR"

    # Get list of modified, staged, and untracked files
    CHANGED_FILES=$(git diff --name-only HEAD 2>/dev/null || true)
    UNTRACKED_FILES=$(git ls-files --others --exclude-standard 2>/dev/null || true)
    ALL_FILES=$(echo -e "${CHANGED_FILES}\n${UNTRACKED_FILES}" | sort -u | grep -v '^$')

    if [ -z "$ALL_FILES" ]; then
        echo "  ✓ No files to copy"
        cd ..
        continue
    fi

    FILE_COUNT=0
    while IFS= read -r file; do
        if [ -n "$file" ] && [ -f "$file" ]; then
            # Create directory structure in patch dir
            TARGET_DIR="$SUBMODULE_PATCH_DIR/$(dirname "$file")"
            mkdir -p "$TARGET_DIR"

            # Copy the file
            cp "$file" "$SUBMODULE_PATCH_DIR/$file"
            FILE_COUNT=$((FILE_COUNT + 1))
            echo "  📄 Copied: $file"
        fi
    done <<< "$ALL_FILES"

    echo "  ✅ Copied $FILE_COUNT file(s) from $submodule"

    cd ..
done

echo ""
echo "✅ File extraction complete!"
echo "Modified files saved in: $PATCH_DIR/"
find "$PATCH_DIR" -type f 2>/dev/null | sed 's/^/  /' || echo "(No files copied)"
