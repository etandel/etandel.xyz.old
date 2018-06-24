--------
title: Criando um framework para crawler distribuido em python
--------

### Introdução

Um _crawler_ é um programa que é capaz de navegar páginas web recursivamente.
Ou seja, dadas uma ou mais URLs iniciais, ele visita a página, extrai os links na página, visita esses links e assim por diante até não ter mais o que visitar ou atingir alguma condição definida pelo usuário.
Cralwers são usados principalmente para [replicar sites](https://en.wikipedia.org/wiki/Mirror_website), indexar a web (e.g. Google) ou extrair informações relevantes de sites, também chamado de [web scraping](https://pt.wikipedia.org/wiki/Coleta_de_dados_web).

A lógica de um crawler pode ser resumida no diagrama abaixo:

![](/images/crawler-flowchart.svg)

Note que essencialmente um crawler é simples: possui apenas um _loop_ e algumas condições de parada. No entanto, são tantos os problemas que podem ocorrer em qualquer uma dessas etapas que criar e manter um crawler robusto e rápido não é nem um pouco trivial. Por isso, apesar de existirem diversas ferramentas no mercado que abstraem essa tarefa - e para produção você provavelmente deveria usar uma delas em vez de criar outra do zero -, esse artigo visa explicar o passo-a-passo de criar um crawler em Python, iniciando com uma implementação mais ingênua e evoluindo ela para ganhar performance e lidar melhor com dificuldades comuns.

### Versão 1: Um processo, uma thread, síncrono e ingênuo.

Para uma primeira versão, vamos implementar o mínimo necessário para um crawler funcionar e não nos preocupar muito com qualquer problema que possa surgir.

Antes de começar, precisamos resolver como é que o crawler vai visitar uma página e extrair seus links. O ecossistema do Python possui muitas bibliotecas que podem ajudar nisso, algumas que até já vem embutidas na própria biblioteca padrão da linguagem; pessoalmente, acho que as mais simples são a [Requests]() para lidar com a camada HTTP e [BeautifulSoup]() mais [lxml]() para trabalhar com o conteúdo HTML da página.


Primeiro, vamos criar uma função para que visita uma URL e retorna seu conteúdo, sem se preocupar por enquanto com erros que possam acontecer no meio do caminho:

``` python
import requests


def fetch(url: str) -> str:
    """
    Executa um GET na url e retorna o conteúdo respondido.
    """
    return requests.get(url).content
```

Precisamos também de uma função que leia o HTML da página e extraia os links:

``` python
from typing import List

from bs4 import BeautifulSoup


def get_links(content: str) -> List[str]:
    """
    Busca todas as tags <a> em content que possuam a propriedade href,
    e então retorna os hrefs em uma lista.
    """
    return [a['href']
            for a in BeautifulSoup(content, 'lxml').find_all('a', href=True)]
```

Agora a função que de fato faz a lógica toda. Ela deve receber uma URL inicial e executar o fluxograma acima.
Para isso vamos precisar de uma fila de URLs a visitar, um conjunto para armazenar as urls já visitadas, e um _loop_ para manter a coisa toda rodando.
Além disso, como todo algoritmo recursivo, é sempre bom ter uma condição de parada que evite que nosso crawler fique rodando para sempre; para isso, vamos definir uma profundidade máxima para a recursão.
A nossa fila então vai guardar as próximas URLs a serem visitadas e suas respectivas profundidades, para podermos saber se devemos entrar mais um nível no site ou não.

``` python
from queue import Queue  # já vem pronto na linguagem


def crawl(seed: str, max_depth: int=3):
    # urls já visitadas
    visited = set()

    # fila de urls a visitar.
    # já adicionamos a url original, que tem profundidade 0
    queue = Queue()
    queue.put((0, seed))

    # se a fila estiver vazia, paramos o processamento
    while not queue.empty():
        depth, url = queue.get()
        visited.add(url)

        content = fetch(url)
        # faz alguma coisa com o conteúdo
        process_page(depth, url, content)

        # se a profundidade atual já for máxima, nem pegamos os próximos links
        # se não, adicionamos cada link na fila,
        # lembrando de incrementar a profundidade
        if depth < max_depth:
            for link in get_links(content):
                if link not in visited:
                    queue.put((depth + 1, link))

```

Note a chamada da função `process_page()`. Como só visitar recursivamente um site não traz nenhum valor, precisamos passar os dados recebidos para alguém fazer algo interessante com isso. Por enquanto, vamos só imprimir na tela a profundidade e a url:

``` python
def process_page(depth: int, url: str, content: str):
    print(f'{depth} - {url}')
```

Falta só adicionar um _boilerplate_ para iniciarmos o crawler pela linha de comando:

``` python
import sys

if __name__ == '__main__':
    max_depth, seed = sys.argv[1:]
    crawl(seed, int(max_depth))
```


### Testando

- Testar g1
- Testar etandel.xyz -> mostrar que links relativos bugam
- reescrever get_links() com urljoin
- explicar e consertar erro de TOCTOU no if link not in visited


### Arquivo final:

``` python
import sys
from queue import Queue
from typing import List
from urllib.parse import urljoin

from bs4 import BeautifulSoup
import requests


def fetch(url: str) -> str:
    """
    Executa um GET na url e retorna o conteúdo respondido.
    """
    return requests.get(url).content


def get_links(url: str, content: str) -> List[str]:
    """
    Busca todas as tags <a> em content que possuam a propriedade href,
    normaliza os hrefs para serem URLs absolutas baseadas na url dada
    e então retorna os links em uma lista.
    """
    return [urljoin(url, a['href'])
            for a in BeautifulSoup(content, 'lxml').find_all('a', href=True)]


def process_page(depth: int, url: str, content: str):
    print(f'{depth} - {url}')


def crawl(seed: str, max_depth: int=3):
    # urls já visitadas
    visited = set()

    # fila de urls a visitar.
    # já adicionamos a url original, que tem profundidade 0
    queue = Queue()
    queue.put((0, seed))

    # se a fila estiver vazia, paramos o processamento
    while not queue.empty():
        depth, url = queue.get()
        if url not in visited:
            visited.add(url)

            content = fetch(url)
            # faz alguma coisa com o conteúdo
            process_page(depth, url, content)

            # se a profundidade atual já for máxima, nem pegamos os links
            # se não, adicionamos cada link na fila,
            # lembrando de incrementar a profundidade
            if depth < max_depth:
                for link in get_links(url, content):
                    if link not in visited:
                        queue.put((depth + 1, link))


if __name__ == '__main__':
    max_depth, seed = sys.argv[1:]
    crawl(seed, int(max_depth))
```

### Um processo, uma thread, assíncrono


### Distribuido
### Framework
### O que mais?
    -  timeout
    -  abstrair processamento de erros
    -  múltiplos fetchers
    -  múltiplas filas

