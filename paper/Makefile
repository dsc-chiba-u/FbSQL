# Manuscript build targets (thin wrappers over render.sh).
# Rendered outputs are gitignored; regenerate them from paper.Rmd.

.PHONY: html pdf jss clean

html:
	./render.sh html

pdf:
	./render.sh pdf

jss:
	./render.sh jss

clean:
	rm -rf paper.html paper.pdf paper-jss.pdf paper_files paper_cache
