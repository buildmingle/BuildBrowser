cmake_minimum_required(VERSION 3.16)
project(BuildBrowser VERSION 1.0 LANGUAGES CXX OBJCXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(BuildBrowser MACOSX_BUNDLE
    src/main.mm
    src/AppDelegate.mm
    src/BrowserWindowController.mm
    src/TabManager.mm
    src/BookmarkManager.mm
    src/HistoryManager.mm
    src/SettingsManager.mm
    src/DownloadManager.mm
    src/SettingsPanel.mm
    src/SidePanel.mm
    src/DownloadsPanel.mm
    src/ContentBlocker.mm
)

target_include_directories(BuildBrowser PRIVATE include)

target_link_libraries(BuildBrowser PRIVATE
    "-framework Cocoa"
    "-framework WebKit"
    "-framework Foundation"
)

set_target_properties(BuildBrowser PROPERTIES
    MACOSX_BUNDLE_GUI_IDENTIFIER  "io.kiro.browser"
    MACOSX_BUNDLE_BUNDLE_NAME     "BuildBrowser"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "1.0"
)

# ARC + set deployment target so __weak works
target_compile_options(BuildBrowser PRIVATE -fobjc-arc)
target_link_options(BuildBrowser PRIVATE -mmacosx-version-min=12.0)
set(CMAKE_OSX_DEPLOYMENT_TARGET "12.0" CACHE STRING "" FORCE)
