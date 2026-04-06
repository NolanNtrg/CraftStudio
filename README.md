# CraftStudio

CraftStudio is a powerful, native macOS application designed to simplify and enhance various creative workflows. Built with SwiftUI and a focus on premium aesthetics, CraftStudio provides a suite of advanced tools for image editing and audio processing.

## ✨ Features

### 🖌️ Smart Background Eraser
Remove backgrounds or isolate subjects with precision using the advanced eraser module.
*   **Intuitive Canvas:** Supports full zoom and pan capabilities for detailed adjustments.
*   **Precision Control:** Accurately maps coordinates and provides a robust undo/redo system to revert to previous states without resetting the entire canvas.
*   **Seamless Import:** Drag-and-drop images directly into the designated zones or use the native Photos picker / Finder browser.

### ✒️ High-Fidelity Vectorization
Convert raster images into high-quality vector graphics instantly.
*   **Hole Detection:** Advanced algorithms accurately detect and process internal structures and negative space within images.
*   **Customizable Drop Zones:** Easy-to-use interface for adding images with a simple "Rechercher dans Finder" button or drag-and-drop.

### 🎵 YouTube to MP3 Converter
Extract high-quality audio directly from YouTube URLs.
*   **yt-dlp Integration:** Powered by the robust `yt-dlp` library for reliable, fast, and high-quality audio downloads.
*   **Enhanced UX:** Clean interface with highly readable text fields (grey placeholders) and visual progress indicators for track length visibility.

## 🛠️ Built With

*   **SwiftUI:** For a modern, responsive, and native macOS user interface.
*   **XcodeGen:** Project configuration is managed via `project.yml`, ensuring a clean and reproducible `.xcodeproj` structure.
*   **yt-dlp:** For powerful video and audio processing capabilities.

## 🚀 Getting Started

### Prerequisites

*   macOS 14.0 or later.
*   Xcode 15.0 or later.
*   [XcodeGen](https://github.com/yonaskolb/XcodeGen) (for generating the project file).
*   \*`yt-dlp` may require a local python environment or dependencies.

### Installation & Build

1.  **Clone the repository** (if applicable).
2.  **Generate the Xcode Project:**
    Since the `.xcodeproj` file is not tracked in version control, you must generate it using XcodeGen:
    ```bash
    xcodegen generate
    ```
3.  **Open the Project:**
    Open the newly generated `CraftStudio.xcodeproj` in Xcode.
4.  **Build and Run:**
    Select the `CraftStudio` scheme and hit `Cmd + R` to build and run the application.

## 📦 Deployment

To create a distributable `.dmg` file for the application, you can use the `create-dmg` tool:

```bash
create-dmg \
  --volname "Installation CraftStudio" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "CraftStudio.app" 150 190 \
  --hide-extension "CraftStudio.app" \
  --app-drop-link 450 190 \
  "CraftStudio.dmg" \
  "/path/to/your/DerivedData/.../CraftStudio.app"
```