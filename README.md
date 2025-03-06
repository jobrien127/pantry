# Pantry

A modern iOS app for smart pantry management, helping you track your groceries, manage expiration dates, and receive intelligent suggestions based on your purchasing habits.

## Features

- **Item Tracking**: Keep track of all items in your pantry with details like name, quantity, and expiration dates
- **Smart Notifications**: Receive timely notifications about items nearing expiration
- **Purchase History**: Track your purchasing patterns to help with future shopping decisions
- **Intelligent Suggestions**: Get personalized suggestions based on your usage patterns and purchase history
- **Modern SwiftUI Interface**: Clean, intuitive interface built with SwiftUI and SwiftData

## Technologies Used

- **SwiftUI**: For building the modern, responsive user interface
- **SwiftData**: For persistent data storage and management
- **Combine**: For reactive programming and handling asynchronous events
- **UserNotifications**: For managing expiration alerts

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/Pantry.git
```

2. Open `Pantry.xcodeproj` in Xcode

3. Build and run the project (⌘+R)

## Architecture

The app follows the MVVM (Model-View-ViewModel) architecture:

- **Models**: `Item` - Represents pantry items with SwiftData persistence
- **Views**: `ContentView`, `AddItemView`, `ItemDetailView` - UI components
- **ViewModel**: `PantryViewModel` - Business logic and data management

## Features in Detail

### Item Management
- Add new items with name, quantity, and expiration date
- Track purchase history and usage patterns
- Update item details and quantities
- Remove items when consumed or disposed

### Smart Notifications
- Automatic notifications for items nearing expiration
- Customizable notification preferences
- Background updates for timely alerts

### Intelligent Suggestions
- Purchase recommendations based on usage patterns
- Restocking suggestions for frequently used items
- Smart inventory management

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Built with SwiftUI and SwiftData
- Inspired by the need for smart pantry management
- Thanks to all contributors and users

## Contact

For any questions or feedback, please open an issue in the repository.
