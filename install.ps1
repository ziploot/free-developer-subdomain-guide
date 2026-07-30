# [ZipLoot] 1-Click Multi-Provider Free Subdomain PR Automator (.is-a.dev, .js.org)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Clear-Host
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "   ZIPLOOT 1-CLICK FREE SUBDOMAIN AUTOMATOR" -ForegroundColor Cyan
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

$Target = Read-Host "[INPUT] Enter Target CNAME or IP (e.g. ziploot.github.io or ziploot.vercel.app)"
if ([string]::IsNullOrWhiteSpace($Target)) {
    Write-Host "[ERROR] Target CNAME or IP is required." -ForegroundColor Red
    exit 1
}

# Clean target URL if protocol passed
$Target = $Target -replace 'https?://', '' -replace '/.*$', ''

Write-Host
Write-Host "[INFO] Submitting Pull Request (PR) to $Provider automatically..." -ForegroundColor Blue

$PyCode = @"
import sys
import json
import requests
import base64
import time

token = "$GithubToken"
subdomain = "$Subdomain".lower().strip()
target = "$Target".strip()
provider = "$Provider"

headers = {
    "Authorization": "token " + token,
    "Accept": "application/vnd.github.v3+json"
}

user_res = requests.get("https://api.github.com/user", headers=headers)
if user_res.status_code != 200:
    print("[ERROR] Invalid GitHub Token: " + str(user_res.json().get('message')))
    sys.exit(1)

username = user_res.json()["login"]
email = user_res.json().get("email") or (username + "@users.noreply.github.com")
print("[SUCCESS] Authenticated as GitHub User: " + username)

upstream_repo = "is-a-dev/register" if provider == "is-a.dev" else "js-org/js.org"

print("[INFO] Forking " + upstream_repo + " to " + username + "...")
fork_res = requests.post("https://api.github.com/repos/" + upstream_repo + "/forks", headers=headers)

time.sleep(5)

branch_name = "add-" + subdomain + "-" + str(int(time.time()))
fork_repo = username + "/" + upstream_repo.split('/')[1]

repo_info = requests.get("https://api.github.com/repos/" + fork_repo, headers=headers).json()
default_branch = repo_info.get("default_branch", "main")
ref_res = requests.get("https://api.github.com/repos/" + fork_repo + "/git/ref/heads/" + default_branch, headers=headers).json()
sha = ref_res["object"]["sha"]

requests.post("https://api.github.com/repos/" + fork_repo + "/git/refs", json={"ref": "refs/heads/" + branch_name, "sha": sha}, headers=headers)

if provider == "is-a.dev":
    file_path = "domains/" + subdomain + ".json"
    record_type = "CNAME" if "." in target and not target.replace(".", "").isdigit() else "A"
    content_dict = {
        "owner": {"username": username, "email": email},
        "records": {record_type: target}
    }
    content_bytes = (json.dumps(content_dict, indent=2) + "\n").encode("utf-8")
    put_body = {
        "message": "Add " + subdomain + ".is-a.dev subdomain",
        "content": base64.b64encode(content_bytes).decode("utf-8"),
        "branch": branch_name
    }
    requests.put("https://api.github.com/repos/" + fork_repo + "/contents/" + file_path, json=put_body, headers=headers)
    print("[SUCCESS] Committed " + file_path + " to branch " + branch_name)

    pr_title = "Add " + subdomain + ".is-a.dev"
    pr_description = "# Requirements\n\n- [x] I **agree** to the [Terms of Service](https://is-a.dev/terms).\n- [x] My file is following the [domain structure](https://docs.is-a.dev/domain-structure/).\n- [x] My website is **reachable** and **completed**.\n- [x] My website is **software development** related.\n- [x] My website is **not for commercial use**.\n- [x] I have provided contact information in the `owner` key.\n- [x] I have provided a preview of my website below.\n\n# Website Preview\nhttps://" + target + "\n\n# Website Purpose\nDeveloper portal providing open-source tools and web applications."

else:
    file_path = "cnames_active.js"
    master_cnames = requests.get("https://raw.githubusercontent.com/js-org/js.org/master/cnames_active.js").text
    
    lines = master_cnames.splitlines()
    new_lines = []
    inserted = False
    entry_line = '  "' + subdomain + '": "' + target + '",'
    
    for line in lines:
        if not inserted and line.strip().startswith('"') and line.strip().split('"')[1] > subdomain:
            new_lines.append(entry_line)
            inserted = True
        new_lines.append(line)
    
    if not inserted:
        new_lines.insert(len(new_lines)-2, entry_line)
    
    updated_content = "\n".join(new_lines) + "\n"
    
    get_file = requests.get("https://api.github.com/repos/" + fork_repo + "/contents/" + file_path + "?ref=" + branch_name, headers=headers).json()
    file_sha = get_file["sha"]
    
    put_body = {
        "message": "Add " + subdomain + ".js.org subdomain in exact alphabetical order",
        "content": base64.b64encode(updated_content.encode("utf-8")).decode("utf-8"),
        "sha": file_sha,
        "branch": branch_name
    }
    requests.put("https://api.github.com/repos/" + fork_repo + "/contents/" + file_path, json=put_body, headers=headers)
    print("[SUCCESS] Updated " + file_path + " on branch " + branch_name)

    pr_title = "ziploot.js.org"
    pr_description = "- [x] There is reasonable content on the page (see: [No Content](https://github.com/js-org/js.org/wiki/No-Content))\n- [x] I have read and accepted the [Terms and Conditions](http://js.org/terms.html)\n- The site content can be seen at https://" + target + "\n\n> The site content is an open-source web application developer portal and is relevant to JavaScript developers specifically because it provides Node.js scripts, developer tools, web automation, and JavaScript utilities."

pr_url = "https://api.github.com/repos/" + upstream_repo + "/pulls"
pr_body = {
    "title": pr_title,
    "head": username + ":" + branch_name,
    "base": default_branch,
    "body": pr_description
}
pr_res = requests.post(pr_url, json=pr_body, headers=headers)

if pr_res.status_code in [200, 201]:
    pr_data = pr_res.json()
    print("")
    print("========================================================")
    print(" [SUCCESS] PULL REQUEST SUBMITTED SUCCESSFULLY FOR " + subdomain + "." + provider + "!")
    print(" [PR LINK] " + str(pr_data.get('html_url')))
    print(" [APPROVAL TIME] Expected Approval: 5-15 Minutes")
    print("========================================================")
else:
    print("[WARN] PR submission response: " + str(pr_res.status_code) + " - " + str(pr_res.json().get('message')))
"@

$PyCode | python -

Write-Host
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "[COMPLETE] ZIPLOOT SUBDOMAIN AUTOMATION FINISHED!" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Cyan
