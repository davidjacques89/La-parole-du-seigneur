"""Build the Bible part of Sayings.lua from public-domain sources, so no verse is typed by hand.

Each entry: (id, category, book, chapter, verse, fr_trim, en_trim)
A trim is None (whole verse) or (start_phrase, end_phrase); end_phrase None = to the end.
The extracted span must exist verbatim in the source, or the build fails.
Only cosmetic edits are applied afterwards: capital first letter, final punctuation,
curly apostrophes to straight ones.
"""
import json
import re
import sys

import os  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from verses import DATA, load_lsg, load_kjv, KJV_NAMES  # noqa: E402

KJV2 = os.path.join(DATA, "midvash", "versions", "en", "kjv", "kjv.json")

SPEC = [
    # --- Words of Jesus (Gospels + Acts 20:35) ---
    ("jn3_16", "jesus", "John", 3, 16, None, None),
    ("mt4_4", "jesus", "Matt", 4, 4, ("L'homme ne vivra", None), ("Man shall not live", None)),
    ("mt5_3", "jesus", "Matt", 5, 3, None, None),
    ("mt5_5", "jesus", "Matt", 5, 5, None, None),
    ("mt5_7", "jesus", "Matt", 5, 7, None, None),
    ("mt5_8", "jesus", "Matt", 5, 8, None, None),
    ("mt5_9", "jesus", "Matt", 5, 9, None, None),
    ("mt5_14", "jesus", "Matt", 5, 14, None, None),
    ("mt5_16", "jesus", "Matt", 5, 16, None, None),
    ("mt5_44", "jesus", "Matt", 5, 44, ("Aimez vos ennemis", None), ("Love your enemies", None)),
    ("mt6_21", "jesus", "Matt", 6, 21, None, None),
    ("mt6_24", "jesus", "Matt", 6, 24, None, None),
    ("mt6_34", "jesus", "Matt", 6, 34, None, None),
    ("mt7_1", "jesus", "Matt", 7, 1, None, None),
    ("mt7_3", "jesus", "Matt", 7, 3, None, ("why beholdest", None)),
    ("mt7_7", "jesus", "Matt", 7, 7, None, None),
    ("mt7_12", "jesus", "Matt", 7, 12, None, ("all things whatsoever", None)),
    ("mt7_20", "jesus", "Matt", 7, 20, None, ("by their fruits", None)),
    ("mt11_28", "jesus", "Matt", 11, 28, None, None),
    ("mt18_20", "jesus", "Matt", 18, 20, None, None),
    ("mt19_24", "jesus", "Matt", 19, 24, ("il est plus facile", None), ("It is easier", None)),
    ("mt20_16", "jesus", "Matt", 20, 16, None, ("So the last", "the first last")),
    ("mt22_39", "jesus", "Matt", 22, 39, ("Tu aimeras", None), ("Thou shalt love", None)),
    ("mt26_41", "jesus", "Matt", 26, 41, ("l'esprit est bien disposé", None), ("the spirit indeed", None)),
    ("mt26_52", "jesus", "Matt", 26, 52, ("Remets ton épée", None), ("Put up again", None)),
    ("mt28_20", "jesus", "Matt", 28, 20, ("je suis avec vous", None), ("I am with you", "end of the world")),
    ("mk2_27", "jesus", "Mark", 2, 27, ("Le sabbat", "pour le sabbat"), ("The sabbath", "for the sabbath")),
    ("mk9_23", "jesus", "Mark", 9, 23, ("Tout est possible", None), ("all things are possible", None)),
    ("mk12_17", "jesus", "Mark", 12, 17, ("Rendez à César", "ce qui est à Dieu"), ("Render to Caesar", "that are God's")),
    ("lk6_37", "jesus", "Luke", 6, 37, None, None),
    ("lk6_38", "jesus", "Luke", 6, 38, ("Donnez, et il vous sera donné", "il vous sera donné"), ("Give, and it shall be given unto you", "given unto you")),
    ("lk15_7", "jesus", "Luke", 15, 7, ("il y aura plus de joie", None), ("joy shall be in heaven", None)),
    ("lk23_34", "jesus", "Luke", 23, 34, ("Père, pardonne-leur", "ce qu'ils font"), ("Father, forgive them", "what they do")),
    ("jn6_35", "jesus", "John", 6, 35, ("Je suis le pain de vie", None), ("I am the bread of life", None)),
    ("jn8_7", "jesus", "John", 8, 7, ("Que celui de vous", "la pierre"), ("He that is without sin", "cast a stone")),
    ("jn8_12", "jesus", "John", 8, 12, ("Je suis la lumière du monde", None), ("I am the light of the world", None)),
    ("jn8_32", "jesus", "John", 8, 32, None, None),
    ("jn10_11", "jesus", "John", 10, 11, None, None),
    ("jn11_25", "jesus", "John", 11, 25, ("Je suis la résurrection", None), ("I am the resurrection", None)),
    ("jn13_34", "jesus", "John", 13, 34, None, None),
    ("jn14_6", "jesus", "John", 14, 6, ("Je suis le chemin", None), ("I am the way", None)),
    ("jn14_27", "jesus", "John", 14, 27, None, None),
    ("jn15_13", "jesus", "John", 15, 13, None, None),
    ("jn16_33", "jesus", "John", 16, 33, ("Vous aurez des tribulations", None), ("In the world ye shall have", None)),
    ("ac20_35", "jesus", "Acts", 20, 35, ("Il y a plus de bonheur", None), ("It is more blessed", None)),
    # --- Proverbs ---
    ("pr3_5", "proverbs", "Prov", 3, 5, None, None),
    ("pr6_6", "proverbs", "Prov", 6, 6, None, None),
    ("pr10_12", "proverbs", "Prov", 10, 12, None, None),
    ("pr13_20", "proverbs", "Prov", 13, 20, None, None),
    ("pr15_1", "proverbs", "Prov", 15, 1, None, None),
    ("pr16_9", "proverbs", "Prov", 16, 9, None, None),
    ("pr16_18", "proverbs", "Prov", 16, 18, None, None),
    ("pr17_22", "proverbs", "Prov", 17, 22, None, None),
    ("pr18_21", "proverbs", "Prov", 18, 21, None, None),
    ("pr22_6", "proverbs", "Prov", 22, 6, None, None),
    ("pr24_16", "proverbs", "Prov", 24, 16, None, None),
    ("pr26_11", "proverbs", "Prov", 26, 11, None, None),
    ("pr27_17", "proverbs", "Prov", 27, 17, None, None),
    # --- Psalms ---
    ("ps23_1", "psalms", "Ps", 23, 1, ("L'Eternel est mon berger", None), ("The Lord is my shepherd", None)),
    ("ps23_4", "psalms", "Ps", 23, 4, None, None),
    ("ps27_1", "psalms", "Ps", 27, 1, ("L'Eternel est ma lumière", None), ("The Lord is my light", None)),
    ("ps30_5", "psalms", "Ps", 30, 5, None, None),
    ("ps37_4", "psalms", "Ps", 37, 4, None, None),
    ("ps46_10", "psalms", "Ps", 46, 10, ("Arrêtez", "je suis Dieu"), ("Be still", "I am God")),
    ("ps90_12", "psalms", "Ps", 90, 12, None, None),
    ("ps118_24", "psalms", "Ps", 118, 24, None, None),
    ("ps119_105", "psalms", "Ps", 119, 105, None, ("Thy word", None)),
    ("ps133_1", "psalms", "Ps", 133, 1, ("Voici, oh!", None), ("Behold", None)),
    # --- Ecclesiastes ---
    ("ec1_2", "ecclesiastes", "Eccl", 1, 2, None, None),
    ("ec1_9", "ecclesiastes", "Eccl", 1, 9, ("il n'y a rien de nouveau", None), ("there is no new thing", None)),
    ("ec3_1", "ecclesiastes", "Eccl", 3, 1, None, None),
    ("ec4_9", "ecclesiastes", "Eccl", 4, 9, None, None),
    ("ec9_10", "ecclesiastes", "Eccl", 9, 10, ("Tout ce que ta main", "fais-le"), ("Whatsoever thy hand", "with thy might")),
    ("ec11_1", "ecclesiastes", "Eccl", 11, 1, None, None),
    # --- Other scripture ---
    ("is40_31", "scripture", "Isa", 40, 31, None, None),
    ("rm12_21", "scripture", "Rom", 12, 21, None, None),
    ("1co13_13", "scripture", "1Cor", 13, 13, None, None),
    ("ph4_13", "scripture", "Phil", 4, 13, None, None),
]

