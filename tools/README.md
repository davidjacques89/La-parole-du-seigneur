# Library tools

`LaParoleDuSeigneur/Sayings.lua` is generated, so every Bible verse is cut from a
public-domain text instead of typed by hand.

- `build_sayings.py` lists the verses (`SPEC`) and how each is trimmed. The build fails if a
  trimmed phrase is not found word for word in the source.
- `assemble.py` adds the Québec sayings (`QUEBEC`) and writes `Sayings.lua`.
- `verses.py` prints the raw French and English text for references, to choose trims.

## Regenerate

Put the source texts under `tools/data/` (or set `BIBLE_DATA`):

```
tools/data/midvash/versions/fr/lsg/lsg.json          github.com/midvash/bible-data (Louis Segond 1910)
tools/data/midvash/versions/en/kjv/kjv.json          github.com/midvash/bible-data (KJV)
tools/data/scrollmapper/formats/json/KJV.json        github.com/scrollmapper/bible_databases (KJV)
```

Then, from the repo root:

```
python3 tools/assemble.py && lua5.1 tests/run.lua
```

The `tools/data` folder is not committed.

## Notes on the Québec sayings

They are traditional expressions, prayers and dictons used in Quebec Catholic culture.
No author is claimed: the label shown as the reference says what kind of saying it is.

Where they come from:
- The prayers (Notre Père, Je vous salue Marie, Souvenez-vous, Angélus, Credo, Bénédicité, offrande du matin)
  use older wordings found in public-domain French and Quebec prayer books and on Catholic sites.
  Modern Quebec liturgical translations are copyrighted and are not used.
- "Eau bénite, je te prends..." is documented as a Quebec bedtime prayer in *Cap-aux-Diamants* (1994).
- The weather dictons ("Dicton météo") are traditional French sayings shared with the rest of the French-speaking
  world; they are not specific to Quebec.
- The first 24 (everyday sayings, short prayers and invocations) were written from general knowledge of Quebec
  Catholic culture and have not been matched against a printed collection.

Review the list in `assemble.py` and cut or add freely. Keep every `id` permanent, because favorites are saved by id.
