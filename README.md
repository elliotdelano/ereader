# EReader

A versatile ebook reader application built with Flutter, supporting the EPUB format with more to come.

<!-- ![Library Screen Light Theme](./docs/images/library_light.png) -->
<!-- ![Library Screen Dark Theme](./docs/images/library_dark.png) -->
<!-- ![Reader Screen Sepia Theme](./docs/images/reader_sepia.png) -->

## Features

This application aims to provide a robust reading experience with the following features:

**Library Management:**

-   **EPUB & PDF Support:** Read books in both EPUB and PDF formats.
-   **Directory Browsing:** Select a directory on your device to load books from.
-   **Book List:** Displays loaded books with covers (if available), titles, and authors.
-   **Currently Reading Section:** A dedicated, visually distinct panel at the top of the library prioritizes books you're currently reading.
    -   Books are automatically marked as "Currently Reading" when opened.
    -   Status can be manually toggled via the book edit options.
-   **Search:** Filter your library based on title or author using an integrated search delegate.
-   **Sorting:** Sort the library list by title, author, or recently opened.
-   **Metadata Editing:** Modify book title and author information.
-   **Persistence:** Remembers the last opened directory and user settings.

**EPUB Reader:**

-   **Custom Viewer:** Utilizes a custom webview-based viewer (`webview_flutter`) powered by `Epub.js`.
-   **Theme Customization:** Switch between Light, Dark, and Sepia reading themes, consistent across the app and reader view.
-   **Font Customization:** Adjust font family and font size for optimal readability.
-   **Pagination & Navigation:**
    -   Turn pages using tap zones (left/right edges) or horizontal swipe gestures.
    -   Navigate quickly using a progress slider.
-   **Table of Contents:** Access and navigate the book using its internal Table of Contents.
-   **Progress Saving:**
    -   Automatically saves reading progress (CFI location and percentage).
    -   Loads the last reading position when a book is reopened.
-   **Immersive Mode:** Tapping the center of the screen toggles the visibility of the AppBar and progress slider for a distraction-free reading experience.

## Core Technologies

-   **Flutter:** Cross-platform UI framework.
-   **Dart:** Programming language.
-   **`epubx`:** Parsing EPUB metadata.
-   **`Epub.js`:** JavaScript library for rendering EPUB content within the webview.

## Getting Started

This project is a standard Flutter application.

1.  **Clone the repository:**
    ```bash
    git clone <repository-url>
    cd ereader
    ```
2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```
3.  **Run the application:**
    ```bash
    flutter run
    ```

**Note:** Ensure you have the Flutter SDK installed and configured for your target platform(s). Depending on the platform, you might need additional setup for `webview_flutter` or file system permissions. Refer to the respective package documentation for details.

<!-- ## Contributing

Contributions are welcome! Please feel free to open an issue or submit a pull request. -->

<!-- ## License

This project is licensed under the [MIT License](./LICENSE). -->
