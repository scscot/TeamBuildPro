#!/bin/bash

# === CONFIGURE THIS ===
GITHUB_REPO_URL="https://github.com/scscot/teambuild_app.git"  # <-- CHANGE THIS

# === Derived paths ===
PROJECT_DIR="$HOME/Desktop/tbp"
BACKUP_DIR="$HOME/Desktop/tbp_backup_$(date +%Y%m%d_%H%M%S)"

echo "🔒 Backing up current tbp/ directory to $BACKUP_DIR ..."
cp -r "$PROJECT_DIR" "$BACKUP_DIR" || {
  echo "❌ Backup failed. Exiting."
  exit 1
}

echo "✅ Backup complete."

cd "$PROJECT_DIR" || {
  echo "❌ Could not navigate to $PROJECT_DIR. Exiting."
  exit 1
}

# Initialize Git if not already a repo
if [ ! -d ".git" ]; then
  echo "🔧 Initializing new Git repository..."
  git init
else
  echo "ℹ️ Git already initialized in this directory."
fi

echo "🔗 Connecting to remote GitHub repository..."
git remote remove origin 2>/dev/null
git remote add origin "$GITHUB_REPO_URL"

# Optional: uncomment if you want to pull remote history
# echo "⬇️ Pulling latest from remote (optional)..."
# git pull origin main --allow-unrelated-histories

echo "📦 Staging all files for commit..."
git add .

echo "📝 Creating commit..."
git commit -m "Reconnected local repo to GitHub – restoring sync"

echo "🚀 Pushing to GitHub..."
git branch -M main
git push -u origin main

echo "✅ Git sync complete! Your local /tbp folder is now reconnected to GitHub."
