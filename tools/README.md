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

They are traditional expressions, prayers and invocations used in Quebec Catholic culture.
No author is claimed: the label shown as the reference says what kind of saying it is.
They were not taken from a single published collection, so review the list in `assemble.py`
and cut or add freely. Keep every `id` permanent, because favorites are saved by id.
