#!/usr/bin/env python3
from bs4 import BeautifulSoup
from json import dumps
from sys import argv
from urllib.request import urlopen

soup = BeautifulSoup(urlopen(argv[1]), 'html.parser')

versions = [
    span.text \
        for release in soup.find_all('div', class_='release') \
            for span in release.find_all('span', class_='css-truncate-target')
]

unique = []
for v in versions:
    if v not in unique:
        unique.append(v)

print(dumps(unique))
