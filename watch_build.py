import urllib.request
import json
import time
import os

REPO = "djenadimohamedamine-code/carte-nabil"
GITHUB_API = f"https://api.github.com/repos/{REPO}/actions/runs"

def check_ios_build():
    print(f"\n[*] Surveillance du build iOS sur GitHub: {REPO}")
    print("[*] Appuyez sur Ctrl+C pour arreter la surveillance.\n")
    
    last_id = None
    
    while True:
        try:
            req = urllib.request.Request(GITHUB_API, headers={"Accept": "application/vnd.github+json"})
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = json.loads(resp.read())
            
            runs = data.get("workflow_runs", [])
            if not runs:
                print("[-] Aucun build trouve.")
                time.sleep(10)
                continue

            # On prend le build le plus recent
            run = runs[0]
            current_id = run["id"]
            status = run["status"]
            conclusion = run["conclusion"]
            created_at = run["created_at"]
            
            if current_id != last_id:
                print(f"\n[+] Nouveau Build Detecte: {run['name']}")
                print(f"[+] ID: {current_id}")
                print(f"[+] Date: {created_at}")
                last_id = current_id

            if status == "completed":
                if conclusion == "success":
                    print(f"\n[SUCCESS] Build iOS reussi ! IPA/App disponible sur GitHub.")
                else:
                    print(f"\n[FAILED] Le build iOS a echoue (Conclusion: {conclusion}).")
                print(f"[URL] {run['html_url']}")
                break
            else:
                # Provide real-time feedback on progress
                print(f"[*] Statut: {status} | Nom: {run['name']}...", end="\r")
                
        except Exception as e:
            print(f"\n[!] Erreur de surveillance: {e}")
        
        time.sleep(10)

if __name__ == "__main__":
    check_ios_build()
