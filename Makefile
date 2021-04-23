.PHONY: builder

SITE_FILES ?= ./blog/* ./css/* ./images/* ./templates/*

site: .stack-work/dist/x86_64-linux-tinfo6/Cabal-2.0.1.0/build/site/site
	@.stack-work/dist/x86_64-linux-tinfo6/Cabal-2.0.1.0/build/site/site build

.stack-work/dist/x86_64-linux-tinfo6/Cabal-2.0.1.0/build/site/site: $(SITE_FILES)
	@stack build

deploy: site
	@rsync -avz _site/ etandel.xyz:/usr/share/nginx/etandel.xyz
