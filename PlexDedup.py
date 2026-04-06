import os
import json
import time
import requests
import subprocess
import re
import shutil
from plexapi.server import PlexServer

# python3 -m venv dedup && source dedup/bin/activate && pip install requests plexapi --quiet
# ==========================================
# CONFIGURATION
# ==========================================
TMDB_API_KEY = "token"
LIBRARY_DIR = "/media/plex/Movies/"
REVIEW_DIR = "/media/plex/Review/" # <--- THIS IS YOUR "TRASH" FOLDER
INDEX_FILE = "library_state.json"
PLEX_URL = "http://127.0.0.1:32400"
PLEX_TOKEN = "token"
PLEX_LIBRARY_NAME = "Movies"

# ==========================================
# PHASE 0: STATE MANAGEMENT
# ==========================================
def load_index():
    if os.path.exists(INDEX_FILE):
        with open(INDEX_FILE, 'r') as f:
            return json.load(f)
    return {}

def save_index(data):
    temp_file = INDEX_FILE + ".tmp"
    with open(temp_file, 'w') as f:
        json.dump(data, f, indent=4)
    os.replace(temp_file, INDEX_FILE)

# ==========================================
# PHASE 1: DISCOVERY & TMDB MATCHING
# ==========================================
def extract_title_and_year(filename):
    # Strip extension
    name, _ = os.path.splitext(filename)
    
    # Remove TMDB tag if it exists so it doesn't get swept into the title
    name = re.sub(r'\s*\{tmdb-\d+\}', '', name).strip()
    
    # Look for a 4 digit year surrounded by boundaries (find all, pick the last one)
    year_matches = list(re.finditer(r'\b(19\d{2}|20\d{2})\b', name))
    
    if year_matches:
        last_match = year_matches[-1]
        year = last_match.group(1)
        title_raw = name[:last_match.start()]
    else:
        year = None
        title_raw = name 
        
    # Strip out common scene tags
    title_raw = re.sub(r'(?i)(1080p|720p|4k|2160p|bluray|webrip|brrip|x264|x265|hevc|aac|remastered)', '', title_raw)
    
    # --- 2. THE FAST FIX (For -1 and FS/WS tags) ---
    title_raw = re.sub(r'-\d\s*$', '', title_raw)
    title_raw = re.sub(r'(?i)\b(FS|WS)\b', '', title_raw)
    
    # Clean up formatting (replace dots, underscores, brackets with spaces)
    title_clean = re.sub(r'[._\[\]\(\)-]+', ' ', title_raw).strip()
    title_clean = " ".join(title_clean.split())
    
    return title_clean, year

def fetch_tmdb_id(title, year=None):
    time.sleep(0.3)
    url = "https://api.themoviedb.org/3/search/movie"
    params = {"api_key": TMDB_API_KEY, "query": title}
    if year:
        params["year"] = year
    
    try:
        response = requests.get(url, params=params, timeout=10)
        response.raise_for_status()
        results = response.json().get('results', [])
        
        if not results:
            return None, None

        if year and len(results) >= 1:
            return results[0]['id'], results[0]['title']
        elif not year and len(results) == 1:
            return results[0]['id'], results[0]['title']
        elif not year and len(results) > 1:
            search_title_lower = title.lower()
            exact_matches = [r for r in results if r['title'].lower() == search_title_lower]
            if len(exact_matches) == 1:
                return exact_matches[0]['id'], exact_matches[0]['title']
            return None, None
    except Exception as e:
        print(f"API Error for '{title}': {e}")
    return None, None

def fetch_tmdb_details_by_id(tmdb_id):
    time.sleep(0.3)
    url = f"https://api.themoviedb.org/3/movie/{tmdb_id}"
    params = {"api_key": TMDB_API_KEY}
    try:
        response = requests.get(url, params=params, timeout=10)
        if response.status_code == 200:
            data = response.json()
            title = data.get('title', 'Unknown')
            release_date = data.get('release_date', '')
            year = release_date.split('-')[0] if release_date else 'Unknown'
            return title, year
    except Exception as e:
        print(f"API Error fetching details for ID {tmdb_id}: {e}")
    return None, None

