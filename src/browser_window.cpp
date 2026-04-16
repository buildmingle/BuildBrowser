#include "browser_window.h"
#include <cstring>
#include <string>

// ─── helpers ────────────────────────────────────────────────────────────────

// Ensure a URL has a scheme; bare text becomes a DuckDuckGo search
static std::string sanitize_url(const std::string &input) {
  if (input.empty())
    return "https://start.duckduckgo.com";
  if (input.rfind("http://", 0) == 0 || input.rfind("https://", 0) == 0)
    return input;
  // Looks like a domain (contains a dot, no spaces)?
  if (input.find('.') != std::string::npos &&
      input.find(' ') == std::string::npos)
    return "https://" + input;
  // Otherwise treat as a search query
  return "https://duckduckgo.com/?q=" +
         std::string(g_uri_escape_string(input.c_str(), nullptr, false));
}

// ─── C-style signal trampolines ─────────────────────────────────────────────

struct TabSignalData {
  BrowserWindow *bw;
  WebKitWebView *wv;
};

static void cb_load_changed(WebKitWebView *wv, WebKitLoadEvent ev,
                            gpointer ud) {
  static_cast<BrowserWindow *>(ud)->on_load_changed(wv, ev);
}
static void cb_title_changed(WebKitWebView *wv, GParamSpec *, gpointer ud) {
  const char *t = webkit_web_view_get_title(wv);
  static_cast<BrowserWindow *>(ud)->on_title_changed(wv, t ? t : "New Tab");
}
static void cb_uri_changed(WebKitWebView *wv, GParamSpec *, gpointer ud) {
  const char *u = webkit_web_view_get_uri(wv);
  static_cast<BrowserWindow *>(ud)->on_uri_changed(wv, u ? u : "");
}
static void cb_progress_changed(WebKitWebView *wv, GParamSpec *, gpointer ud) {
  double p = webkit_web_view_get_estimated_load_progress(wv);
  static_cast<BrowserWindow *>(ud)->on_load_progress(wv, p);
}

// ─── BrowserWindow ──────────────────────────────────────────────────────────

BrowserWindow::BrowserWindow(GtkApplication *app) {
  build_ui(app);
  new_tab(); // open a blank tab on startup
}

