# WrapUp AI / AI Meeting Analyzer

WrapUp AI is an AI meeting analyzer for recording, transcribing, summarizing, and searching meetings across web, desktop, backend, and mobile surfaces.

## Features

- Meeting upload, live recording, and session processing
- AI transcription and speaker diarization
- Meeting summaries, action items, analytics, and chat over meeting context
- Supabase authentication, database storage, sharing, migrations, and edge functions
- Stripe subscription flows
- Electron desktop runtime and Flutter mobile app structure

## Tech Stack

- React, Vite, TypeScript, Tailwind CSS, shadcn/ui
- Electron
- Python FastAPI backend
- Supabase
- Flutter
- Groq, Deepgram, pyannote, and related AI services
- Stripe

## Setup

Install frontend dependencies:

```bash
npm install
```

Create local environment files from the templates:

```bash
cp .env.example .env
cp backend/.env.example backend/.env
cp mobile/.env.example mobile/.env
```

Fill the copied `.env` files with your own credentials. Real `.env` files are ignored and must not be committed.

Install backend dependencies:

```bash
python -m venv .venv
.venv/Scripts/pip install -r requirements.txt
```

On macOS/Linux:

```bash
python -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
```

## Run Locally

Frontend:

```bash
npm run dev
```

Backend:

```bash
npm run dev:backend
```

Electron:

```bash
npm run dev:electron
```

Tests:

```bash
npm test
```

Flutter mobile:

```bash
cd mobile
flutter pub get
flutter run
```

## Security

Do not commit real `.env` files, API keys, service-role keys, private keys, service-account JSON files, local database files, logs, generated media, model artifacts, dependency folders, or build outputs.

Use `.env.example`, `backend/.env.example`, and `mobile/.env.example` as safe templates for local and deployment configuration.
