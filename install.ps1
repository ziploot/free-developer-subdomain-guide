# [ZipLoot] 1-Click Multi-Provider Free Subdomain PR Automator (.is-a.dev, .js.org)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Clear-Host
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "   ⚡ ZIPLOOT 1-CLICK FREE SUBDOMAIN AUTOMATOR" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "   Supports: .is-a.dev | .js.org | 100% Automated PR" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host

Write-Host "Select Provider:" -ForegroundColor Yellow
Write-Host " [1] .is-a.dev (General Developer Subdomain)" -ForegroundColor Green
Write-Host " [2] .js.org (JavaScript / Web Project Subdomain)" -ForegroundColor Green
Write-Host

$ProviderChoice = Read-Host "[INPUT] Enter choice (1 or 2)"
$Provider = "is-a.dev"
if ($ProviderChoice -eq "2") { $Provider = "js.org" }

$GithubToken = Read-Host "[INPUT] Enter your GitHub Token (with repo scope)"
if ([string]::IsNullOrWhiteSpace($GithubToken)) {
    Write-Host "[ERROR] GitHub Token is required to submit PR automatically." -ForegroundColor Red
    exit 1
}

$Subdomain = Read-Host "[INPUT] Enter desired Subdomain Name (e.g. ziploot)"
if ([string]::IsNullOrWhiteSpace($Subdomain)) {
    Write-Host "[ERROR] Subdomain name is required." -ForegroundColor Red
    exit 1
}

$Target = Read-Host "[INPUT] Enter Target CNAME or IP (e.g. ziploot.github.io or 1.2.3.4)"
if ([string]::IsNullOrWhiteSpace($Target)) {
    Write-Host "[ERROR] Target CNAME or IP is required." -ForegroundColor Red
    exit 1
}

Write-Host
Write-Host "[INFO] Submitting Pull Request (PR) to $Provider automatically..." -ForegroundColor Blue

$PythonScript = @"
import sys
import json
import requests
import base64

token = "$GithubToken"
subdomain = "$Subdomain".lower().strip()
target = "$Target".strip()
provider = "$Provider"

headers = {
    "Authorization": f"token {token}",
    "Accept": "application/vnd.github.v3+json"
}

# 1. Get authenticated username
user_res = requests.get("https://api.github.com/user", headers=headers)
if user_res.status_code != 200:
    print(f"[ERROR] Invalid GitHub Token: {user_res.json().get('message')}")
    sys.exit(1)

username = user_res.json()["login"]
email = user_res.json().get("email") or f"{username}@users.noreply.github.com"
print(f"[SUCCESS] Authenticated as GitHub User: {username}")

upstream_repo = "is-a-dev/register" if provider == "is-a.dev" else "js-org/js.org"

# 2. Fork upstream repo
print(f"[INFO] Forking {upstream_repo} to {username}/{upstream_repo.split('/')[1]}...")
fork_res = requests.post(f"https://api.github.com/repos/{upstream_repo}/forks", headers=headers)
if fork_res.status_code not in [200, 202]:
    print(f"[WARN] Fork status: {fork_res.status_code} - {fork_res.json().get('message')}")

import time
time.sleep(4)

# 3. Create JSON or edit CNAME file
branch_name = f"add-{subdomain}-{int(time.time())}"
fork_repo = f"{username}/{upstream_repo.split('/')[1]}"

# Get default branch SHA
repo_info = requests.get(f"https://api.github.com/repos/{fork_repo}", headers=headers).json()
default_branch = repo_info.get("default_branch", "main")
ref_res = requests.get(f"https://api.github.com/repos/{fork_repo}/git/ref/heads/{default_branch}", headers=headers).json()
sha = ref_res["object"]["sha"]

# Create new ref/branch
requests.post(f"https://api.github.com/repos/{fork_repo}/git/refs", json={"ref": f"refs/heads/{branch_name}", "sha": sha}, headers=headers)

if provider == "is-a.dev":
    file_path = f"domains/{subdomain}.json"
    record_type = "CNAME" if "." in target and not target.replace(".", "").isdigit() else "A"
    record_val = [target]
    content_dict = {
        "owner": {"username": username, "email": email},
        "record": {record_type: record_val}
    }
    content_bytes = json.dumps(content_dict, indent=2).encode("utf-8")
    commit_msg = f"Add {subdomain}.is-a.dev subdomain"
    
    put_url = f"https://api.github.com/repos/{fork_repo}/contents/{file_path}"
    put_body = {
        "message": commit_msg,
        "content": base64.b64encode(content_bytes).decode("utf-8"),
        "branch": branch_name
    }
    commit_res = requests.put(put_url, json=put_body, headers=headers)
    print(f"[SUCCESS] Committed {file_path} to branch {branch_name}")

else: # js.org
    file_path = "cnames_active.js"
    # Get current file
    get_file = requests.get(f"https://api.github.com/repos/{fork_repo}/contents/{file_path}?ref={branch_name}", headers=headers).json()
    file_sha = get_file["sha"]
    raw_content = base64.b64decode(get_file["content"]).decode("utf-8")
    
    # Append new CNAME record before closing brace
    new_record = f'  "{subdomain}": "{target}",
'
    if f'"{subdomain}":' not in raw_content:
        updated_content = raw_content.rstrip().rstrip("};") + "
" + new_record + "};
"
        put_url = f"https://api.github.com/repos/{fork_repo}/contents/{file_path}"
        put_body = {
            "message": f"Add {subdomain}.js.org subdomain",
            "content": base64.b64encode(updated_content.encode("utf-8")).decode("utf-8"),
            "sha": file_sha,
            "branch": branch_name
        }
        commit_res = requests.put(put_url, json=put_body, headers=headers)
        print(f"[SUCCESS] Updated {file_path} on branch {branch_name}")

# 4. Submit Pull Request (PR) to Upstream
pr_url = f"https://api.github.com/repos/{upstream_repo}/pulls"
pr_body = {
    "title": f"Add {subdomain}.{provider}",
    "head": f"{username}:{branch_name}",
    "base": default_branch,
    "body": f"Automated 1-Click Subdomain Registration for `{subdomain}.{provider}` pointing to `{target}` via ZipLoot Automator."
}
pr_res = requests.post(pr_url, json=pr_body, headers=headers)

if pr_res.status_code in [200, 201]:
    pr_data = pr_res.json()
    print("")
    print("========================================================")
    print(f" 🚀 PULL REQUEST SUBMITTED SUCCESSFULLY FOR {subdomain}.{provider}!")
    print(f" 🔗 PR Link: {pr_data.get('html_url')}")
    print(f" ⏱️ Expected Approval: 5-15 Minutes")
    print("========================================================")
else:
    print(f"[WARN] PR submission status {pr_res.status_code}: {pr_res.json().get('message')}")
"@

$PythonScript | python -

Write-Host
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "[COMPLETE] ZIPLOOT SUBDOMAIN AUTOMATION FINISHED!" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Cyan
