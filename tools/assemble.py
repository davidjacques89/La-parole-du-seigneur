"""Assemble WordsOfTheLord/Sayings.lua from the generated Bible entries plus the Québec list."""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "WordsOfTheLord", "Sayings.lua")

# (id, text, label). Traditional expressions, prayers and invocations used in Quebec Catholic culture.
# No author is claimed: the label says what kind of saying it is.
QUEBEC = [
    ("qc_aide_toi", "Aide-toi, le ciel t'aidera.", "Dicton populaire"),
    ("qc_propose", "L'homme propose, et Dieu dispose.", "Dicton populaire"),
    ("qc_prete_dieu", "Qui donne aux pauvres prête à Dieu.", "Dicton populaire"),
    ("qc_croix", "Chacun sa croix.", "Dicton populaire"),
    ("qc_porter", "Le bon Dieu ne nous donne jamais plus que ce que nous pouvons porter.", "Dicton populaire"),
    ("qc_offre", "Offre ça au bon Dieu.", "Expression québécoise"),
    ("qc_grace", "À la grâce de Dieu!", "Expression québécoise"),
    ("qc_si_dieu", "Si Dieu le veut.", "Expression traditionnelle"),
    ("qc_voit", "Le bon Dieu voit tout.", "Expression traditionnelle"),
    ("qc_dimanche", "Le dimanche, c'est le jour du Seigneur.", "Expression traditionnelle"),
    ("qc_rende", "Que le bon Dieu vous le rende.", "Souhait traditionnel"),
    ("qc_benisse", "Que le bon Dieu vous bénisse.", "Souhait traditionnel"),
    ("qc_garde", "Que Dieu vous garde.", "Souhait traditionnel"),
    ("qc_ora", "Prie et travaille.", "Devise monastique"),
    ("qc_signe", "Au nom du Père, et du Fils, et du Saint-Esprit. Ainsi soit-il.", "Signe de croix"),
    ("qc_gloire", "Gloire au Père, et au Fils, et au Saint-Esprit, comme il était au commencement, maintenant et toujours, et dans les siècles des siècles. Ainsi soit-il.", "Prière traditionnelle"),
    ("qc_pardon", "Pardonnez-nous nos offenses, comme nous pardonnons aussi à ceux qui nous ont offensés.", "Prière traditionnelle"),
    ("qc_pitie", "Seigneur, ayez pitié de nous. Christ, ayez pitié de nous.", "Prière traditionnelle"),
    ("qc_marie", "Sainte Marie, Mère de Dieu, priez pour nous, pauvres pécheurs, maintenant et à l'heure de notre mort.", "Prière traditionnelle"),
    ("qc_ange", "Ange de Dieu, qui êtes mon gardien, éclairez-moi, gardez-moi, dirigez-moi, gouvernez-moi. Ainsi soit-il.", "Prière traditionnelle"),
    ("qc_repos", "Donnez-leur, Seigneur, le repos éternel, et que la lumière sans fin brille sur eux.", "Prière traditionnelle"),
    ("qc_antoine", "Saint Antoine, bon Saint Antoine, faites que je retrouve ce que j'ai perdu.", "Invocation populaire"),
    ("qc_anne", "Bonne sainte Anne, priez pour nous.", "Invocation populaire"),
    ("qc_joseph", "Saint Joseph, priez pour nous.", "Invocation populaire"),
    # --- Prayers in their older wordings (public domain), as printed in Quebec prayer books ---
    ("qc_notre_pere", "Notre Père, qui êtes aux cieux, que votre nom soit sanctifié, que votre règne arrive, que votre volonté soit faite sur la terre comme au ciel. Donnez-nous aujourd'hui notre pain quotidien; pardonnez-nous nos offenses, comme nous pardonnons à ceux qui nous ont offensés; et ne nous induisez pas en tentation, mais délivrez-nous du mal. Ainsi soit-il.", "Notre Père (ancienne version)"),
    ("qc_je_vous_salue", "Je vous salue, Marie, pleine de grâce; le Seigneur est avec vous; vous êtes bénie entre toutes les femmes, et Jésus, le fruit de vos entrailles, est béni. Sainte Marie, Mère de Dieu, priez pour nous, pauvres pécheurs, maintenant et à l'heure de notre mort. Ainsi soit-il.", "Je vous salue, Marie"),
    ("qc_souvenez", "Souvenez-vous, ô très miséricordieuse Vierge Marie, qu'on n'a jamais entendu dire qu'aucun de ceux qui ont eu recours à votre protection, imploré votre assistance ou réclamé votre secours, ait été abandonné.", "Prière à la Vierge"),
    ("qc_angelus1", "L'ange du Seigneur apporta l'annonce à Marie. Et elle conçut du Saint-Esprit.", "Angélus"),
    ("qc_angelus2", "Voici la servante du Seigneur. Qu'il me soit fait selon votre parole.", "Angélus"),
    ("qc_angelus3", "Et le Verbe s'est fait chair. Et il a habité parmi nous.", "Angélus"),
    ("qc_angelus4", "Priez pour nous, sainte Mère de Dieu, afin que nous devenions dignes des promesses du Christ.", "Angélus"),
    ("qc_eau_benite", "Eau bénite, je te prends; si la mort me surprend, tu me serviras de saint sacrement.", "Prière populaire"),
    ("qc_offrande", "Divin Coeur de Jésus, je vous offre, par le Coeur Immaculé de Marie, toutes les prières, les oeuvres et les souffrances de ce jour.", "Offrande du matin"),
    ("qc_communion", "Seigneur, je ne suis pas digne que vous entriez dans mon âme, mais dites une parole et mon âme sera guérie.", "Avant la communion"),
    ("qc_adorons", "Adorons à jamais le Très Saint Sacrement.", "Invocation"),
    ("qc_credo", "Je crois en l'Esprit Saint, à la sainte Église catholique, à la communion des saints, à la rémission des péchés, à la résurrection de la chair, à la vie éternelle. Amen.", "Credo (fin)"),
    ("qc_benedicite", "Bénissez-nous, Seigneur, bénissez ce repas, ceux qui l'ont préparé, et procurez du pain à ceux qui n'en ont pas. Ainsi soit-il.", "Bénédicité"),
    ("qc_graces", "Merci, Seigneur, pour tous vos bienfaits, gardez nos âmes dans la paix.", "Action de grâces"),
    # --- Dictons des saints (traditional weather sayings; shared with the rest of the French-speaking world) ---
    ("qc_chandeleur", "À la Chandeleur, l'hiver passe ou prend rigueur.", "Dicton météo"),
    ("qc_ste_anne_pluie", "S'il pleut à la Sainte-Anne, il pleut un mois et une semaine.", "Dicton météo"),
    ("qc_ste_agathe", "À la Sainte-Agathe, moitié de ton foin et de ta paille.", "Dicton météo"),
    ("qc_ste_dorothee", "À la Sainte-Dorothée, la plus forte neigée.", "Dicton météo"),
    ("qc_st_blaise", "Le lendemain de la Saint-Blaise, souvent l'hiver s'apaise.", "Dicton météo"),
    ("qc_ste_isabelle", "Neige à la Sainte-Isabelle fait la fleur plus belle.", "Dicton météo"),
    ("qc_visitation", "S'il pleut à la Visitation, pluie à discrétion.", "Dicton météo"),
    ("qc_st_jean", "Saint Jean doit une averse; s'il ne la paie, Pierre la verse.", "Dicton météo"),
]

