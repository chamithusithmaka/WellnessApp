# Serenity — AI Mental Wellness Companion

A cross-platform Flutter app that provides 24/7 emotional support through an AI-powered chatbot, real-time mood tracking, guided journaling, and relaxation audio.

---

## Features

- **AI Chatbot (Serenity)** — Warm, empathetic conversations powered by Google Gemini 2.5 Flash with OpenRouter (GPT-4o-mini) as a fallback. The chatbot practices reflective listening, validates emotions, and suggests evidence-based coping techniques such as box breathing, the 5-4-3-2-1 grounding method, and mindfulness.
- **Smart Mood Detection** — A custom on-device sentiment analysis engine (pure Dart) scans conversation text for emotional keywords across categories including joy, calm, gratitude, sadness, anxiety, stress, anger, and distress. It applies negation detection and calculates a weighted mood score from 1–10 with no external ML library.
- **Mood Tracking & Trends** — Conversations automatically generate mood data points. Interactive charts (fl_chart) visualise emotional patterns over time.
- **Guided Journaling** — Private journal entries stored locally and synced to Firebase Firestore.
- **Relaxation Audio** — Built-in calming audio tracks for guided breathing and relaxation sessions using just_audio.
- **Offline Mode** — A rule-based keyword response engine keeps the app helpful and empathetic without an internet connection.
- **Crisis Safety** — Detects crisis-related language and immediately surfaces the 988 Suicide & Crisis Lifeline, Crisis Text Line, and a dedicated Help screen with one-tap phone dialling.
- **Secure Authentication** — Google Sign-In and Firebase Authentication with cloud (Firestore) and local (SQLite) storage.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart) — Android, iOS, Web, Desktop |
| AI / Chatbot | Google Gemini 2.5 Flash API, OpenRouter (GPT-4o-mini) |
| Sentiment Analysis | Custom keyword-based NLP engine (Dart, on-device) |
| Backend / Auth | Firebase Authentication, Cloud Firestore |
| Local Storage | SQLite (sqflite) |
| Offline Mode | Rule-based keyword response engine |
| Charts | fl_chart |
| Audio | just_audio, audio_session |
| Connectivity | connectivity_plus |

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart SDK `^3.8.1`)
- A Firebase project with Authentication and Firestore enabled
- A Google Gemini API key
- An OpenRouter API key (optional fallback)

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/ai_wellness_app.git
   cd ai_wellness_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure environment variables**

   Create a `.env` file in the project root:
   ```env
   GEMINI_API_KEY=your_gemini_api_key_here
   OPENROUTER_API_KEY=your_openrouter_api_key_here
   ```

4. **Firebase setup**

   - Add your `google-services.json` to `android/app/`
   - Add your `GoogleService-Info.plist` to `ios/Runner/`
   - Update `lib/firebase_options.dart` with your Firebase project config

5. **Run the app**
   ```bash
   flutter run
   ```

---

## Project Structure

```
lib/
├── main.dart
├── firebase_options.dart
├── models/
│   ├── chat_message.dart
│   ├── mood_entry.dart
│   └── journal_entry.dart
├── services/
│   ├── gemini_service.dart          # Google Gemini AI integration
│   ├── openrouter_service.dart      # OpenRouter fallback AI
│   ├── mood_service.dart            # On-device sentiment analysis engine
│   ├── offline_response_service.dart # Offline keyword response engine
│   ├── auth_service.dart            # Firebase Authentication
│   ├── firestore_service.dart       # Cloud Firestore sync
│   ├── database_service.dart        # Local SQLite storage
│   └── connectivity_service.dart    # Network status monitoring
└── screens/
    ├── auth/                        # Login & sign-up
    ├── home/                        # Main navigation
    ├── chat/                        # AI chatbot
    ├── mood/                        # Mood tracking & charts
    ├── journal/                     # Guided journaling
    ├── relax/                       # Relaxation audio
    └── help/                        # Crisis resources
```

---

## How Mood Analysis Works

The app does **not** use any external ML framework. Mood detection is handled by a fully on-device custom engine in `mood_service.dart`:

1. User messages are scanned against categorised keyword lists (e.g., `['sad', 'lonely', 'crying']` → `sad`).
2. Negation detection reverses sentiment where phrases like "not happy" appear.
3. Each detected emotion is assigned a numeric score weight (e.g., `distressed: 1.5`, `calm: 7.0`, `excellent: 10.0`).
4. A weighted average produces a final mood score from **1–10**, which is stored and visualised over time.

---

## Safety & Disclaimer

Serenity is **not** a replacement for professional mental health care. The app encourages users to seek professional help when appropriate and immediately surfaces crisis resources when distress signals are detected.

---

## License

This project is for educational and portfolio purposes.