def process_file_identification(file_path, filename, index):
    """Helper to handle the logic of API tagging and __ID_ONLY__ intercepts."""
    title, year = extract_title_and_year(filename)

    if title:
        # Check if filename already contains a TMDB tag
        tag_match = re.search(r'\{tmdb-(\d+)\}', filename)
        
        if tag_match:
            tmdb_id = int(tag_match.group(1))
            print(f"Pre-tagged ID [{tmdb_id}] found in filename. Bypassing API...", end=" ")
            print(f"Matched! {title}")
            index[file_path] = {
                "status": "IDENTIFIED",
                "tmdb_id": tmdb_id,
                "clean_name": title,
                "year": year if year else "Unknown"
            }
            return True
        else:
            # Standard API Search
            print(f"Querying TMDB: {title} ({year if year else 'No Year'})...", end=" ")
            tmdb_id, clean_name = fetch_tmdb_id(title, year)
            
            if tmdb_id:
                print(f"Matched! ID: {tmdb_id}")
                index[file_path] = {
                    "status": "IDENTIFIED",
                    "tmdb_id": tmdb_id,
                    "clean_name": clean_name,
                    "year": year if year else "Unknown"
                }
                return True
            
    print("Not Found/Ambiguous.")
    index[file_path] = {"status": "MANUAL_REQUIRED"}
    return False

def run_phase_1(index):
    print("Starting Phase 1: Discovery & Identification...")
    processed_count = 0
    
    for root, dirs, files in os.walk(LIBRARY_DIR):
        for filename in files:
            if not filename.lower().endswith(('.mkv', '.mp4', '.avi', '.m4v')):
                continue
            file_path = os.path.join(root, filename)
            
            if file_path in index:
                continue
                
            process_file_identification(file_path, filename, index)
            
            processed_count += 1
            if processed_count % 10 == 0:
                save_index(index)
                
    save_index(index)
    print("Phase 1 Complete.")

# ==========================================
# PHASE 2: SCORING & DEDUPLICATION
# ==========================================
def calculate_quality_score(file_path):
    cmd = ["ffprobe", "-v", "quiet", "-print_format", "json", "-show_streams", "-show_format", file_path]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        data = json.loads(result.stdout)
    except Exception:
        return 0 

    video_stream = next((s for s in data.get('streams', []) if s.get('codec_type') == 'video'), None)
    if not video_stream:
        return 0

    bitrate = int(data.get('format', {}).get('bit_rate', 0))
    if bitrate == 0:
        bitrate = int(video_stream.get('bit_rate', 0))
    score = bitrate / 1000 

    width = int(video_stream.get('width', 0))
    if width >= 3800: score += 500
    elif width >= 1900: score += 200

    codec = video_stream.get('codec_name', '').lower()
    if codec in ['hevc', 'av1']: score += 100

    pix_fmt = video_stream.get('pix_fmt', '').lower()
    if '10le' in pix_fmt or '10bit' in pix_fmt: score *= 1.20 

    return score

def run_phase_2(index):
    print("Starting Phase 2: Scoring & Deduplication...")
    groups = {}
    
    for path, data in index.items():
        if data["status"] == "IDENTIFIED":
            tmdb_id = data["tmdb_id"]
            if tmdb_id not in groups: groups[tmdb_id] = []
            groups[tmdb_id].append(path)

    for tmdb_id, paths in groups.items():
        if len(paths) > 1:
            clean_name = index[paths[0]]["clean_name"]
            print(f"\nFound duplicate cluster for: {clean_name}")
            highest_score = -1
            winner_path = None
            
            for path in paths:
                score = calculate_quality_score(path)
                print(f"  -> Score: {score:.2f} | File: {os.path.basename(path)}")
                if score > highest_score:
                    highest_score = score
                    winner_path = path
            
            for path in paths:
                if path == winner_path:
                    print(f"  *** WINNER: {os.path.basename(path)}")
                    index[path]["status"] = "KEEPER"
                else:
                    index[path]["status"] = "TRASH"
        elif len(paths) == 1:
            index[paths[0]]["status"] = "KEEPER"

    save_index(index)
    print("\nPhase 2 Complete.")