void BrowserWindow::build_ui(GtkApplication *app) {
  // ── Window ──────────────────────────────────────────────────────────────
  m_window = gtk_application_window_new(app);
  gtk_window_set_title(GTK_WINDOW(m_window), "BuildBrowser");
  gtk_window_set_default_size(GTK_WINDOW(m_window), 1280, 800);

  // ── Header bar ──────────────────────────────────────────────────────────
  m_header_bar = gtk_header_bar_new();
  gtk_header_bar_set_show_title_buttons(GTK_HEADER_BAR(m_header_bar), TRUE);
  gtk_window_set_titlebar(GTK_WINDOW(m_window), m_header_bar);

  // Back / Forward / Reload buttons
  auto *nav_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 2);
  gtk_widget_add_css_class(nav_box, "linked"); // makes them look like a group

  m_back_btn = gtk_button_new_from_icon_name("go-previous-symbolic");
  m_fwd_btn = gtk_button_new_from_icon_name("go-next-symbolic");
  m_reload_btn = gtk_button_new_from_icon_name("view-refresh-symbolic");

  gtk_widget_set_tooltip_text(m_back_btn, "Back");
  gtk_widget_set_tooltip_text(m_fwd_btn, "Forward");
  gtk_widget_set_tooltip_text(m_reload_btn, "Reload");

  gtk_box_append(GTK_BOX(nav_box), m_back_btn);
  gtk_box_append(GTK_BOX(nav_box), m_fwd_btn);
  gtk_box_append(GTK_BOX(nav_box), m_reload_btn);
  gtk_header_bar_pack_start(GTK_HEADER_BAR(m_header_bar), nav_box);

  // URL entry — stretches to fill available space
  m_url_entry = gtk_entry_new();
  gtk_entry_set_placeholder_text(GTK_ENTRY(m_url_entry),
                                 "Search or enter address…");
  gtk_widget_set_hexpand(m_url_entry, TRUE);
  gtk_header_bar_set_title_widget(GTK_HEADER_BAR(m_header_bar), m_url_entry);

  // New-tab button on the right
  m_new_tab_btn = gtk_button_new_from_icon_name("tab-new-symbolic");
  gtk_widget_set_tooltip_text(m_new_tab_btn, "New Tab");
  gtk_header_bar_pack_end(GTK_HEADER_BAR(m_header_bar), m_new_tab_btn);

  // ── Main layout: tab strip on top, web content below ────────────────────
  auto *vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
  gtk_window_set_child(GTK_WINDOW(m_window), vbox);

  // Progress bar (hidden when not loading)
  m_progress = gtk_progress_bar_new();
  gtk_widget_set_visible(m_progress, FALSE);
  gtk_box_append(GTK_BOX(vbox), m_progress);

  // Tab strip
  m_tab_bar = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 2);
  gtk_widget_add_css_class(m_tab_bar, "tab-bar");
  gtk_widget_set_margin_start(m_tab_bar, 4);
  gtk_widget_set_margin_end(m_tab_bar, 4);
  gtk_widget_set_margin_top(m_tab_bar, 4);
  gtk_box_append(GTK_BOX(vbox), m_tab_bar);

  // Web view stack
  m_stack = gtk_stack_new();
  gtk_widget_set_vexpand(m_stack, TRUE);
  gtk_box_append(GTK_BOX(vbox), m_stack);

  // ── Signal connections ───────────────────────────────────────────────────
  g_signal_connect(m_back_btn, "clicked",
                   G_CALLBACK(+[](GtkButton *, gpointer ud) {
                     static_cast<BrowserWindow *>(ud)->go_back();
                   }),
                   this);

  g_signal_connect(m_fwd_btn, "clicked",
                   G_CALLBACK(+[](GtkButton *, gpointer ud) {
                     static_cast<BrowserWindow *>(ud)->go_forward();
                   }),
                   this);

  g_signal_connect(m_reload_btn, "clicked",
                   G_CALLBACK(+[](GtkButton *, gpointer ud) {
                     auto *bw = static_cast<BrowserWindow *>(ud);
                     if (auto *t = bw->active_tab(); t && t->loading)
                       bw->stop();
                     else
                       bw->reload();
                   }),
                   this);

  g_signal_connect(m_new_tab_btn, "clicked",
                   G_CALLBACK(+[](GtkButton *, gpointer ud) {
                     static_cast<BrowserWindow *>(ud)->new_tab();
                   }),
                   this);

  // Navigate on Enter in URL bar
  g_signal_connect(
      m_url_entry, "activate", G_CALLBACK(+[](GtkEntry *e, gpointer ud) {
        const char *text = gtk_editable_get_text(GTK_EDITABLE(e));
        static_cast<BrowserWindow *>(ud)->navigate(text ? text : "");
      }),
      this);
}

// ─── Tab management ─────────────────────────────────────────────────────────

