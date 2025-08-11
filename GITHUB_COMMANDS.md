# 🚀 GitHub Commands Reference

This file contains all the essential Git and GitHub commands for managing the Meal Planner project.

## 📋 Quick Reference

### Repository Information
- **Repository**: `https://github.com/paulhilton74/Mealplanner.git`
- **Main Branch**: `main`
- **Feature Branch**: `feature/final-clean`

---

## 🔧 Initial Setup Commands

### Clone Repository
```bash
git clone https://github.com/paulhilton74/Mealplanner.git
cd Mealplanner
```

### Set Up Remote (if needed)
```bash
git remote add origin https://github.com/paulhilton74/Mealplanner.git
git remote -v  # Verify remote is set correctly
```

---

## 📝 Daily Development Commands

### Check Status
```bash
git status                    # Check current status
git branch                    # List all branches
git branch -r                 # List remote branches
git log --oneline -10         # View recent commits
```

### Stage and Commit Changes
```bash
git add .                     # Stage all changes
git add filename.swift        # Stage specific file
git commit -m "Your commit message here"
```

### Push Changes
```bash
git push origin feature/final-clean    # Push to feature branch
git push origin main                   # Push to main branch
git push -u origin branch-name         # Push new branch and set upstream
```

### Pull Latest Changes
```bash
git pull origin main                   # Pull from main
git pull origin feature/final-clean    # Pull from feature branch
git fetch origin                       # Fetch without merging
```

---

## 🌿 Branch Management

### Create and Switch Branches
```bash
git checkout -b new-feature-name       # Create and switch to new branch
git checkout main                      # Switch to main branch
git checkout feature/final-clean       # Switch to feature branch
```

### Merge Branches
```bash
git checkout main                      # Switch to main
git merge feature/final-clean          # Merge feature into main
git push origin main                   # Push merged changes
```

### Delete Branches
```bash
git branch -d branch-name              # Delete local branch
git push origin --delete branch-name   # Delete remote branch
```

---

## 🔄 Syncing with GitHub

### Update from GitHub
```bash
git fetch origin                       # Fetch all remote changes
git pull origin main                   # Pull and merge main
git rebase origin/main                 # Rebase current branch on main
```

### Force Push (Use Carefully!)
```bash
git push --force-with-lease origin branch-name    # Safer force push
git push -f origin branch-name                    # Force push (dangerous)
```

---

## 🛠️ Fixing Common Issues

### Undo Last Commit (Keep Changes)
```bash
git reset --soft HEAD~1               # Undo commit, keep changes staged
git reset HEAD~1                      # Undo commit, unstage changes
```

### Discard Local Changes
```bash
git checkout -- filename.swift        # Discard changes to specific file
git reset --hard HEAD                 # Discard all local changes
git clean -fd                         # Remove untracked files and directories
```

### Fix Merge Conflicts
```bash
git status                            # See conflicted files
# Edit files to resolve conflicts
git add .                             # Stage resolved files
git commit -m "Resolve merge conflicts"
```

### Stash Changes
```bash
git stash                             # Stash current changes
git stash pop                         # Apply and remove latest stash
git stash list                        # List all stashes
git stash apply stash@{0}             # Apply specific stash
```

---

## 📦 Release Management

### Tag Releases
```bash
git tag -a v1.0.0 -m "Release version 1.0.0"    # Create annotated tag
git push origin v1.0.0                          # Push tag to GitHub
git tag -l                                       # List all tags
```

### Create Release Branch
```bash
git checkout -b release/v1.0.0        # Create release branch
git push -u origin release/v1.0.0     # Push release branch
```

---

## 🔍 Inspection Commands

### View Changes
```bash
git diff                              # See unstaged changes
git diff --staged                     # See staged changes
git diff HEAD~1                       # Compare with previous commit
git show commit-hash                  # Show specific commit details
```

### Search History
```bash
git log --grep="search term"          # Search commit messages
git log --author="Author Name"        # Filter by author
git log --since="2 weeks ago"         # Filter by date
git blame filename.swift              # See who changed each line
```

---

## 🚨 Emergency Commands

### Reset to Remote State
```bash
git fetch origin
git reset --hard origin/main          # Reset to match remote main
git clean -fd                         # Remove untracked files
```

### Recover Deleted Commits
```bash
git reflog                            # Show reference log
git checkout commit-hash              # Checkout specific commit
git cherry-pick commit-hash           # Apply specific commit
```

---

## 📋 Project-Specific Workflows

### Feature Development Workflow
```bash
# 1. Start new feature
git checkout main
git pull origin main
git checkout -b feature/new-feature-name

# 2. Develop and commit
git add .
git commit -m "Add new feature: description"

# 3. Push feature branch
git push -u origin feature/new-feature-name

# 4. Create Pull Request on GitHub
# 5. After review, merge via GitHub or locally:
git checkout main
git pull origin main
git merge feature/new-feature-name
git push origin main
git branch -d feature/new-feature-name
```

### Hotfix Workflow
```bash
# 1. Create hotfix from main
git checkout main
git pull origin main
git checkout -b hotfix/fix-description

# 2. Fix and commit
git add .
git commit -m "Hotfix: description"

# 3. Push and merge quickly
git push -u origin hotfix/fix-description
# Create PR and merge immediately
```

---

## 🔐 Security Best Practices

### Before Committing
```bash
# Check for sensitive files
git status
git diff --staged

# Ensure API keys are not included
grep -r "sk-" .                       # Search for OpenAI keys
grep -r "API" . --exclude-dir=.git    # Search for API references
```

### Clean Sensitive Data
```bash
# Remove file from git history (use carefully!)
git filter-branch --force --index-filter \
'git rm --cached --ignore-unmatch path/to/sensitive/file' \
--prune-empty --tag-name-filter cat -- --all

# Force push after cleaning (dangerous!)
git push --force-with-lease origin --all
```

---

## 📞 Getting Help

### Git Help
```bash
git help command-name                 # Get help for specific command
git --help                           # General git help
git status --help                    # Help for status command
```

### Useful Aliases (Add to ~/.gitconfig)
```bash
git config --global alias.st status
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.ci commit
git config --global alias.unstage 'reset HEAD --'
git config --global alias.last 'log -1 HEAD'
git config --global alias.visual '!gitk'
```

---

## 📝 Notes

- Always create feature branches for new work
- Write descriptive commit messages
- Pull before pushing to avoid conflicts
- Use `--force-with-lease` instead of `--force` when force pushing
- Keep sensitive data out of commits using .gitignore
- Regular backups: your GitHub repo IS your backup!

---

**Remember**: When in doubt, `git status` is your friend! 🤝
