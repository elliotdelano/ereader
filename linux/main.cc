#include <webview_cef/webview_cef_plugin.h>
#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

int main(int argc, char** argv) {
  // Initialize GTK.
  gtk_init(&argc, &argv);

  // Create a new Flutter application.
  initCEFProcesses(argc, argv);
  g_autoptr(MyApplication) app = my_application_new();

  // Run the application.
  int status = g_application_run(G_APPLICATION(app), argc, argv);

  return status;
} 
