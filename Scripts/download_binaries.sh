#!/bin/bash
set -e

# Se placer à la racine du projet
cd "$(dirname "$0")/.."

mkdir -p CraftStudio/Resources/bin
cd CraftStudio/Resources/bin

# yt-dlp
echo "Downloading yt-dlp..."
curl -L -o yt-dlp https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos
chmod +x yt-dlp

# Determine architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    DOWNLOAD_ARCH="arm64"
else
    DOWNLOAD_ARCH="amd64"
fi

# ffmpeg and ffprobe
echo "Downloading ffmpeg and ffprobe for $DOWNLOAD_ARCH..."
curl -L -o ffmpeg.zip "https://ffmpeg.martin-riedl.de/redirect/latest/macos/${DOWNLOAD_ARCH}/release/ffmpeg.zip"
curl -L -o ffprobe.zip "https://ffmpeg.martin-riedl.de/redirect/latest/macos/${DOWNLOAD_ARCH}/release/ffprobe.zip"

unzip -o ffmpeg.zip
unzip -o ffprobe.zip
rm ffmpeg.zip ffprobe.zip

chmod +x ffmpeg ffprobe

xattr -d com.apple.quarantine yt-dlp ffmpeg ffprobe &> /dev/null || true

echo "Binaries downloaded successfully!"
