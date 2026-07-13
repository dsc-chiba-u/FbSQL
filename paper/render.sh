#!/usr/bin/env bash
# Render the manuscript:
#   ./render.sh html   development build (html_document)
#   ./render.sh pdf    development build (html -> PDF via weasyprint)
#   ./render.sh vldb   submission build (Springer svjour3 twocolumn,
#                      The VLDB Journal; numbered references, spmpsci)
#
# The vldb build renders a copy of paper.Rmd in a temporary directory with
# the pandoc template paper/vldb/vldbj-template.tex. Journal class assets
# (svjour3.cls, svglov3.clo, spmpsci.bst) are taken from /opt/vldbj inside
# the fbsql-paper image (downloaded from Springer at image build time) and
# are never committed. Title and abstract come from paper.Rmd's YAML;
# authors, institutes, and keywords live in the template.
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
    vldb)
        Rscript - <<'EOF'
build <- file.path(tempdir(), "fbsql-vldb-build")
dir.create(build, recursive = TRUE, showWarnings = FALSE)
file.copy(list.files("/opt/vldbj", full.names = TRUE), build,
          overwrite = TRUE)
file.copy("vldb/vldbj-template.tex", build, overwrite = TRUE)
file.copy("references.bib", build, overwrite = TRUE)
file.copy("figures", build, recursive = TRUE)
file.copy("tables", build, recursive = TRUE)

## The related-work table is wider than one column: promote it to table*
## for the twocolumn layout (build-time only; the generated file in
## tables/ stays single-source in FbSQL-experiments).
rw <- file.path(build, "tables", "related_work.tex")
txt <- readLines(rw)
txt <- gsub("\\begin{table}[t!]", "\\begin{table*}[t!]", txt, fixed = TRUE)
txt <- gsub("\\end{table}", "\\end{table*}", txt, fixed = TRUE)
writeLines(txt, rw)

file.copy("paper.Rmd", build, overwrite = TRUE)
rmarkdown::render(file.path(build, "paper.Rmd"),
                  output_format = rmarkdown::pdf_document(
                      template = file.path(build, "vldbj-template.tex"),
                      citation_package = "natbib",
                      latex_engine = "pdflatex",
                      number_sections = TRUE,
                      fig_caption = TRUE,
                      highlight = "tango",
                      keep_tex = TRUE),
                  output_file = "paper-vldb.pdf")
file.copy(file.path(build, "paper-vldb.pdf"), "paper-vldb.pdf",
          overwrite = TRUE)
EOF
        ;;
    *)
        echo "usage: $0 [html|pdf|vldb]" >&2
        exit 1
        ;;
esac
