# Cancionero - ChordVault

**A Flutter app for managing song notes and chords with quick transposition capabilities.**

## 🎵 Project Overview

Cancionero is a Flutter-based song management application that allows musicians to:
- Create and manage song notes with chord progressions
- Transpose chords in real-time without modifying the original text
- Organize songs in a library with search and filtering capabilities
- Export/import songs in various formats
- Share songs via text files

## 🏗️ Architecture & Tech Stack

### Core Technologies
- **Flutter 3.9.2+** - Cross-platform mobile framework
- **Riverpod 2.5.1** - State management
- **Hive 2.2.3** - Local database storage
- **Dart 3.9.2+** - Programming language

### Key Dependencies
- `flutter_riverpod` - State management
- `hive` & `hive_flutter` - Local storage
- `path_provider` - File system access
- `share_plus` - Sharing functionality
- `uuid` - Unique identifiers
- `intl` - Internationalization

## 📁 Project Structure

```
lib/
├── main.dart                    # App entry point
├── models/                      # Data models
│   ├── song.dart               # Song model with Hive adapter
│   ├── block.dart              # Song block/chunk model
│   └── note.dart               # Note model
├── providers/                   # State management
│   └── app_providers.dart      # Riverpod providers
├── screens/                     # UI screens
│   ├── home_screen.dart        # Main dashboard
│   ├── library_screen.dart     # Song library with search
│   ├── note_editor_screen.dart # Song editing interface
│   ├── song_preview_screen.dart # Song preview/display
│   └── help_screen.dart        # Help and instructions
└── services/                    # Business logic
    ├── chords/                  # Chord processing
    │   ├── chord_parser.dart   # Chord parsing logic
    │   └── chord_transposer.dart # Transposition logic
    ├── storage/                 # Data persistence
    ├── clipboard/              # Clipboard operations
    └── io/                     # File I/O operations
```

## 🎯 Core Features

### 1. Song Management
- **Create/Edit Songs**: Rich text editor with chord support
- **Library Organization**: Search, filter, and categorize songs
- **Favorites System**: Mark songs as favorites
- **Metadata Support**: Author, tags, original key, timestamps

### 2. Chord Processing
- **Real-time Transposition**: Transpose chords without modifying original text
- **Chord Recognition**: Automatic chord detection and parsing
- **Key Management**: Support for all major and minor keys
- **Visual Indicators**: Clear chord highlighting and formatting

### 3. Data Persistence
- **Local Storage**: Hive database for offline access
- **Import/Export**: JSON format for data portability
- **Backup/Restore**: Complete data backup capabilities
- **Cross-platform**: Works on Android, iOS, Windows, macOS, Linux

### 4. User Experience
- **Dark Theme**: Modern dark UI with Material 3 design
- **Responsive Design**: Adapts to different screen sizes
- **Search & Filter**: Quick song discovery
- **Sharing**: Export songs as text files

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.9.2 or higher
- Dart SDK 3.9.2 or higher
- Android Studio / VS Code with Flutter extensions

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd cancionero
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run tests**
   ```bash
   flutter test
   ```

4. **Launch the app**
   ```bash
   flutter run
   ```

### Platform-specific Setup

#### Windows (PowerShell)
```powershell
# Add Flutter to PATH if not already done
$env:Path += ";C:\Users\salvi\flutter\bin"
```

#### Android
- Ensure Android SDK is installed
- Enable USB debugging for physical devices
- Or use Android emulator

#### iOS (macOS only)
- Xcode and iOS SDK required
- iOS Simulator or physical device

## 🎼 Data Models

### Song Model
```dart
class Song {
  final String id;
  String title;
  final List<Block> blocks;
  final String? originalKey;
  final List<String> tags;
  final String? author;
  bool isFavorite;
  DateTime createdAt;
  DateTime updatedAt;
}
```

### Block Model
```dart
class Block {
  final String id;
  String content;
  final BlockType type;
  int transposition;
  // ... other properties
}
```

## 🔧 Development Guidelines

### State Management
- Uses **Riverpod** for state management
- Providers are defined in `lib/providers/app_providers.dart`
- Follow the provider pattern for data access

### Database Operations
- **Hive** is used for local storage
- Models have corresponding adapters for serialization
- Database initialization in `lib/services/storage/hive_service.dart`

### UI/UX Patterns
- **Material 3** design system
- Dark theme by default
- Responsive layouts for different screen sizes
- Consistent navigation patterns

### Code Organization
- **Feature-based structure**: Group related functionality
- **Service layer**: Business logic separated from UI
- **Model layer**: Data structures with Hive adapters
- **Provider layer**: State management and data access

## 🧪 Testing

The project includes comprehensive tests:
- **Unit tests**: Business logic and utilities
- **Widget tests**: UI component testing
- **Integration tests**: End-to-end functionality

Run tests with:
```bash
flutter test
```

## 📱 Supported Platforms

- ✅ **Android** (API 21+)
- ✅ **iOS** (iOS 11+)
- ✅ **Windows** (Windows 10+)
- ✅ **macOS** (macOS 10.14+)
- ✅ **Linux** (Ubuntu 18.04+)
- ✅ **Web** (Chrome, Firefox, Safari)

## 🔄 Data Flow

1. **User Input** → UI Components
2. **UI Events** → Riverpod Providers
3. **Providers** → Service Layer
4. **Services** → Hive Database
5. **Database** → Model Updates
6. **Model Changes** → UI Rebuild

## 🎵 Key User Flows

### Creating a New Song
1. Tap "+" button on home screen
2. Enter song title and metadata
3. Add blocks (verses, chorus, bridge)
4. Add chords and lyrics
5. Save to library

### Transposing
1. Select song from library
2. Choose block to edit
3. Use transposition controls (-, +, Reset)
4. Preview changes in real-time
5. Apply changes permanently

### Library Management
1. Browse songs in library
2. Use search to find specific songs
3. Filter by tags, author, or favorites
4. Edit, delete, or share songs

## 🚀 Future Enhancements

### Planned Features
- **Capo Support**: Visual capo indicators
- **Chord Diagrams**: Visual chord representations
- **Setlist Management**: Organize songs for performances
- **Cloud Sync**: Backup to cloud services
- **Collaboration**: Share songs with other users
- **Advanced Search**: Full-text search in lyrics
- **Export Formats**: PDF, MIDI, and other formats

### Technical Improvements
- **Performance**: Optimize large song libraries
- **Offline Sync**: Better conflict resolution
- **Accessibility**: Screen reader support
- **Internationalization**: Multi-language support

## 🐛 Troubleshooting

### Common Issues

1. **Flutter not found**
   - Ensure Flutter is in your PATH
   - Run `flutter doctor` to check setup

2. **Build failures**
   - Clean build: `flutter clean && flutter pub get`
   - Check dependencies: `flutter pub deps`

3. **Database issues**
   - Clear app data and restart
   - Check Hive initialization

4. **Platform-specific issues**
   - Android: Check SDK version and permissions
   - iOS: Verify signing and provisioning
   - Windows: Ensure Visual Studio tools installed

## 📄 License

This project is private and not intended for public distribution.

## 🤝 Contributing

This is a personal project. For collaboration or questions, contact the repository owner.

## 📞 Support

For technical support or feature requests, please create an issue in the repository or contact the development team.

---

**Note for AI Assistants**: This project uses Flutter with Riverpod for state management, Hive for local storage, and follows Material 3 design principles. The codebase is well-structured with clear separation of concerns between UI, business logic, and data layers. When making changes, ensure compatibility with the existing architecture and maintain the established patterns.