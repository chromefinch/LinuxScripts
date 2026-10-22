### 1. The Smart Download Script

Create a new file named `takeout.sh` (`nano takeout.sh`), paste the following code, and save it.

```bash
#!/bin/bash

TOTAL_PARTS=114
BASE_NAME="takeout-blah"
TOKEN="token"
USER_ID="user"

for n in $(seq 1 $TOTAL_PARTS); do
  padded=$(printf "%03d" $n)
  idx=$((n - 1))
  filename="${BASE_NAME}-${padded}.zip"
  url="https://takeout-download.usercontent.google.com/download/${filename}?j=${TOKEN}&i=${idx}&user=${USER_ID}&authuser=0"

  while true; do
    # 1. Check if a valid ZIP already exists
    if [ -f "$filename" ]; then
      mime=$(file -b --mime-type "$filename")
      if [ "$mime" = "application/zip" ]; then
        echo "✅ $filename is already a valid ZIP. Skipping."
        break # Move to the next part
      else
        echo "🗑️ $filename is corrupted or an HTML login page. Deleting..."
        rm "$filename"
      fi
    fi

    # 2. Pause if cookies.txt is missing
    while [ ! -f "cookies.txt" ]; do
      echo "--------------------------------------------------------"
      echo "⏸️  COOKIE EXPIRED OR MISSING."
      echo "Please export a fresh cookies.txt to this folder."
      read -p "Press [Enter] when the new cookies.txt is ready..."
    done

    # 3. Download, using -O to force a clean filename
    echo "⬇️ Downloading $filename..."
    wget --continue --tries=5 -O "$filename" --load-cookies cookies.txt "$url"

    # 4. Verify what Google actually sent us
    mime=$(file -b --mime-type "$filename")
    if [ "$mime" = "application/zip" ]; then
      echo "✅ Successfully verified $filename"
      break # Move to the next part
    else
      echo "❌ Cookie expired! Google sent an HTML redirect."
      rm "$filename"
      rm "cookies.txt"
      echo "🗑️ Deleted the fake ZIP and the expired cookies.txt."
      # Loop restarts automatically, hitting the pause prompt
    fi
  done
done

echo "🎉 All $TOTAL_PARTS parts downloaded successfully!"

```

### 2. Run It

Make the script executable and run it:

```bash
chmod +x takeout.sh
./takeout.sh

```

Because of the `-O` flag, every file will save with a perfectly clean name. Because of the `file -b --mime-type` check, it will never be tricked by a 50KB HTML file disguising itself as a ZIP. When Google kicks you out, the script will halt, delete the trash, and wait for you.
