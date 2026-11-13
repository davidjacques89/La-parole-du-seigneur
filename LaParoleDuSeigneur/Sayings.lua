-- Built-in sayings.
-- French: Louis Segond 1910. English: King James Version. Both are in the public domain.
-- Each entry is { text, reference }. Add, remove or edit freely: the addon reads this list at login.
local _, ns = ...

ns.sayings = {
    fr = {
        { "Car Dieu a tant aimé le monde qu'il a donné son Fils unique, afin que quiconque croit en lui ne périsse point, mais qu'il ait la vie éternelle.", "Jean 3:16" },
        { "Heureux les pauvres en esprit, car le royaume des cieux est à eux!", "Matthieu 5:3" },
        { "Heureux les débonnaires, car ils hériteront la terre!", "Matthieu 5:5" },
        { "Heureux ceux qui procurent la paix, car ils seront appelés fils de Dieu!", "Matthieu 5:9" },
        { "Vous êtes la lumière du monde. Une ville située sur une montagne ne peut être cachée.", "Matthieu 5:14" },
        { "Aimez vos ennemis, bénissez ceux qui vous maudissent, faites du bien à ceux qui vous haïssent, et priez pour ceux qui vous maltraitent et qui vous persécutent.", "Matthieu 5:44" },
        { "Ne vous inquiétez donc pas du lendemain; car le lendemain aura soin de lui-même. A chaque jour suffit sa peine.", "Matthieu 6:34" },
        { "Ne jugez point, afin que vous ne soyez point jugés.", "Matthieu 7:1" },
        { "Demandez, et l'on vous donnera; cherchez, et vous trouverez; frappez, et l'on vous ouvrira.", "Matthieu 7:7" },
        { "Tout ce que vous voulez que les hommes fassent pour vous, faites-le de même pour eux, car c'est la loi et les prophètes.", "Matthieu 7:12" },
        { "Venez à moi, vous tous qui êtes fatigués et chargés, et je vous donnerai du repos.", "Matthieu 11:28" },
        { "Il est plus facile à un chameau de passer par le trou d'une aiguille qu'à un riche d'entrer dans le royaume de Dieu.", "Matthieu 19:24" },
        { "Ainsi les derniers seront les premiers, et les premiers seront les derniers.", "Matthieu 20:16" },
        { "Tu aimeras ton prochain comme toi-même.", "Matthieu 22:39" },
        { "Remets ton épée à sa place; car tous ceux qui prendront l'épée périront par l'épée.", "Matthieu 26:52" },
        { "L'esprit est bien disposé, mais la chair est faible.", "Matthieu 26:41" },
        { "L'homme ne vivra pas de pain seulement, mais de toute parole qui sort de la bouche de Dieu.", "Matthieu 4:4" },
        { "Rendez à César ce qui est à César, et à Dieu ce qui est à Dieu.", "Marc 12:17" },
        { "Ne jugez point, et vous ne serez point jugés; ne condamnez point, et vous ne serez point condamnés; absolvez, et vous serez absous.", "Luc 6:37" },
        { "Père, pardonne-leur, car ils ne savent ce qu'ils font.", "Luc 23:34" },
        { "Que celui de vous qui est sans péché jette le premier la pierre.", "Jean 8:7" },
        { "Vous connaîtrez la vérité, et la vérité vous affranchira.", "Jean 8:32" },
        { "Je suis la résurrection et la vie. Celui qui croit en moi vivra, quand même il serait mort.", "Jean 11:25" },
        { "Je vous donne un commandement nouveau: Aimez-vous les uns les autres; comme je vous ai aimés, vous aussi, aimez-vous les uns les autres.", "Jean 13:34" },
        { "Je suis le chemin, la vérité, et la vie.", "Jean 14:6" },
        { "Il n'y a pas de plus grand amour que de donner sa vie pour ses amis.", "Jean 15:13" },
    },
    en = {
        { "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.", "John 3:16" },
        { "Blessed are the poor in spirit: for theirs is the kingdom of heaven.", "Matthew 5:3" },
        { "Blessed are the meek: for they shall inherit the earth.", "Matthew 5:5" },
        { "Blessed are the peacemakers: for they shall be called the children of God.", "Matthew 5:9" },
        { "Ye are the light of the world. A city that is set on an hill cannot be hid.", "Matthew 5:14" },
        { "Love your enemies, bless them that curse you, do good to them that hate you, and pray for them which despitefully use you, and persecute you.", "Matthew 5:44" },
        { "Take therefore no thought for the morrow: for the morrow shall take thought for the things of itself. Sufficient unto the day is the evil thereof.", "Matthew 6:34" },
        { "Judge not, that ye be not judged.", "Matthew 7:1" },
        { "Ask, and it shall be given you; seek, and ye shall find; knock, and it shall be opened unto you.", "Matthew 7:7" },
        { "All things whatsoever ye would that men should do to you, do ye even so to them: for this is the law and the prophets.", "Matthew 7:12" },
        { "Come unto me, all ye that labour and are heavy laden, and I will give you rest.", "Matthew 11:28" },
        { "It is easier for a camel to go through the eye of a needle, than for a rich man to enter into the kingdom of God.", "Matthew 19:24" },
        { "So the last shall be first, and the first last.", "Matthew 20:16" },
        { "Thou shalt love thy neighbour as thyself.", "Matthew 22:39" },
        { "Put up again thy sword into his place: for all they that take the sword shall perish with the sword.", "Matthew 26:52" },
        { "The spirit indeed is willing, but the flesh is weak.", "Matthew 26:41" },
        { "Man shall not live by bread alone, but by every word that proceedeth out of the mouth of God.", "Matthew 4:4" },
        { "Render to Caesar the things that are Caesar's, and to God the things that are God's.", "Mark 12:17" },
        { "Judge not, and ye shall not be judged: condemn not, and ye shall not be condemned: forgive, and ye shall be forgiven.", "Luke 6:37" },
        { "Father, forgive them; for they know not what they do.", "Luke 23:34" },
        { "He that is without sin among you, let him first cast a stone.", "John 8:7" },
        { "And ye shall know the truth, and the truth shall make you free.", "John 8:32" },
        { "I am the resurrection, and the life: he that believeth in me, though he were dead, yet shall he live.", "John 11:25" },
        { "A new commandment I give unto you, That ye love one another; as I have loved you, that ye also love one another.", "John 13:34" },
        { "I am the way, the truth, and the life.", "John 14:6" },
        { "Greater love hath no man than this, that a man lay down his life for his friends.", "John 15:13" },
    },
}

-- Sayings used by the optional reactions (/parole reactions), found by reference.
ns.reactionRefs = {
    death = { fr = "Luc 23:34", en = "Luke 23:34" },
    revive = { fr = "Jean 11:25", en = "John 11:25" },
}
