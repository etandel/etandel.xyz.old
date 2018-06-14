--------
title: Criando um framework para crawler distribuido em python
--------

### Introdução
### Um processo, uma thread, síncrono
``` python
from queue import Queue

import requests
from bs4 import BeautifulSoup


def fetch(url: str) -> str:
    return requests.get(url).content


def process_page(depth: int, url: str, content: str) -> None:
    raise NotImplementedError()


def crawl(seed: str, max_depth=3: int):
    visited = set()

    queue = Queue()
    queue.put((0, seed))

    while not queue.empty():
        depth, url = queue.get()
        visited.add(url)

        content = fetch(url)
        parser = BeautifulSoup(content, 'lxml')

        process_page(depth, url, content)

        if depth < max_depth:
            for link in parser.find_all('a', href=True):
                href = link['href']
                if href not in self.visited:
                    q.put((depth + 1, href))

```
### Um processo, uma thread, assíncrono


### Distribuido
### Framework
### O que mais?
    -  timeout
    -  abstrair processamento de erros
    -  múltiplos fetchers
    -  múltiplas filas