HEADER = '''-- Built-in sayings library. GENERATED by tools/assemble.py: edit the tools, not this file.
--
-- Bible verses are cut from public-domain texts: Louis Segond 1910 (French) and the
-- King James Version (English). Each id is permanent: favorites are saved by id,
-- so never reuse or renumber one.
--
-- Entry fields:  id, cat, fr, frRef, en, enRef
--   cat "quebec" entries have French text only; the label in frRef says what kind of
--   saying it is (traditional saying, prayer, invocation). They show up in "Québec" mode.
local _, ns = ...

-- Display order of categories, with names in French and English.
ns.CATEGORIES = {
    { key = "jesus",        en = "Words of Jesus",  fr = "Paroles de Jésus" },
    { key = "proverbs",     en = "Proverbs",        fr = "Proverbes" },
    { key = "psalms",       en = "Psalms",          fr = "Psaumes" },
    { key = "ecclesiastes", en = "Ecclesiastes",    fr = "Ecclésiaste" },
    { key = "scripture",    en = "Other scripture", fr = "Autres textes" },
    { key = "quebec",       en = "Québec",          fr = "Québec" },
}

-- Sayings used by the optional reactions (/parole reactions).
ns.reactionIds = { death = "lk23_34", revive = "jn11_25" }

ns.sayings = {
'''


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    bible = subprocess.run(
        [sys.executable, "-I", os.path.join(HERE, "build_sayings.py")],
        capture_output=True, text=True, check=True, stdin=subprocess.DEVNULL, timeout=90,
    ).stdout.rstrip("\n")
    qc = []
    seen = set()
    for sid, text, label in QUEBEC:
        assert sid not in seen and "|" not in text and len(text.encode()) < 500, sid
        seen.add(sid)
        qc.append(f'    {{ id = "{sid}", cat = "quebec", fr = {lua_str(text)}, frRef = {lua_str(label)} }},')
    out = HEADER + bible + "\n" + "\n".join(qc) + "\n}\n\n"
    out += """-- Lookup by id, built once.
ns.sayingsById = {}
for _, entry in ipairs(ns.sayings) do
    assert(not ns.sayingsById[entry.id], "duplicate saying id: " .. entry.id)
    ns.sayingsById[entry.id] = entry
end
"""
    open(OUT, "w").write(out)
    print("bible:", bible.count("id ="), "quebec:", len(QUEBEC))


main()
