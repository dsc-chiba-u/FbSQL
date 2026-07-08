# Figure 1 (system overview): FbSQL is the language; the PostgreSQL
# extension is its (replaceable) reference implementation; the model
# relation is the central artifact.
#
# Vector outputs (SVG + PDF) are generated from this one source:
#   docker run --rm -u "$(id -u):$(id -g)" -v "$PWD":/paper -w /paper \
#       fbsql-paper Rscript figures/figure1_system_overview.R
# A hand-editable draw.io source with the same layout is kept alongside
# (figure1_system_overview.drawio).
# Caption lives in paper/paper.Rmd (fig.cap of the fig1 chunk).

library(grid)

col_lang_fill <- "#F0F5FB"
col_lang_line <- "#4477AA"
col_impl_fill <- "#F5F5F5"
col_impl_line <- "#999999"
col_box_fill  <- "#FFFFFF"
col_box_line  <- "#4477AA"
col_model_fill <- "#FFF7E6"
col_model_line <- "#CC7722"
col_meta_fill <- "#FDEBD0"
col_arrow    <- "#333333"
col_dashed   <- "#888888"

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

    ## ---- language layer -------------------------------------------------
    box(15, 210, 985, 630, col_lang_fill, col_lang_line, lwd = 1.6)
    txt(30, 608, "FbSQL — the language", size = 12, face = "bold",
        col = col_lang_line, just = "left")
    txt(30, 588, "what the user writes and what is guaranteed; every arrow is a relation",
        size = 8.5, col = col_lang_line, just = "left")

    ## training relation
    box(35, 430, 175, 505, col_box_fill, col_box_line)
    txt(105, 480, "Training relation", size = 9.5, face = "bold")
    txt(105, 458, "any SQL query", size = 8)

    ## fit_glm
    box(215, 430, 345, 505, col_box_fill, col_box_line, lwd = 1.4)
    txt(280, 482, "fit_glm()", size = 10.5, face = "bold")
    txt(280, 460, "formula, family", size = 8)
    txt(280, 522, "'churn_flag ~ age + gender'", size = 8, col = "#555555")

    ## model relation (central, table-like)
    box(385, 350, 625, 545, col_model_fill, col_model_line, lwd = 2.4, r = 0.03)
    txt(505, 524, "Model relation", size = 11.5, face = "bold", col = "#7A4A00")
    grid.segments(unit(397, "native"), unit(508, "native"),
                  unit(613, "native"), unit(508, "native"),
                  gp = gpar(col = col_model_line, lwd = 0.8))
    txt(400, 492, "term            estimate   …   aic", size = 8,
        face = "bold", just = "left")
    txt(400, 472, "(Intercept)     −12.11    …", size = 8, just = "left")
    txt(400, 454, "age               0.30       …", size = 8, just = "left")
    txt(400, 436, "genderM        −0.43     …", size = 8, just = "left")
    box(395, 388, 615, 418, col_meta_fill, col_model_line, lwd = 0.8, r = 0.15)
    txt(505, 403, "metadata: xlevels · contrasts · terms", size = 8)
    txt(505, 366, "queryable · joinable · auditable · self-contained",
        size = 8.5, face = "italic", col = "#7A4A00")

    ## scoring relation
    box(665, 545, 805, 610, col_box_fill, col_box_line)
    txt(735, 590, "Scoring relation", size = 9.5, face = "bold")
    txt(735, 568, "any SQL query", size = 8)

    ## predict_glm
    box(665, 430, 805, 505, col_box_fill, col_box_line, lwd = 1.4)
    txt(735, 482, "predict_glm()", size = 10.5, face = "bold")
    txt(735, 460, "on_new_levels", size = 8)

    ## prediction relation
    box(845, 430, 975, 505, col_box_fill, col_box_line)
    txt(910, 486, "Prediction", size = 9.5, face = "bold")
    txt(910, 470, "relation", size = 9.5, face = "bold")
    txt(910, 450, "+ <response>_predicted", size = 7.5)

    ## flows within the language layer
    arr(175, 468, 213, 468)                       # training -> fit
    arr(345, 468, 383, 468, col = col_model_line) # fit -> model
    arr(625, 468, 663, 468, col = col_model_line) # model -> predict
    arr(735, 543, 735, 507)                       # scoring -> predict
    arr(805, 468, 843, 468)                       # predict -> prediction

    ## ---- implementation layer -------------------------------------------
    box(15, 20, 985, 170, col_impl_fill, col_impl_line, lwd = 1.2, lty = "dashed")
    txt(30, 148, "Reference implementation — PostgreSQL extension",
        size = 10.5, face = "bold", col = "#555555", just = "left")
    txt(30, 128, "replaceable engine: the SQL above never changes",
        size = 8.5, col = "#555555", just = "left")

    box(215, 40, 400, 110, col_box_fill, col_impl_line)
    txt(307, 88, "PL/R → stats::glm()", size = 9.5, face = "bold", col = "#444444")
    txt(307, 64, "fitting engine (R as oracle)", size = 8, col = "#666666")

    box(620, 40, 850, 110, col_box_fill, col_impl_line)
    txt(735, 88, "PL/pgSQL — no R", size = 9.5, face = "bold", col = "#444444")
    txt(735, 64, "predicts from the model relation alone", size = 8, col = "#666666")

    txt(510, 78, "future engines:\nC · GPU · distributed", size = 8.5,
        face = "italic", col = "#666666")

    ## language / engine boundary connectors
    arr(280, 428, 307, 112, col = col_dashed, lty = "dashed", lwd = 1)
    arr(735, 428, 735, 112, col = col_dashed, lty = "dashed", lwd = 1)
    txt(970, 190, "language / engine boundary", size = 8, face = "italic",
        col = "#888888", just = "right")

    popViewport()
}

out_w <- 10
out_h <- 6.4

svg("figures/figure1_system_overview.svg", width = out_w, height = out_h)
draw()
invisible(dev.off())

cairo_pdf("figures/figure1_system_overview.pdf", width = out_w, height = out_h)
draw()
invisible(dev.off())

cat("wrote figures/figure1_system_overview.{svg,pdf}\n")