# Entries where the second KJV copy has the more common spelling ("Caesar").
USE_KJV2 = {"mk12_17"}

FR_BOOKS = {
    "Matt": "Matthieu", "Mark": "Marc", "Luke": "Luc", "John": "Jean", "Acts": "Actes",
    "Prov": "Proverbes", "Ps": "Psaumes", "Eccl": "Ecclésiaste", "Isa": "Ésaïe",
    "Rom": "Romains", "1Cor": "1 Corinthiens", "Phil": "Philippiens",
}
EN_BOOKS = {
    "Matt": "Matthew", "Mark": "Mark", "Luke": "Luke", "John": "John", "Acts": "Acts",
    "Prov": "Proverbs", "Ps": "Psalm", "Eccl": "Ecclesiastes", "Isa": "Isaiah",
    "Rom": "Romans", "1Cor": "1 Corinthians", "Phil": "Philippians",
}


def norm(text):
    return text.replace("’", "'").replace("‘", "'")


def extract(text, trim, where):
    text = norm(text)
    if trim is None:
        span = text
    else:
        start, end = trim
        i = text.find(start)
        if i < 0:
            sys.exit(f"{where}: start phrase not found: {start!r}\n  in: {text}")
        span = text[i:]
        if end is not None:
            j = span.find(end)
            if j < 0:
                sys.exit(f"{where}: end phrase not found: {end!r}\n  in: {span}")
            span = span[: j + len(end)]
    span = span.strip()
    span = re.sub(r"\s*-\s*$", "", span)          # LSG stray dash (Ps 46:10)
    span = span[0].upper() + span[1:]
    span = re.sub(r"[,;:]$", "", span)
    if span[-1] not in ".!?":
        span += "."
    return span