void BrowserWindow::new_tab(const std::string &url) {
  Tab tab;

  // WebKit web view with sensible settings
  auto *settings = webkit_settings_new();
  webkit_settings_set_enable_javascript(settings, TRUE);
  webkit_settings_set_enable_smooth_scrolling(settings, TRUE);
  webkit_settings_set_enable_developer_extras(settings, TRUE);

  tab.web_view = webkit_web_view_new_with_settings(settings);
  g_object_unref(settings);
  gtk_widget_set_vexpand(tab.web_view, TRUE);
  gtk_widget_set_hexpand(tab.web_view, TRUE);

  // Connect WebKit signals
  g_signal_connect(tab.web_view, "load-changed", G_CALLBACK(cb_load_changed),
                   this);
  g_signal_connect(tab.web_view, "notify::title", G_CALLBACK(cb_title_changed),
                   this);
  g_signal_connect(tab.web_view, "notify::uri", G_CALLBACK(cb_uri_changed),
                   this);
  g_signal_connect(tab.web_view, "notify::estimated-load-progress",
                   G_CALLBACK(cb_progress_changed), this);

  // Tab strip widget: [favicon] [label] [×]
  tab.tab_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 4);
  tab.tab_label = gtk_label_new("New Tab");
  gtk_label_set_max_width_chars(GTK_LABEL(tab.tab_label), 20);
  gtk_label_set_ellipsize(GTK_LABEL(tab.tab_label), PANGO_ELLIPSIZE_END);
  gtk_widget_set_hexpand(tab.tab_label, TRUE);

  tab.close_btn = gtk_button_new_from_icon_name("window-close-symbolic");
  gtk_widget_add_css_class(tab.close_btn, "flat");
  gtk_widget_add_css_class(tab.close_btn, "circular");
  gtk_widget_set_tooltip_text(tab.close_btn, "Close tab");

  gtk_box_append(GTK_BOX(tab.tab_box), tab.tab_label);
  gtk_box_append(GTK_BOX(tab.tab_box), tab.close_btn);

  // Wrap in a toggle button so clicking selects the tab
  auto *tab_btn = gtk_toggle_button_new();
  gtk_widget_add_css_class(tab_btn, "tab-button");
  gtk_button_set_child(GTK_BUTTON(tab_btn), tab.tab_box);
  gtk_widget_set_size_request(tab_btn, 160, -1);

  int idx = static_cast<int>(m_tabs.size());
  m_tabs.push_back(std::move(tab));

  // Add web view to stack
  std::string page_name = "tab-" + std::to_string(idx);
  gtk_stack_add_named(GTK_STACK(m_stack), m_tabs[idx].web_view,
                      page_name.c_str());

  // Add tab button to tab bar
  gtk_box_append(GTK_BOX(m_tab_bar), tab_btn);

  // Close button signal — capture index by value at creation time
  g_signal_connect(m_tabs[idx].close_btn, "clicked",
                   G_CALLBACK(+[](GtkButton *, gpointer ud) {
                     auto *pair =
                         static_cast<std::pair<BrowserWindow *, int> *>(ud);
                     pair->first->close_tab(pair->second);
                     delete pair;
                   }),
                   new std::pair<BrowserWindow *, int>(this, idx));

  // Tab select signal
  g_signal_connect(
      tab_btn, "clicked", G_CALLBACK(+[](GtkToggleButton *, gpointer ud) {
        auto *pair = static_cast<std::pair<BrowserWindow *, int> *>(ud);
        pair->first->switch_tab(pair->second);
      }),
      new std::pair<BrowserWindow *, int>(this, idx));

  switch_tab(idx);
  navigate(url);
}

void BrowserWindow::close_tab(int index) {
  if (index < 0 || index >= static_cast<int>(m_tabs.size()))
    return;
  if (m_tabs.size() == 1) {
    // Last tab — just navigate home instead of closing
    navigate("https://start.duckduckgo.com");
    return;
  }

  // Remove from stack and tab bar
  gtk_stack_remove(GTK_STACK(m_stack), m_tabs[index].web_view);

  // Find and remove the tab button from the tab bar
  int i = 0;
  for (auto *child = gtk_widget_get_first_child(m_tab_bar); child != nullptr;
       child = gtk_widget_get_next_sibling(child), ++i) {
    if (i == index) {
      gtk_box_remove(GTK_BOX(m_tab_bar), child);
      break;
    }
  }

  m_tabs.erase(m_tabs.begin() + index);

  // Switch to adjacent tab
  int new_idx = (index > 0) ? index - 1 : 0;
  m_active_idx = -1; // force refresh
  if (!m_tabs.empty())
    switch_tab(new_idx);
}

void BrowserWindow::switch_tab(int index) {
  if (index < 0 || index >= static_cast<int>(m_tabs.size()))
    return;
  m_active_idx = index;

  std::string page_name = "tab-" + std::to_string(index);
  gtk_stack_set_visible_child_name(GTK_STACK(m_stack), page_name.c_str());

  auto &tab = m_tabs[index];
  const char *uri = webkit_web_view_get_uri(WEBKIT_WEB_VIEW(tab.web_view));
  update_url_bar(uri ? uri : "");
  update_nav_buttons();

  // Update window title
  gtk_window_set_title(
      GTK_WINDOW(m_window),
      (tab.title.empty() ? "BuildBrowser" : tab.title).c_str());
}

// ─── Navigation ─────────────────────────────────────────────────────────────

