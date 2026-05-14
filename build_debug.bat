@echo off
REM ===================================================================
REM CuniGest - Lancement DEBUG (téléphone branché en USB)
REM ===================================================================
REM Usage : double-clique sur ce fichier OU lance-le depuis cmd
REM Branche le téléphone en USB avec le mode développeur activé.
REM ===================================================================

set SUPABASE_URL=https://psqjcgdzauwsdplxgdjn.supabase.co
set SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBzcWpjZ2R6YXV3c2RwbHhnZGpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc1MzAxMDIsImV4cCI6MjA5MzEwNjEwMn0.Hpcp_5eWgLbrNKzbefQ2AexLk8G_n-EOM5AlXdv68IM
set SENTRY_DSN=https://d4e8b89b6099612275981b3aec48ff89@o4511347316359168.ingest.de.sentry.io/4511347322126416

flutter run ^
  --dart-define=SUPABASE_URL=%SUPABASE_URL% ^
  --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY% ^
  --dart-define=SENTRY_DSN=%SENTRY_DSN% ^
  --dart-define=SENTRY_ENV=debug
