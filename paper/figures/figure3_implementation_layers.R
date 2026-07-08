# Figure 3 (implementation layers): the language specification on top, the
# PostgreSQL extension realizing it (R behind fitting, no R behind
# prediction, the model relation as the boundary artifact), and the
# verification layer enforcing conformance continuously.
#
# Same style/palette as figure1_system_overview.R. Regenerate with:
#   docker run --rm -u "$(id -u):$(id -g)" -v "$PWD":/paper -w /paper \
#       fbsql-paper Rscript figures/figure3_implementation_layers.R
# Caption lives in paper/paper.Rmd (fig.cap of the figure3 chunk).

library(grid)

col_lang_fill  <- "#F0F5FB"
col_lang_line  <- "#4477AA"
col_impl_fill  <- "#F5F5F5"
col_impl_line  <- "#999999"
col_box_fill   <- "#FFFFFF"
col_model_fill <- "#FFF7E6"
col_model_line <- "#CC7722"
col_arrow      <- "#333333"

draw <- function() {
    grid.newpage()
    pushViewport(viewport(xscale = c(0, 1000), yscale = c(0, 640)))

    box <- function(x0, y0, x1, y1, fill, border, lwd = 1, lty = "solid", r = 0.06) {
        grid.roundrect(x = unit((x0 + x1) / 2, "native"),
                       y = unit((y0 + y1) / 2, "native"),
                       width = unit(x1 - x0, "native"),
                       height = unit(y1 - y0, "native"),
                       r = unit(r, "snpc"),
                       gp = gpar(fill = fill, col = border, lwd = lwd, lty = lty))
    }
    txt <- function(x, y, label, size = 9, face = "plain", col = "black", just = "centre") {
        grid.text(label, x = unit(x, "native"), y = unit(y, "native"),
                  just = just,
                  gp = gpar(fontsize = size, fontface = face, col = col,
                            fontfamily = "sans"))
    }
    arr <- function(x0, y0, x1, y1, col = col_arrow, lty = "solid", lwd = 1.4) {
        grid.segments(unit(x0, "native"), unit(y0, "native"),
                      unit(x1, "native"), unit(y1, "native"),
                      gp = gpar(col = col, lwd = lwd, lty = lty),
                      arrow = arrow(length = unit(2.2, "mm"), type = "closed"))
    }
    seg <- function(x0, y0, x1, y1, col = col_arrow, lwd = 1.4) {
        grid.segments(unit(x0, "native"), unit(y0, "native"),
                      unit(x1, "native"), unit(y1, "native"),
                      gp = gpar(col = col, lwd = lwd))
    }

    ## language specification (fixed part, top)
    box(150, 545, 850, 628, col_lang_fill, col_lang_line, lwd = 1.6)
    txt(500, 604, "FbSQL language specification — the fixed part", size = 11,
        face = "bold", col = col_lang_line)
    txt(500, 578, "signatures · formula semantics (R's glm) · model relation columns · metadata schema · error policies",
        size = 8, col = col_lang_line)
    txt(500, 558, "defined independently of any engine", size = 8,
        face = "italic", col = col_lang_line)

    arr(500, 543, 500, 517)

    ## extension (realization)
    box(60, 200, 940, 515, col_impl_fill, col_impl_line, lwd = 1.2, lty = "dashed")
    txt(80, 492, "PostgreSQL extension — reference implementation",
        size = 10.5, face = "bold", col = "#555555", just = "left")
    txt(80, 472, "one realization; engines are replaceable (C · GPU · distributed)",
        size = 8, col = "#555555", just = "left")

    ## fit side (uses R)
    box(120, 340, 420, 450, col_box_fill, col_impl_line)
    txt(270, 428, "fit_glm()", size = 10.5, face = "bold")
    txt(270, 404, "PL/R → stats::glm()", size = 9, face = "bold", col = "#444444")
    txt(270, 380, "R as internal engine", size = 8, col = "#666666")
    txt(270, 360, "(never exposed to the user)", size = 8, col = "#666666")

    ## predict side (no R)
    box(580, 340, 880, 450, col_box_fill, col_impl_line)
    txt(730, 428, "predict_glm()", size = 10.5, face = "bold")
    txt(730, 404, "PL/pgSQL — no R", size = 9, face = "bold", col = "#444444")
    txt(730, 380, "computes from the model", size = 8, col = "#666666")
    txt(730, 360, "relation alone", size = 8, col = "#666666")

    ## model relation: the boundary artifact between the engines
    box(390, 225, 610, 320, col_model_fill, col_model_line, lwd = 2.4, r = 0.06)
    txt(500, 296, "Model relation", size = 11, face = "bold", col = "#7A4A00")
    txt(500, 272, "term rows + metadata", size = 8.5)
    txt(500, 248, "the boundary artifact:\nall that crosses the engines", size = 8,
        face = "italic", col = "#7A4A00")

    ## fit -> model -> predict (through the boundary artifact)
    seg(270, 338, 270, 272, col = col_model_line)
    arr(270, 272, 388, 272, col = col_model_line)
    seg(612, 272, 730, 272, col = col_model_line)
    arr(730, 272, 730, 338, col = col_model_line)

    arr(500, 198, 500, 172)

    ## verification layer
    box(150, 85, 850, 170, col_impl_fill, "#555555", lwd = 1.4)
    txt(500, 146, "Verification — conformance enforced continuously", size = 10.5,
        face = "bold", col = "#333333")
    txt(500, 120, "pg_regress conformance suite · R parity at 4 decimals · pinned Docker environment · CI on every commit",
        size = 8, col = "#444444")
    txt(500, 98, "any replacement engine must pass the same suite", size = 8,
        face = "italic", col = "#444444")

    popViewport()
}

out_w <- 10
out_h <- 6.4

svg("figures/figure3_implementation_layers.svg", width = out_w, height = out_h)
draw()
invisible(dev.off())

cairo_pdf("figures/figure3_implementation_layers.pdf", width = out_w, height = out_h)
draw()
invisible(dev.off())

cat("wrote figures/figure3_implementation_layers.{svg,pdf}\n")
