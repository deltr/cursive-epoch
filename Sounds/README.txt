Cursive — Custom Sound Files
=============================

The "Custom Alert 1/2/3" entries in the sound dropdown look for these files:

    Sounds/alert1.ogg
    Sounds/alert2.ogg
    Sounds/alert3.ogg

The addon does not ship with audio. Drop your own .ogg files into this
folder, named exactly as above, then restart the game (or /reload). Use
the "Test Sound" button in the Cursive options panel to verify.

Notes:
- WoW 3.3.5a supports .ogg (Vorbis) and .mp3 via PlaySoundFile. .ogg is
  the most reliable choice. Keep clips short (< 2s).
- File paths are case-insensitive on Windows but case-sensitive on Linux/Mac
  WoW clients. Stick to lowercase filenames as listed above.
- If a file is missing, the test button will appear silent — no error is
  shown. (3.3.5a's PlaySoundFile fails quietly.)

Free sources for short alert clips:
- freesound.org  (filter for CC0)
- mixkit.co/free-sound-effects
- pixabay.com/sound-effects
