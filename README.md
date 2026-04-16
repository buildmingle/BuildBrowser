# BuildBrowser

A lightweight C++ web browser built on **WebKitGTK** + **GTK4**.

## Features
- Full web rendering via WebKit (same engine as Safari)
- Multi-tab support with close buttons
- Back / Forward / Reload / Stop navigation
- Smart URL bar — bare domains get `https://`, plain text becomes a DuckDuckGo search
- Thin progress bar while pages load
- Clean GTK4 UI that follows your system theme

## Dependencies

| Package | Ubuntu/Debian | Fedora | Arch |
|---------|--------------|--------|------|
| GTK4 dev | `libgtk-4-dev` | `gtk4-devel` | `gtk4` |
| WebKitGTK 6 | `libwebkitgtk-6.0-dev` | `webkitgtk6.0-devel` | `webkitgtk-6.0` |
| CMake ≥ 3.16 | `cmake` | `cmake` | `cmake` |

```bash
# Ubuntu 24.04+
sudo apt install libgtk-4-dev libwebkitgtk-6.0-dev cmake build-essential

# Fedora 39+
sudo dnf install gtk4-devel webkitgtk6.0-devel cmake gcc-c++

# Arch
sudo pacman -S gtk4 webkitgtk-6.0 cmake base-devel
```

## Build & Run

```bash
chmod +x build.sh
./build.sh
./build/BuildBrowser
```

## Project Layout

```
browser/
├── CMakeLists.txt          # Build definition
├── build.sh                # Convenience build script
├── include/
│   └── browser_window.h    # BrowserWindow + Tab structs
└── src/
    ├── main.cpp            # App entry point, CSS loader
    ├── browser_window.cpp  # All window/tab/navigation logic
    └── style.css           # Application stylesheet
```

## Extending

- **New tab page**: change the default URL in `BrowserWindow::new_tab()`
- **Bookmarks**: add a `std::vector<std::string>` to `BrowserWindow` and a toolbar button
- **Downloads**: connect `WebKitWebContext::download-started` signal
- **Dark mode**: GTK4 follows the system preference automatically