void BrowserWindow::navigate(const std::string &url) {
  auto *tab = active_tab();
  if (!tab)
    return;
  std::string clean = sanitize_url(url);
  webkit_web_view_load_uri(WEBKIT_WEB_VIEW(tab->web_view), clean.c_str());
}

void BrowserWindow::go_back() {
  if (auto *t = active_tab())
    webkit_web_view_go_back(WEBKIT_WEB_VIEW(t->web_view));
}

void BrowserWindow::go_forward() {
  if (auto *t = active_tab())
    webkit_web_view_go_forward(WEBKIT_WEB_VIEW(t->web_view));
}

void BrowserWindow::reload() {
  if (auto *t = active_tab())
    webkit_web_view_reload(WEBKIT_WEB_VIEW(t->web_view));
}

void BrowserWindow::stop() {
  if (auto *t = active_tab())
    webkit_web_view_stop_loading(WEBKIT_WEB_VIEW(t->web_view));
}

// ─── WebKit signal handlers ──────────────────────────────────────────────────

void BrowserWindow::on_load_changed(WebKitWebView *wv, WebKitLoadEvent event) {
  int idx = find_tab_by_webview(wv);
  if (idx < 0)
    return;

  m_tabs[idx].loading =
      (event == WEBKIT_LOAD_STARTED || event == WEBKIT_LOAD_COMMITTED);

  if (idx == m_active_idx) {
    // Swap reload icon to stop icon while loading
    gtk_button_set_icon_name(GTK_BUTTON(m_reload_btn),
                             m_tabs[idx].loading ? "process-stop-symbolic"
                                                 : "view-refresh-symbolic");
    gtk_widget_set_visible(m_progress, m_tabs[idx].loading);
    if (!m_tabs[idx].loading)
      gtk_progress_bar_set_fraction(GTK_PROGRESS_BAR(m_progress), 0.0);
    update_nav_buttons();
  }
}

void BrowserWindow::on_title_changed(WebKitWebView *wv, const char *title) {
  int idx = find_tab_by_webview(wv);
  if (idx < 0)
    return;
  m_tabs[idx].title = title ? title : "New Tab";
  update_tab_label(idx, m_tabs[idx].title);
  if (idx == m_active_idx)
    gtk_window_set_title(GTK_WINDOW(m_window), m_tabs[idx].title.c_str());
}

void BrowserWindow::on_uri_changed(WebKitWebView *wv, const char *uri) {
  int idx = find_tab_by_webview(wv);
  if (idx < 0)
    return;
  m_tabs[idx].url = uri ? uri : "";
  if (idx == m_active_idx)
    update_url_bar(m_tabs[idx].url);
}

void BrowserWindow::on_load_progress(WebKitWebView *wv, double progress) {
  int idx = find_tab_by_webview(wv);
  if (idx == m_active_idx) {
    gtk_progress_bar_set_fraction(GTK_PROGRESS_BAR(m_progress), progress);
  }
}

// ─── Private helpers ─────────────────────────────────────────────────────────

void BrowserWindow::update_nav_buttons() {
  auto *tab = active_tab();
  if (!tab)
    return;
  auto *wv = WEBKIT_WEB_VIEW(tab->web_view);
  gtk_widget_set_sensitive(m_back_btn, webkit_web_view_can_go_back(wv));
  gtk_widget_set_sensitive(m_fwd_btn, webkit_web_view_can_go_forward(wv));
}

void BrowserWindow::update_url_bar(const std::string &url) {
  gtk_editable_set_text(GTK_EDITABLE(m_url_entry), url.c_str());
}

void BrowserWindow::update_tab_label(int index, const std::string &title) {
  if (index < 0 || index >= static_cast<int>(m_tabs.size()))
    return;
  gtk_label_set_text(GTK_LABEL(m_tabs[index].tab_label),
                     title.empty() ? "New Tab" : title.c_str());
}

int BrowserWindow::find_tab_by_webview(WebKitWebView *wv) {
  for (int i = 0; i < static_cast<int>(m_tabs.size()); ++i)
    if (m_tabs[i].web_view == GTK_WIDGET(wv))
      return i;
  return -1;
}
