#!/bin/bash
# Apply modified files to submodules
# This script copies saved files from the patches directory back to their respective submodules

set -e

PATCH_DIR="submodule-patches"
SUBMODULES=("cli" "temporal")

if [ ! -d "$PATCH_DIR" ]; then
    echo "❌ Error: Patch directory '$PATCH_DIR' not found"
    echo "Run extract-submodule-patches.sh first to save modified files"
    exit 1
fi

echo "Applying modified files to submodules..."

for submodule in "${SUBMODULES[@]}"; do
    SUBMODULE_PATCH_DIR="$PATCH_DIR/$submodule"

    if [ ! -d "$SUBMODULE_PATCH_DIR" ]; then
        echo "  ⚠️  No saved files found for '$submodule', skipping..."
        continue
    fi

    echo ""
    echo "Processing submodule: $submodule"

    if [ ! -d "$submodule" ]; then
        echo "  ❌ Submodule directory '$submodule' not found, skipping..."
        continue
    fi

    # Check if submodule has uncommitted changes
    cd "$submodule"
    if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
        echo "  ⚠️  Warning: $submodule has uncommitted changes"
        read -p "  Do you want to continue and overwrite with saved files? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "  ⏭️  Skipping $submodule"
            cd ..
            continue
        fi
    fi
    cd ..

    # Copy files from patch directory to submodule
    FILE_COUNT=0
    while IFS= read -r saved_file; do
        # Get relative path from patch directory
        RELATIVE_PATH="${saved_file#$SUBMODULE_PATCH_DIR/}"
        TARGET_FILE="$submodule/$RELATIVE_PATH"

        # Create target directory if needed
        TARGET_DIR=$(dirname "$TARGET_FILE")
        mkdir -p "$TARGET_DIR"

        # Copy the file
        cp "$saved_file" "$TARGET_FILE"
        FILE_COUNT=$((FILE_COUNT + 1))
        echo "  📥 Copied: $RELATIVE_PATH"
    done < <(find "$SUBMODULE_PATCH_DIR" -type f)

    echo "  ✅ Copied $FILE_COUNT file(s) to $submodule"
done

echo ""
echo "✅ File application complete!"
echo ""
echo "Next steps:"
echo "  1. Review changes in submodules: git diff cli/ temporal/"
echo "  2. Test your changes"
echo "  3. Commit if satisfied"
