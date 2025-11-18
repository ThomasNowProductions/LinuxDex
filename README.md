# LinuxDex

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com/)

A cross-platform Flutter application for tracking and sharing your Linux distribution journey. Keep a chronological history of the Ubuntu distributions you've used, create public profiles, and explore others' Linux experiences.

## Features

- 🔐 User authentication with Supabase
- 📊 Track your Ubuntu distro history chronologically
- 🌐 Public and private profiles
- 📱 Cross-platform support (Android, iOS, Web, Desktop)
- 🎨 Terminal-inspired dark theme
- 🔍 View other users' public profiles

## Project Structure
- `lib/`: Flutter application source code
- `android/`: Android platform-specific code and configuration
- `ios/`: iOS platform-specific code and configuration
- `web/`: Web platform-specific code and assets
- `linux/`: Linux platform-specific code
- `macos/`: macOS platform-specific code
- `windows/`: Windows platform-specific code
- `database/`: Database schema and SQL scripts
- `test/`: Unit and widget tests

## Setup Instructions

### Prerequisites
- Flutter SDK installed (see [official installation guide](https://flutter.dev/docs/get-started/install))
- Supabase account (sign up at [supabase.com](https://supabase.com))
- Hosting account (optional, for web deployment - Vercel, Netlify, etc.)

### Supabase Setup
1. Create a new Supabase project at https://supabase.com
2. Go to Settings > API to get your Project URL and anon public key
3. Run the SQL script in `database/schema.sql` in your Supabase SQL editor to create the database schema with proper RLS policies

### Local Development
1. Clone the repository
2. Create a `.env` file in the root directory with your Supabase credentials:
   ```
   SUPABASE_URL=your_supabase_project_url
   SUPABASE_ANON_KEY=your_supabase_anon_key
   ```
3. Run `flutter pub get` to install dependencies
4. Run `flutter run` for local development (specify platform with `-d` flag, e.g., `flutter run -d chrome` for web)

The app will be available at your deployment URL.

User profiles can be accessed at `your-deployment-url/username` (where username is the user's email)

## Screenshots

*Add screenshots of the app here*

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the GNU General Public License version 3 license.

## Security Notes
- Environment variables are securely handled
- Input sanitization is implemented in the app
- Supabase handles authentication and data security