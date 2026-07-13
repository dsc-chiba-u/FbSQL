# Manuscript build targets. Every render runs inside the pinned
# fbsql-paper image (see Dockerfile); build it once with `make image`.
# Rendered outputs are gitignored; regenerate them from paper.Rmd.

IMAGE ?= fbsql-paper
RUN := docker run --rm -u $(shell id -u):$(shell id -g) -e HOME=/tmp \
	-v $(CURDIR):/paper -w /paper $(IMAGE)

.PHONY: image html pdf vldb clean

image:
	docker build -t $(IMAGE) .

html:
	$(RUN) ./render.sh html

pdf:
	$(RUN) ./render.sh pdf

vldb:
	$(RUN) ./render.sh vldb

clean:
	rm -rf paper.html paper.pdf paper-vldb.pdf paper-jss.pdf paper_files paper_cache
