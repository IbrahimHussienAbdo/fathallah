# Fathallah Gomla Market - Data Analytics App

A cross-platform (mobile & web) Flutter application designed for Fathallah Gomla Market to perform internal data processing and business analytics. The app provides insights into sales, inventory, and profitability by parsing and analyzing uploaded purchase and sales data.

## 🚀 Live Demo & Previews

-   **Web App:** [Link to your deployed web app]
-   **Mobile Demo:** A video showcasing the mobile app's functionality can be found in the `/assets/mobile_demo` directory.

### Web Application Preview

| Upload Screen                                          | Search & View                                       | Analytics Dashboard                                           | Dead Stock Report                                        |
| ------------------------------------------------------ | --------------------------------------------------- | ------------------------------------------------------------- | -------------------------------------------------------- |
| ![](/assets/web_screens/upload_screen.png) | ![](/assets/web_screens/search.png) | ![](/assets/web_screens/analytics_screen.png) | ![](/assets/web_screens/dead_stock.png) |

## ✨ Features

-   **Cross-Platform:** Single codebase for Android, iOS, and Web.
-   **File Upload:** Upload business data seamlessly using `.csv` or `.xlsx` (Excel) files.
-   **Persistent Storage:** Uses SQLite to store and manage the data locally, with `sqflite` for mobile and `sqflite_common_ffi_web` for the web version.
-   **Data Analysis & Insights:**
    -   **Top N Items:** Identify the best-performing items by sales volume.
    -   **Dead Stock Identification:** Pinpoint items that have been purchased but never sold.
    -   **Profit Reporting:** Calculate and view profit margins for each item.
    -   **Advanced Search:** Quickly find any item by name to see its details.
-   **Interactive UI:** Clean, intuitive, and responsive user interface built with Flutter.

## 🏗️ Technical Architecture

The project follows a clean, layered architecture to ensure separation of concerns, scalability, and maintainability.

```
┌───────────────────┐
│  Presentation     │ (UI Widgets, Screens, State Management)
└─────────┬─────────┘
          │
┌─────────▼─────────┐
│      Domain       │ (Business Logic, Usecases, Entities)
└─────────┬─────────┘
          │
┌─────────▼─────────┐
│       Data        │ (Repositories, Data Sources, Database)
└───────────────────┘
```

-   **Presentation Layer:**
    -   Contains all the UI elements (Widgets, Screens).
    -   Manages the application's state using the `provider` package.
    -   Responds to user input and displays data from the domain layer.

-   **Domain Layer:**
    -   The core of the application, containing the business logic.
    -   `Entities`: Defines the data models (e.g., `Item`).
    -   `Repositories`: Abstract interfaces for data operations.
    -   `Usecases`: Encapsulates specific business rules (e.g., `GetTopNItems`).

-   **Data Layer:**
    -   Implements the repository interfaces defined in the domain layer.
    -   `Data Sources`: Handles the actual data operations, such as interacting with the SQLite database (`AppDatabase`) or parsing files (`FileParser`).
    -   Manages the local SQLite database via `sqflite` (mobile) and `sqflite_common_ffi_web` (web).

## 🗂️ Project Structure

The `lib` directory is organized by feature and layer, promoting modularity and making the codebase easy to navigate.

```
lib
├── data
│   ├── datasources
│   │   ├── app_database.dart
│   │   └── file_parser.dart
│   └── repositories
│       └── item_repository_impl.dart
├── domain
│   ├── entities
│   │   └── item.dart
│   ├── repositories
│   │   └── item_repository.dart
│   └── usecases
│       └── item_usecases.dart
├── presentation
│   ├── providers
│   │   └── app_provider.dart
│   ├── screens
│   │   ├── analytics_screen.dart
│   │   ├── search_screen.dart
│   │   └── upload_screen.dart
│   ├── theme
│   │   └── app_theme.dart
│   └── widgets
│       └── common_widgets.dart
└── main.dart
```

## 🛠️ Key Technologies & Packages

-   **UI Framework:** [Flutter](https://flutter.dev/)
-   **State Management:** [provider](https://pub.dev/packages/provider)
-   **Database:**
    -   [sqflite](https://pub.dev/packages/sqflite) (for Mobile/Desktop)
    -   [sqflite_common_ffi_web](https://pub.dev/packages/sqflite_common_ffi_web) (for Web)
-   **File Handling:**
    -   [file_picker](https://pub.dev/packages/file_picker)
    -   [csv](https://pub.dev/packages/csv)
    -   [excel](https://pub.dev/packages/excel)
-   **Charting:** [fl_chart](https://pub.dev/packages/fl_chart)
-   **Utilities:**
    -   [intl](https://pub.dev/packages/intl) for formatting.
    -   [path_provider](https://pub.dev/packages/path_provider) & [path](https://pub.dev/packages/path) for managing file paths.

## 🚀 Getting Started

1.  **Clone the repository:**
    ```bash
    git clone <your-repo-url>
    cd fathallah_analysis
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Run the application:**
    -   **For Mobile (Android/iOS):**
        ```bash
        flutter run
        ```
    -   **For Web:**
        ```bash
        flutter run -d chrome
        ```

---
This project was developed as part of a technical assignment and demonstrates a strong understanding of Flutter, data management, and software architecture principles.
