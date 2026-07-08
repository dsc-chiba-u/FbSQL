#!/usr/bin/env bash
# Render the manuscript. Mirrors the fbrglm two-pipeline setup:
#   ./render.sh html   development build (html_document)
#   ./render.sh pdf    development build (html -> PDF via weasyprint)
#   ./render.sh jss    submission build (rticles::jss_article + pdflatex)
#
# Requirements (not provided by the fbsql-dev image, which is runtime-only):
#   html/pdf : R + rmarkdown + pandoc (+ weasyprint for pdf)
#   jss      : additionally rticles + a LaTeX distribution (pdflatex);
#              jss.cls / jss.bst / jsslogo.jpg are copied into a temporary
#              build directory from the rticles installation, so nothing
#              journal-owned is committed here.
# TODO: pin a paper-build environment (dedicated Dockerfile or renv) once
# writing starts in earnest.
set -euo pipefail
cd "$(dirname "$0")"

TARGET="${1:-html}"

case "$TARGET" in
    html)
        Rscript -e 'rmarkdown::render("paper.Rmd", output_format = "html_document")'
        ;;
    pdf)
        Rscript -e 'rmarkdown::render("paper.Rmd", output_format = "html_document")'
        weasyprint paper.html paper.pdf
        ;;
    jss)
        # Render a temporary copy with the rticles jss_article format so
        # the source Rmd (whose active output is html_document) stays
        # untouched, as in fbrglm's render_jss_pdf.R: the YAML header is
        # swapped for the JSS-structured form and the class assets are
        # copied in from the rticles skeleton.
        Rscript - <<'EOF'
build <- file.path(tempdir(), "fbsql-jss-build")
dir.create(build, recursive = TRUE, showWarnings = FALSE)
skel <- system.file("rmarkdown", "templates", "jss", "skeleton",
                    package = "rticles")
file.copy(file.path(skel, c("jss.cls", "jss.bst", "jsslogo.jpg")),
          build, overwrite = TRUE)
file.copy("references.bib", build, overwrite = TRUE)

## Keep the JSS-form metadata below in sync with paper.Rmd's YAML.
lines <- readLines("paper.Rmd")
fences <- which(lines == "---")
body <- lines[(fences[2] + 1L):length(lines)]
header <- c(
  "---",
  "documentclass: jss",
  "title:",
  "  formatted: \"FbSQL: A Closure-Preserving Formula-based Extension for Statistical Modeling in SQL\"",
  "  plain:     \"FbSQL: A Closure-Preserving Formula-based Extension for Statistical Modeling in SQL\"",
  "  short:     \"FbSQL: Formula-based Statistical Modeling in SQL\"",
  "author:",
  "  - name: Koki Tsuyuzaki",
  "    affiliation: Chiba University and RIKEN",
  "    email: \\email{koki.tsuyuzaki@gmail.com}",
  "  - name: Kentaro Sakamaki",
  "    affiliation: Juntendo University and Chiba University",
  "    email: \\email{kentaro.sakamaki@gmail.com}",
  "  - name: Hiromu Nishiuchi",
  "    affiliation: Chiba University and Chuo University",
  "    email: \\email{hiromunishiuchi@gmail.com}",
  "abstract: >",
  "  TODO: abstract (kept in sync with paper.Rmd at writing time).",
  "keywords:",
  "  formatted: [SQL, PostgreSQL, generalized linear models, formula interface, closure]",
  "  plain:     [SQL, PostgreSQL, generalized linear models, formula interface, closure]",
  "bibliography: references.bib",
  "---")
writeLines(c(header, body), file.path(build, "paper.Rmd"))

rmarkdown::render(file.path(build, "paper.Rmd"),
                  output_format = rticles::jss_article(),
                  output_file = "paper-jss.pdf")
file.copy(file.path(build, "paper-jss.pdf"), "paper-jss.pdf",
          overwrite = TRUE)
EOF
        ;;
    *)
        echo "usage: $0 [html|pdf|jss]" >&2
        exit 1
        ;;
esac
