# LinuxDex

A Flutter web application for tracking Ubuntu distribution history with Supabase backend.

## Project Structure
- `app/`: Flutter application source code
- `website/`: Vercel deployment files (built web app and serverless functions)

## Setup Instructions

### Prerequisites
- Flutter SDK installed
- Supabase account
- Vercel account (for deployment)

### Supabase Setup
1. Create a new Supabase project at https://supabase.com
2. Go to Settings > API to get your Project URL and anon public key
3. Run the SQL script in `database/schema.sql` in your Supabase SQL editor to create the database schema with proper RLS policies

### Local Development
1. Navigate to the `app/` directory
2. Update `.env` file with your Supabase credentials:
   ```
   SUPABASE_URL=your_supabase_project_url
   SUPABASE_ANON_KEY=your_supabase_anon_key
   ```
3. Run `flutter pub get` to install dependencies
4. Run `flutter run` for local development (or `flutter run -d chrome` for web)

### Deployment to Vercel
1. Push the code to a Git repository (GitHub, GitLab, etc.)
2. Connect the `website/` directory as the Vercel project root
3. Set environment variables in Vercel dashboard:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
4. Deploy

The app will be available at `your-vercel-domain.vercel.app`

User profiles can be accessed at `your-vercel-domain.vercel.app/username` (where username is the user's email)

### Features
- User authentication (sign up, log in)
- Profile creation/editing with Ubuntu distro history
- Chronological display of distro history
- Public profile pages
- Responsive web UI

### Security Notes
- Environment variables are securely handled
- Input sanitization is implemented in the app
- Supabase handles authentication and data security