#!/bin/bash
set -e

CURRENT_BRANCH=`git branch --show-current`

cleanup() {
    if [[ -n "$SELECTED_TAG" && -n "$CURRENT_BRANCH" ]]; then
        echo "===> Restoring original branch: $CURRENT_BRANCH"
        git checkout "$CURRENT_BRANCH"
    fi
}
trap cleanup EXIT

echo "===> Available tags:"
TAGS=($(git tag --sort=-version:refname))
for i in "${!TAGS[@]}"; do
    echo "$((i+1)). ${TAGS[$i]}"
done

echo
read -p "Select a tag number (or press Enter for current branch): " SELECTION

if [[ -n "$SELECTION" && "$SELECTION" =~ ^[0-9]+$ && "$SELECTION" -ge 1 && "$SELECTION" -le "${#TAGS[@]}" ]]; then
    SELECTED_TAG="${TAGS[$((SELECTION-1))]}"
    VERSION="${SELECTED_TAG#v}"  # Remove 'v' prefix
    echo "===> Checking out tag: $SELECTED_TAG"
    git checkout "$SELECTED_TAG"
    
    TAG_DATE=$(git log -1 --format="%ci" "$SELECTED_TAG" | cut -d' ' -f1)
    if command -v gdate >/dev/null 2>&1; then
        TAG_DATE_FORMATTED=$(gdate -d "$TAG_DATE" "+%B %d %Y" 2>/dev/null)
    elif date -j -f "%Y-%m-%d" "$TAG_DATE" "+%B %d %Y" >/dev/null 2>&1; then
        TAG_DATE_FORMATTED=$(date -j -f "%Y-%m-%d" "$TAG_DATE" "+%B %d %Y")
    else
        TAG_DATE_FORMATTED=$(date -d "$TAG_DATE" "+%B %d %Y" 2>/dev/null)
    fi
    
    if [[ -z "$TAG_DATE_FORMATTED" ]]; then
        echo "Warning: Could not format date '$TAG_DATE', using fallback"
        TAG_DATE_FORMATTED="$TAG_DATE"
    fi
    USE_TAG_DATE=true
else
    VERSION=`cat VERSION`
    echo "===> Using current branch: $CURRENT_BRANCH"
    USE_TAG_DATE=false
fi

echo "===> Cleaning previous build artifacts..."
rm -f graypaper.white.{aux,bbl,blg,log,out,run.xml,bcf,pdf}
rm -f graypaper-white-$VERSION.{aux,bbl,blg,log,out,run.xml,bcf,pdf}
rm -f preamble.white.tex graypaper.white.tex .tmp

echo "===> Copying sources..."
cp graypaper.tex graypaper.white.tex
cp preamble.tex preamble.white.tex

echo "===> Updating references..."
sed 's/\\input{preamble\.tex}/\\input{preamble.white.tex}/g' graypaper.white.tex > .tmp && mv .tmp graypaper.white.tex

echo "===> Removing grey colors and PNG assets completely..."

sed '/jam-pen-back.png/d' graypaper.white.tex > .tmp && mv .tmp graypaper.white.tex

sed '/assets\/.*\.png/d' graypaper.white.tex > .tmp && mv .tmp graypaper.white.tex

sed 's/\\pagecolor{verydarkgray}/\\pagecolor{white}/' graypaper.white.tex > .tmp && mv .tmp graypaper.white.tex

sed 's/\\color{white}/\\color{black}/' graypaper.white.tex > .tmp && mv .tmp graypaper.white.tex

sed '/\\makegpbackground/d' graypaper.white.tex > .tmp && mv .tmp graypaper.white.tex

awk '
  BEGIN {skip=0; brace_count=0}
  /AddToShipoutPicture/ {skip=1; brace_count=0; next}
  skip && /\{/ {brace_count++}
  skip && /\}/ {brace_count--; if(brace_count < 0) {skip=0; next}}
  skip {next}
  {print}
' preamble.white.tex > .tmp && mv .tmp preamble.white.tex

sed 's/\\definecolor{verydarkgray}{gray}{0.15}/\\definecolor{verydarkgray}{gray}{1}/' preamble.white.tex > .tmp && mv .tmp preamble.white.tex
sed 's/\\definecolor{verylightgray}{gray}{0.85}/\\definecolor{verylightgray}{gray}{0}/' preamble.white.tex > .tmp && mv .tmp preamble.white.tex

sed '/assets\/.*\.png/d' preamble.white.tex > .tmp && mv .tmp preamble.white.tex

if [[ "$USE_TAG_DATE" == "true" ]]; then
    echo "===> Using tag date: $TAG_DATE_FORMATTED"
    perl -pe "s/\\\\today/$TAG_DATE_FORMATTED/g" preamble.white.tex > .tmp && mv .tmp preamble.white.tex
    echo "===> Verification: checking if replacement worked..."
    if grep -q "$TAG_DATE_FORMATTED" preamble.white.tex; then
        echo "✓ Date replacement successful - found '$TAG_DATE_FORMATTED' in preamble"
    else
        echo "✗ Date replacement failed - '$TAG_DATE_FORMATTED' not found"
    fi
fi

echo "===> Building white-background PDF..."
xelatex -interaction=nonstopmode -jobname=graypaper.white "\def\inputfile{graypaper.white}\input{\inputfile}.tex"
biber graypaper.white || true
xelatex -interaction=nonstopmode graypaper.white.tex
xelatex -interaction=nonstopmode graypaper.white.tex

cp graypaper.white.pdf graypaper-white-$VERSION.pdf

echo "===> Cleaning up temporary files..."
rm -f graypaper.white.{aux,bbl,blg,log,out,run.xml,bcf,pdf}
rm -f preamble.white.tex graypaper.white.tex .tmp

echo "✅ Done! Output: graypaper-white-$VERSION.pdf"
