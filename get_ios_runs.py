import urllib.request
import json
import os

REPO = "djenadimohamedamine-code/carte-nabil"
URL = f"https://api.github.com/repos/{REPO}/actions/runs?per_page=10"

try:
    req = urllib.request.Request(URL, headers={"Accept": "application/vnd.github+json"})
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read())
        runs = data.get("workflow_runs", [])
        for run in runs:
            print(f"ID: {run['id']}, Name: {run['name']}, Status: {run['status']}, Conclusion: {run['conclusion']}, Created At: {run['created_at']}")
except Exception as e:
    print(f"Error: {e}")
