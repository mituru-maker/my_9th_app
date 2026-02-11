# Kitchen Eco AI

AI-powered recipe generator using ingredients you have at home. Built with Flutter and Google Gemini AI.

## Features

- 🍳 Generate recipes from ingredients you have
- 📸 Upload images of ingredients for AI recognition
- 🔧 Configurable Gemini API models
- 📱 Responsive web design
- 🎨 Beautiful Material Design UI

## Getting Started

### Prerequisites

- Flutter SDK
- Google Gemini API Key (get one from [Google AI Studio](https://aistudio.google.com/app/apikey))

### Local Development

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run -d chrome
   ```
4. Configure your API key in the app settings

### Deployment to GitHub Pages

#### Manual Deployment

1. Activate peanut globally:
   ```bash
   dart pub global activate peanut
   ```
2. Build and deploy:
   ```bash
   dart pub global run peanut --extra-args "--base-href /my_9th_app/"
   ```
3. Deploy the `build/web` folder to your GitHub Pages

#### Automatic Deployment

The repository includes GitHub Actions workflow for automatic deployment. When you push to the main branch, the app will be automatically built and deployed to GitHub Pages.

## Configuration

The app uses Google Gemini AI for recipe generation. You'll need an API key from Google AI Studio.

Available models:
- `gemini-3-flash-preview` (default)
- `gemini-1.5-flash` (stable)
- `gemini-2.0-flash-exp` (experimental)

## Technology Stack

- **Frontend**: Flutter
- **AI**: Google Generative AI
- **Storage**: SharedPreferences
- **UI**: Material Design 3
- **Deployment**: GitHub Pages

## License

This project is licensed under the MIT License.