def load_kjv2():
    d = json.load(open(KJV2))
    out = {}
    for b in d["books"]:
        for ch in b["chapters"]:
            for v in ch["verses"]:
                out[(b["book"], ch["chapter"], v["number"])] = v["text"].replace("''", "'")
    return out


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    lsg, kjv, kjv2 = load_lsg(), load_kjv(), load_kjv2()
    ids = set()
    rows = []
    for sid, cat, book, ch, vs, frt, ent in SPEC:
        assert sid not in ids, sid
        ids.add(sid)
        where = f"{sid} ({book} {ch}:{vs})"
        fr_raw = lsg[(book, ch, vs)]
        en_raw = kjv[(KJV_NAMES[book], ch, vs)]
        if sid in USE_KJV2:
            en_raw = kjv2[(book, ch, vs)]
        # Second KJV copy must agree word for word (ignoring apostrophe style and the Hebrew letter heading).
        en_raw2 = kjv2.get((book, ch, vs))
        a = re.sub(r"[^A-Za-z]+", " ", norm(en_raw)).strip().lower()
        b = re.sub(r"[^A-Za-z]+", " ", norm(en_raw2 or "")).strip().lower()
        if a != b and not a.endswith(b) and not b.endswith(a):
            print(f"WARNING KJV copies differ for {where}:\n  1: {en_raw}\n  2: {en_raw2}", file=sys.stderr)
        fr = extract(fr_raw, frt, where + " FR")
        en = extract(en_raw, ent, where + " EN")
        for s in (fr, en):
            assert "|" not in s and len(s.encode()) < 250, (sid, s)
        rows.append((sid, cat, f"{FR_BOOKS[book]} {ch}:{vs}", f"{EN_BOOKS[book]} {ch}:{vs}", fr, en))

    if "--print" in sys.argv:
        for r in rows:
            print(f"{r[0]:10} [{r[1]}]\n  FR: {r[4]} — {r[2]}\n  EN: {r[5]} — {r[3]}")
        print(len(rows), "verses")
        return

    out = []
    for sid, cat, fref, eref, fr, en in rows:
        out.append(
            f'    {{ id = "{sid}", cat = "{cat}",\n'
            f"      fr = {lua_str(fr)}, frRef = {lua_str(fref)},\n"
            f"      en = {lua_str(en)}, enRef = {lua_str(eref)} }},"
        )
    print("\n".join(out))


if __name__ == "__main__":
    main()