# ==========================================
# PHASE 3: EXECUTION
# ==========================================
def run_phase_3(index):
    print("Starting Phase 3: Moving & Renaming...")
    if not os.path.exists(REVIEW_DIR):
        os.makedirs(REVIEW_DIR)

    paths = list(index.keys())
    
    for path in paths:
        data = index[path]
        if data["status"] == "TRASH":
            filename = os.path.basename(path)
            dest = os.path.join(REVIEW_DIR, filename)
            print(f"Moving to Review: {filename}")
            if os.path.exists(path):
                try:
                    shutil.move(path, dest)
                    index[path]["status"] = "PROCESSED_TRASH"
                except Exception as e:
                    print(f"  -> ERROR moving file: {e}")
            else:
                index[path]["status"] = "PROCESSED_TRASH"
    
    for path in paths:
        data = index[path]
        if data["status"] == "KEEPER":
            directory = os.path.dirname(path)
            extension = os.path.splitext(path)[1]
            safe_title = re.sub(r'[\\/*?:"<>|]', "", data["clean_name"])
            new_filename = f"{safe_title} ({data['year']}) {{tmdb-{data['tmdb_id']}}}{extension}"
            new_path = os.path.join(directory, new_filename)
            
            if path != new_path:
                print(f"Renaming: {os.path.basename(path)} -> {new_filename}")
                if os.path.exists(path):
                    try:
                        shutil.move(path, new_path)
                        index[new_path] = data
                        index[new_path]["status"] = "PROCESSED_KEEPER"
                        del index[path]
                    except Exception as e:
                        print(f"  -> ERROR renaming file: {e}")
            else:
                index[path]["status"] = "PROCESSED_KEEPER"

    save_index(index)
    print("Phase 3 Complete.")

# ==========================================
# PHASE 1.5: RETRY MANUAL API
# ==========================================
def retry_manual_api(index):
    print("\nStarting Retry: Running upgraded API logic on stragglers...")
    retry_count = 0
    success_count = 0
    
    for path, data in list(index.items()):
        if data["status"] == "MANUAL_REQUIRED":
            retry_count += 1
            filename = os.path.basename(path)
            
            if process_file_identification(file_path=path, filename=filename, index=index):
                success_count += 1
                save_index(index)
                
    print(f"\nRetry Complete! Rescued {success_count} out of {retry_count} stragglers.")

# ==========================================
# PHASE 1.6: PLEX SERVER SYNC
# ==========================================
def sync_with_plex(index):
    print("\nStarting Plex Sync: Checking local server for straggler metadata...")
    try:
        plex = PlexServer(PLEX_URL, PLEX_TOKEN)
        movies_section = plex.library.section(PLEX_LIBRARY_NAME)
    except Exception as e:
        print(f"Failed to connect to Plex Server: {e}")
        return

    print("Fetching library mapping from Plex (this takes a few seconds)...")
    try:
        all_movies = movies_section.all()
    except Exception as e:
        print(f"Failed to fetch movies from Plex: {e}")
        return

    # Pre-build a dictionary of filename -> movie object for instant lookups
    plex_files = {}
    for movie in all_movies:
        for media in movie.media:
            for part in media.parts:
                plex_files[os.path.basename(part.file)] = movie

    sync_count = 0
    success_count = 0

    for path, data in list(index.items()):
        if data["status"] == "MANUAL_REQUIRED":
            sync_count += 1
            filename = os.path.basename(path)
            print(f"Checking Plex for file: {filename}...", end=" ")
            
            movie = plex_files.get(filename)
            if movie:
                tmdb_id = None
                for guid in movie.guids:
                    if guid.id.startswith('tmdb://'):
                        tmdb_id = int(guid.id.split('tmdb://')[1])
                        break
                        
                if tmdb_id:
                    clean_name = movie.title
                    year = str(movie.year) if movie.year else 'Unknown'
                    print(f"SUCCESS! Plex matched it to: {clean_name} [{tmdb_id}]")
                    index[path] = {
                        "status": "IDENTIFIED", 
                        "tmdb_id": tmdb_id, 
                        "clean_name": clean_name, 
                        "year": year
                    }
                    success_count += 1
                else:
                    print("Found in Plex, but it lacks a TMDB ID.")
            else:
                print("Plex hasn't matched this file either.")
                
    save_index(index)
    print(f"\nPlex Sync Complete! Rescued {success_count} out of {sync_count} stragglers.")

