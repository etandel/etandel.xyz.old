.PHONY: build-deploy

SITE_FILES ?= ./blog/* ./css/* ./images/* ./templates/*

site: .stack-work/dist/x86_64-linux-tinfo6/Cabal-2.0.1.0/build/site/site $(SITE_FILES)
	.stack-work/dist/x86_64-linux-tinfo6/Cabal-2.0.1.0/build/site/site build

.stack-work/dist/x86_64-linux-tinfo6/Cabal-2.0.1.0/build/site/site: site.hs
	stack build

clean:
	if [[ -d _site ]]; then rm -r "./_site"; fi
	if [[ -d _cache ]]; then rm -r "./_cache"; fi

deploy:
	rsync -avz _site/ etandel.xyz:/usr/share/nginx/etandel.xyz

build-deploy: site deploy
