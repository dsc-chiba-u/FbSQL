# Manuscript build environment (separate from the fbsql-dev runtime image,
# which has no rmarkdown/pandoc/LaTeX).
#
# rocker/verse pins R + pandoc + rmarkdown/knitr + TinyTeX in one image;
# we add weasyprint (development PDF) and the official VLDB Journal LaTeX
# template (svjour3 class + Springer .bst files, downloaded from Springer
# at build time -- journal-owned, never committed to this repository).
FROM rocker/verse:4.4.2

RUN apt-get update \
    && apt-get install -y --no-install-recommends weasyprint libarchive-tools \
    && rm -rf /var/lib/apt/lists/*

# LaTeX packages the svjour3 twocolumn build needs beyond the rocker
# TinyTeX baseline (containers later run unprivileged and cannot install).
RUN Rscript -e "tinytex::tlmgr_install(c('natbib', 'fancyvrb', 'framed', \
        'booktabs', 'multirow', 'upquote', 'lmodern', 'psnfss', \
        'epstopdf-pkg', 'grfext'))"

# Official VLDB Journal template assets -> /opt/vldbj (render.sh copies
# them into the build directory).
RUN mkdir -p /opt/vldbj \
    && curl -fsSL -o /tmp/vldbj.rar \
        "https://media.springer.com/full/springer-instructions-for-authors-assets/rar/LaTeX_VLDBJ_Template.rar" \
    && bsdtar -xf /tmp/vldbj.rar -C /tmp \
    && cp /tmp/LaTeX_VLDBJ_Template/svjour3.cls \
          /tmp/LaTeX_VLDBJ_Template/svglov3.clo \
          /tmp/LaTeX_VLDBJ_Template/spmpsci.bst \
          /tmp/LaTeX_VLDBJ_Template/spbasic.bst \
          /tmp/LaTeX_VLDBJ_Template/spphys.bst \
          /opt/vldbj/ \
    && rm -rf /tmp/vldbj.rar /tmp/LaTeX_VLDBJ_Template
