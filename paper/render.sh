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
        # untouched, as in fbrglm's render_jss_pdf.R.
        Rscript - <<'EOF'
build <- file.path(tempdir(), "fbsql-jss-build")
dir.create(build, recursive = TRUE, showWarnings = FALSE)
file.copy(c("paper.Rmd", "references.bib"), build, overwrite = TRUE)
## TODO: swap the YAML output block to rticles::jss_article on the copy
## (see fbrglm/scripts/render_jss_pdf.R for the sed-style rewrite) once
## the manuscript has content worth rendering in JSS form.
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
