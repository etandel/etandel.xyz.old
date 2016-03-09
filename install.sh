#!/usr/bin/env zsh

luarocks --tree=luarocks install --server=http://luarocks.org/dev sitegen

luarocks path --bin > activate.sh
sed -i "s:$HOME/.luarocks:$(pwd)/luarocks:g" activate.sh

