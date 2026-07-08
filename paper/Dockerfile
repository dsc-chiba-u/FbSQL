# Manuscript build environment (separate from the fbsql-dev runtime image,
# which has no rmarkdown/pandoc/LaTeX).
#
# rocker/verse pins R + pandoc + rmarkdown/knitr + TinyTeX in one image;
# we add rticles (JSS submission build) and weasyprint (development PDF).
FROM rocker/verse:4.4.2

RUN apt-get update \
    && apt-get install -y --no-install-recommends weasyprint \
    && rm -rf /var/lib/apt/lists/* \
    && install2.r --error --skipinstalled rticles

# Bake the LaTeX packages the JSS class needs into the image: install the
# known set, then render the rticles JSS skeleton and let
# tinytex::parse_install() pick up anything still missing (containers run
# as an unprivileged user later and cannot install LaTeX packages).
RUN Rscript -e "\
        tinytex::tlmgr_install(c('orcidlink', 'pgf', 'thumbpdf', 'upquote', \
                                 'lmodern', 'natbib', 'fancyvrb', 'grfext', \
                                 'epstopdf-pkg', 'booktabs', 'multirow')); \
        d <- file.path(tempdir(), 'jss-warmup'); \
        dir.create(d); \
        skel <- system.file('rmarkdown', 'templates', 'jss', 'skeleton', package = 'rticles'); \
        file.copy(list.files(skel, full.names = TRUE), d); \
        rmd <- file.path(d, 'skeleton.Rmd'); \
        ok <- FALSE; \
        for (i in 1:4) { \
            ok <- tryCatch({ \
                rmarkdown::render(rmd, output_format = rticles::jss_article()); \
                TRUE \
            }, error = function(e) FALSE); \
            if (ok) break; \
            tinytex::parse_install(file.path(d, 'skeleton.log')); \
        }; \
        if (!ok) stop('JSS skeleton warm-up failed'); \
        unlink(d, recursive = TRUE)"
