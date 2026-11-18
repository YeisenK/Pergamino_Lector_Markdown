#!/usr/bin/env python3
"""Genera el diccionario de Pergamino a partir del extracto de Wiktionary en español
(kaikki.org, CC BY-SA 4.0). Salida: un archivo de texto ordenado por clave, una línea por
palabra: `clave<TAB>JSON`, donde JSON = [{"w": forma, "p": clase, "g": [definiciones]}].

Uso: python3 build_dict.py entrada.jsonl.gz salida.txt
"""
import gzip, json, re, sys, unicodedata
from collections import defaultdict

POS_ES = {
    'noun': 'sustantivo', 'verb': 'verbo', 'adj': 'adjetivo', 'adv': 'adverbio',
    'pron': 'pronombre', 'prep': 'preposición', 'conj': 'conjunción', 'intj': 'interjección',
    'num': 'numeral', 'det': 'determinante', 'article': 'artículo', 'name': 'nombre propio',
    'prefix': 'prefijo', 'suffix': 'sufijo', 'particle': 'partícula', 'phrase': 'frase',
    'proverb': 'refrán', 'abbrev': 'abreviatura', 'symbol': 'símbolo', 'affix': 'afijo',
}
MAX_GLOSSES = 3
MAX_LEN = 200

def key_of(word: str) -> str:
    """Clave de búsqueda: minúsculas, sin acentos, solo ASCII (para ordenar por bytes)."""
    s = unicodedata.normalize('NFD', word.lower())
    s = ''.join(c for c in s if unicodedata.category(c) != 'Mn')
    s = s.replace('ñ', 'n')
    return re.sub(r'[^a-z0-9\-\' ]', '', s).strip()

def main(src, dst):
    senses = defaultdict(list)   # clave -> lista de entradas
    seen = set()
    with gzip.open(src, 'rt', encoding='utf-8') as f:
        for line in f:
            d = json.loads(line)
            word = d.get('word', '')
            pos = POS_ES.get(d.get('pos', ''), d.get('pos', ''))
            glosses = []
            for s in d.get('senses', []):
                for g in s.get('glosses', []):
                    g = g.strip()
                    if g and len(g) <= MAX_LEN and g not in glosses:
                        glosses.append(g)
                    if len(glosses) >= MAX_GLOSSES:
                        break
                if len(glosses) >= MAX_GLOSSES:
                    break
            if not word or not glosses:
                continue
            k = key_of(word)
            if not k:
                continue
            sig = (k, word, pos, tuple(glosses))
            if sig in seen:
                continue
            seen.add(sig)
            senses[k].append({'w': word, 'p': pos, 'g': glosses})
    n = 0
    with open(dst, 'w', encoding='utf-8', newline='\n') as out:
        for k in sorted(senses.keys(), key=lambda s: s.encode('ascii')):
            out.write(f"{k}\t{json.dumps(senses[k][:12], ensure_ascii=False, separators=(',', ':'))}\n")
            n += 1
    print(f"{n} palabras -> {dst}")

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
