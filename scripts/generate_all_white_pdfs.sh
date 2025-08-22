#!/bin/bash
set -e

echo "===> Starting batch PDF generation for all tags..."

ORIGINAL_BRANCH=$(git branch --show-current)

cleanup() {
    if [[ -n "$ORIGINAL_BRANCH" ]]; then
        echo "===> Restoring original branch: $ORIGINAL_BRANCH"
        git checkout "$ORIGINAL_BRANCH" 2>/dev/null || true
    fi
}
trap cleanup EXIT

echo "===> Getting list of all tags..."
TAGS=($(git tag --sort=-version:refname))

if [ ${#TAGS[@]} -eq 0 ]; then
    echo "❌ No git tags found in this repository"
    exit 1
fi

echo "Found ${#TAGS[@]} tags to process"

OUTPUT_DIR="white_pdfs"
mkdir -p "$OUTPUT_DIR"

CURRENT=0
TOTAL=${#TAGS[@]}
SUCCESSFUL=0
FAILED=0

for tag in "${TAGS[@]}"; do
    CURRENT=$((CURRENT + 1))
    echo ""
    echo "===> [$CURRENT/$TOTAL] Processing tag: $tag"
    
    TAG_INDEX=$CURRENT
    
    if bash white_tag.sh "$tag" > "/tmp/white_build_$tag.log" 2>&1; then
        VERSION="${tag#v}"  # Remove 'v' prefix
        if [[ -f "graypaper-white-$VERSION.pdf" ]]; then
            mv "graypaper-white-$VERSION.pdf" "$OUTPUT_DIR/graypaper-white-$tag.pdf"
            echo "✅ Successfully generated: $OUTPUT_DIR/graypaper-white-$tag.pdf"
            SUCCESSFUL=$((SUCCESSFUL + 1))
        else
            echo "❌ PDF not found for tag $tag"
            FAILED=$((FAILED + 1))
        fi
    else
        echo "❌ Build failed for tag $tag (see /tmp/white_build_$tag.log for details)"
        FAILED=$((FAILED + 1))
    fi
    
    rm -f graypaper.white.{aux,bbl,blg,log,out,run.xml,bcf,pdf}
    rm -f preamble.white.tex graypaper.white.tex .tmp
done

echo ""
echo "===> Batch PDF generation complete!"
echo "📊 Summary:"
echo "   Total tags processed: $TOTAL"
echo "   Successful builds: $SUCCESSFUL"
echo "   Failed builds: $FAILED"
echo "   Output directory: $OUTPUT_DIR"

if [[ $SUCCESSFUL -gt 0 ]]; then
    echo ""
    echo "📂 Generated PDFs:"
    ls -la "$OUTPUT_DIR"/*.pdf | while read -r line; do
        echo "   $line"
    done
fi

if [[ $FAILED -gt 0 ]]; then
    echo ""
    echo "⚠️  Build logs for failed tags can be found in /tmp/white_build_*.log"
fi

echo "✅ All done!"