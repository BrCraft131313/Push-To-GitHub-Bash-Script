#!/bin/bash

# التحقق من وجود أداة GitHub CLI (gh) للإنشاء والتحقق
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is required to check permissions and create repositories."
    echo "Please install 'gh' and login using 'gh auth login'."
    exit 1
fi

# استقبال مسار المجلد ورابط المستودع أو اسم المستودع
read -p "Enter The Path For The Folder & The Repo URL/Name (separated by comma): " INPUT

# فصل المسار عن الرابط أو الاسم
FOLDER_PATH=$(echo "$INPUT" | cut -d',' -f1 | xargs)
REPO_INPUT=$(echo "$INPUT" | cut -d',' -f2 | xargs)

# 1. التحقق من وجود المجلد المحلي
if [ ! -d "$FOLDER_PATH" ]; then
    echo "Error: Directory $FOLDER_PATH does not exist!"
    exit 1
fi

# 2. الحصول على اسم المستخدم الحالي المصرح له عبر gh CLI
AUTHENTICATED_USER=$(gh api user --jq '.login' 2>/dev/null)

if [ -z "$AUTHENTICATED_USER" ]; then
    echo "Error: You are not logged into GitHub CLI. Run 'gh auth login' first."
    exit 1
fi

# 3. معالجة وتحديد اسم المستودع والمالك Target User (عالمي بالكامل، يدعم أي مستخدم أو رابط أو اسم مفرد)
if [[ "$REPO_INPUT" =~ ^https://github\.com/([^/]+)/([^/.]+)(\.git)?$ ]]; then
    # إذا تم إدخال رابط كامل، يستخرج المالك واسم المستودع منه مباشرة
    TARGET_OWNER="${BASH_REMATCH[1]}"
    REPO_NAME="${BASH_REMATCH[2]}"
else
    # إذا تم إدخال اسم المستودع فقط، يربطه بالمستخدم المسجل حالياً
    TARGET_OWNER="$AUTHENTICATED_USER"
    REPO_NAME="$REPO_INPUT"
fi

# 4. التأكد من الأمان والملكية (هل الحساب المستهدف هو نفس الحساب المسجل؟)
if [ "$TARGET_OWNER" != "$AUTHENTICATED_USER" ]; then
    echo "Security Alert: Permission denied!"
    echo "You ($AUTHENTICATED_USER) cannot create or force push to a repository owned by ($TARGET_OWNER)."
    exit 1
fi

FULL_REPO_URL="https://github.com/$TARGET_OWNER/$REPO_NAME.git"

# 5. التحقق من وجود المستودع على GitHub أو إنشائه تلقائياً لأي مستخدم مسجل
if ! gh repo view "$TARGET_OWNER/$REPO_NAME" &>/dev/null; then
    echo "Repository '$TARGET_OWNER/$REPO_NAME' does not exist. Creating it now..."
    gh repo create "$TARGET_OWNER/$REPO_NAME" --public --confirm || {
        echo "Error: Failed to create repository on GitHub."
        exit 1
    }
fi

# 6. الانتقال إلى أي مسار مجلد يحدده المستخدم وتنفيذ الرفع العالمي
cd "$FOLDER_PATH" || exit

if [ ! -d ".git" ]; then
    git init
    git branch -M main
fi

git remote remove origin 2>/dev/null
git remote add origin "$FULL_REPO_URL"

git add -A
git commit -m "Auto sync files and folders"
git push -u origin main --force

echo "Done! All contents from $FOLDER_PATH uploaded successfully to $FULL_REPO_URL."
