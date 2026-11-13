"""Print raw LSG 1910 + KJV text for a list of references, to choose trims from."""
import json
import os
import sys

# Source texts (public domain). See tools/README.md for where to download them.
DATA = os.environ.get("BIBLE_DATA", os.path.join(os.path.dirname(os.path.abspath(__file__)), "data"))
LSG = os.path.join(DATA, "midvash", "versions", "fr", "lsg", "lsg.json")
KJV = os.path.join(DATA, "scrollmapper", "formats", "json", "KJV.json")


def load_lsg():
    d = json.load(open(LSG))
    out = {}
    for b in d["books"]:
        for ch in b["chapters"]:
            for v in ch["verses"]:
                out[(b["book"], ch["chapter"], v["number"])] = v["text"].replace("''", "'")
    return out


KJV_NAMES = {
    "Matt": "Matthew", "Mark": "Mark", "Luke": "Luke", "John": "John", "Acts": "Acts",
    "Prov": "Proverbs", "Ps": "Psalms", "Eccl": "Ecclesiastes", "Isa": "Isaiah",
    "1Cor": "I Corinthians", "Phil": "Philippians", "Rom": "Romans",
}


def load_kjv():
    d = json.load(open(KJV))
    out = {}
    for b in d["books"]:
        for ch in b["chapters"]:
            for v in ch["verses"]:
                out[(b["name"], ch["chapter"], v["verse"])] = v["text"]
    return out


REFS = [line.split() for line in sys.stdin.read().strip().splitlines()]

if __name__ == "__main__":
    lsg, kjv = load_lsg(), load_kjv()
    kjv_books = sorted({k[0] for k in kjv})
    for book, ch, vs in REFS:
        key = (book, int(ch), int(vs))
        kname = KJV_NAMES[book]
        if (kname, int(ch), int(vs)) not in kjv:
            print("KJV MISSING", kname, kjv_books[:5])
        print(f"{book} {ch}:{vs}")
        print("  FR:", lsg.get(key, "MISSING"))
        print("  EN:", kjv.get((kname, int(ch), int(vs)), "MISSING"))
