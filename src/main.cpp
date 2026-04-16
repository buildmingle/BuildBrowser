#include <gtk/gtk.h>
#include <filesystem>
#include "browser_window.h"

// Load our custom stylesheet from the same directory as the binary
static void load_css() {
    auto* provider = gtk_css_provider_new();

    // Try to find style.css next to the executable
    std::filesystem::path exe_dir;
    char buf[4096] = {};
    ssize_t len = readlink("/proc/self/exe", buf, sizeof(buf) - 1);
    if (len > 0) {
        exe_dir = std::filesystem::path(buf).parent_path();
    } else {
        exe_dir = std::filesystem::current_path();
    }

    auto css_path = exe_dir / "style.css";
    if (std::filesystem::exists(css_path)) {
        gtk_css_provider_load_from_path(provider, css_path.c_str());
    } else {
        // Fallback: minimal inline CSS so the app still looks decent
        gtk_css_provider_load_from_string(provider,
            ".tab-button { border-radius: 6px 6px 0 0; padding: 4px 8px; }"
            ".tab-button:checked { background: @window_bg_color; }"
            "progressbar > trough > progress { background: @accent_color; min-height: 3px; }"
        );
    }

    gtk_style_context_add_provider_for_display(
        gdk_display_get_default(),
        GTK_STYLE_PROVIDER(provider),
        GTK_STYLE_PROVIDER_PRIORITY_APPLICATION
    );
    g_object_unref(provider);
}

int main(int argc, char* argv[]) {
    auto* app = gtk_application_new("io.kiro.browser", G_APPLICATION_DEFAULT_FLAGS);

    g_signal_connect(app, "activate", G_CALLBACK(+[](GtkApplication* app, gpointer) {
        load_css();
        auto* bw = new BrowserWindow(app);
        gtk_widget_present(bw->root_widget());
    }), nullptr);

    int status = g_application_run(G_APPLICATION(app), argc, argv);
    g_object_unref(app);
    return status;
}
