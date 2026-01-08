Help me squash merge all the commits together.
When I check the github repository, I should just see only one commit
Eventhough there is a tag in git hub, do forceful squash merge

help me push v1.0.0 tag to github repo


help me cleanup local git repo.  No additional branches. just a simple state is online repo


Only one commit in github

```
# Step 1: Check current state
git log --oneline --all | head -20
git status
git tag

# Step 2: Create orphan branch and squash
git checkout --orphan new-main
git add -A
git commit -m "Flutter Purchase App - Complete offline-first purchase management system with basket management, vendor quotations, and Google Sheets sync"
git branch -D main
git branch -m main
git push -f origin main

# Step 3: Verify
git log --oneline
```






```
git log --oneline --all | head -20
git status
git tag
git log --oneline --reverse | head -1
git checkout --orphan new-main
git add -A
git commit -m "Flutter Purchase App - Complete offline-first purchase management system with basket management, vendor quotations, and Google Sheets sync"
git log --oneline
git branch -D main
git branch -m main
git push -f origin main
git log --oneline
```

Push tags
```
git tag -a v1.0.0 -m "Release v1.0.0 - Complete offline-first purchase management system with basket management, vendor quotations, and Google Sheets sync"
git push origin v1.0.0
```


```
git tag -d v1.0.0
git push origin :refs/tags/v1.0.0
```

With 2 commits

```
git status
git log --oneline --all
git log --oneline --reverse
git reset --soft 05d5562
git status
git commit -m "Flutter Purchase App - Complete offline-first purchase management system with basket management, vendor quotations, and Google Sheets sync"
git log --oneline
git push --force-with-lease origin main
git log --oneline
```
