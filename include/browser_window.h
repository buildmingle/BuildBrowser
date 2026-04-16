#pragma once

#include <gtk/gtk.h>
#include <webkit/webkit.h>
#include <string>
#include <vector>

// Represents a single browser tab
struct Tab {
    GtkWidget*    web_view;   // WebKitWebView
    GtkWidget*    tab_label;  // Label shown in tab bar
    GtkWidget*    close_btn;  // Close button on tab
    GtkWidget*    tab_box;    // HBox holding label + close btn
    std::string   title;
    std::string   url;
    bool          loading = false;
};

// Main application window — owns all widgets and tabs
class BrowserWindow {
public:
    explicit BrowserWindow(GtkApplication* app);

    // Tab management
    void new_tab(const std::string& url = "https://start.duckduckgo.com");
    void close_tab(int index);
    void switch_tab(int index);

    // Navigation
    void navigate(const std::string& url);
    void go_back();
    void go_forward();
    void reload();
    void stop();

    // Getters
    GtkWidget*  root_widget()  const { return m_window; }
    Tab*        active_tab()         { return m_active_idx >= 0 ? &m_tabs[m_active_idx] : nullptr; }
    int         active_index() const { return m_active_idx; }

    // Called by WebKit signals (must be public for C callbacks)
    void on_load_changed(WebKitWebView* wv, WebKitLoadEvent event);
    void on_title_changed(WebKitWebView* wv, const char* title);
    void on_uri_changed(WebKitWebView* wv, const char* uri);
    void on_load_progress(WebKitWebView* wv, double progress);

private:
    void build_ui(GtkApplication* app);
    void update_nav_buttons();
    void update_url_bar(const std::string& url);
    void update_tab_label(int index, const std::string& title);
    int  find_tab_by_webview(WebKitWebView* wv);

    GtkWidget*       m_window      = nullptr;
    GtkWidget*       m_header_bar  = nullptr;
    GtkWidget*       m_back_btn    = nullptr;
    GtkWidget*       m_fwd_btn     = nullptr;
    GtkWidget*       m_reload_btn  = nullptr;
    GtkWidget*       m_url_entry   = nullptr;
    GtkWidget*       m_progress    = nullptr;  // GtkProgressBar
    GtkWidget*       m_tab_bar     = nullptr;  // GtkBox acting as tab strip
    GtkWidget*       m_stack       = nullptr;  // GtkStack — one page per tab
    GtkWidget*       m_new_tab_btn = nullptr;

    std::vector<Tab> m_tabs;
    int              m_active_idx  = -1;
};