# ==========================================
# PHASE 4: MANUAL REVIEW LOOP
# ==========================================
def run_phase_4(index):
    print("Starting Phase 4: Manual Straggler Review...")
    for path, data in list(index.items()):
        if data["status"] == "MANUAL_REQUIRED":
            filename = os.path.basename(path)
            print(f"\nCould not automatically match: {filename}")
            user_input = input("Enter TMDB ID (or type 's' for manual entry/skip): ").strip()
            
            if user_input.lower() == 's':
                print("--- Manual Entry Mode ---")
                title = input("Enter clean Movie Title (or 's' to skip file entirely): ").strip()
                if title.lower() == 's' or not title:
                    print("Skipping file...")
                    continue
                year = input("Enter Year: ").strip()
                id_input = input("Enter TMDB ID (or 0 if unknown): ").strip()
                tmdb_id = int(id_input) if id_input.isdigit() else 0
                index[path] = {"status": "IDENTIFIED", "tmdb_id": tmdb_id, "clean_name": title, "year": year}
                save_index(index)
                print("Updated manually!")
                continue
                
            if user_input.isdigit():
                tmdb_id = int(user_input)
                print(f"Fetching details for TMDB ID {tmdb_id}...")
                title, year = fetch_tmdb_details_by_id(tmdb_id)
                if title:
                    print(f"Found: {title} ({year})")
                    confirm = input("Is this correct? (y/n, default y): ").strip().lower()
                    if confirm == 'y' or confirm == '':
                        index[path] = {"status": "IDENTIFIED", "tmdb_id": tmdb_id, "clean_name": title, "year": year}
                        save_index(index)
                        print("Updated via API!")
                    else:
                        print("Skipping file.")
                else:
                    print("Failed to pull details for that ID. You can try manual mode ('s') next time.")
            else:
                print("Invalid input. Skipping file.")

# ==========================================
# MAIN MENU (DASHBOARD)
# ==========================================
if __name__ == "__main__":
    while True:
        idx = load_index()
        counts = {"IDENTIFIED": 0, "MANUAL_REQUIRED": 0, "KEEPER": 0, "TRASH": 0, "PROCESSED_KEEPER": 0, "PROCESSED_TRASH": 0}
        total_files = len(idx)
        
        for data in idx.values():
            status = data.get("status", "UNKNOWN")
            if status in counts: counts[status] += 1
            else: counts[status] = 1
                
        straggler_count = counts.get("MANUAL_REQUIRED", 0)
        identified_count = counts.get("IDENTIFIED", 0)
        
        print("\n" + "="*45)
        print("         MEDIA LIBRARY DEDUPLICATOR")
        print("="*45)
        print(f" Total Files Tracked: {total_files}")
        print(f" Successfully Matched:{identified_count}")
        print(f" Manual Review Needs: {straggler_count}")
        print(f" Pending Trash:       {counts.get('TRASH', 0)}")
        print("="*45)
        
        print("1. Phase 1: Scan Library & Match to TMDB")
        print("2. Phase 2: Score Qualities & Mark Duplicates")
        print("3. Phase 3: Execute (Move Trash & Rename Keepers)")
        print(f"4. Phase 1.5: Auto-Retry API on Stragglers")
        print(f"5. Phase 1.6: Sync Stragglers with Plex Server")
        print(f"6. Phase 4: Manual Review Stragglers [{straggler_count} waiting]")
        print("7. Run Full Pipeline (Phases 1 -> 2 -> 3)")
        print("0. Exit\n")
        
        choice = input("Select an option: ")
        
        if choice == '1': run_phase_1(idx)
        elif choice == '2': run_phase_2(idx)
        elif choice == '3': run_phase_3(idx)
        elif choice == '4': retry_manual_api(idx)
        elif choice == '5': sync_with_plex(idx)
        elif choice == '6': run_phase_4(idx)
        elif choice == '7':
            run_phase_1(idx)
            run_phase_2(idx)
            run_phase_3(idx)
        elif choice == '0': break
        else: print("Invalid choice.")
