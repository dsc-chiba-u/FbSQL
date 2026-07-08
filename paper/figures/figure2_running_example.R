# Figure 2 (running example): one customer relation feeds fitting (2025
# cohort) and scoring (2026 cohort); the fitted churn model travels between
# the two functions as an ordinary relation.
#
# Same style/palette as figure1_system_overview.R. Regenerate with:
#   docker run --rm -u "$(id -u):$(id -g)" -v "$PWD":/paper -w /paper \
#       fbsql-paper Rscript figures/figure2_running_example.R
# Caption lives in paper/paper.Rmd (fig.cap of the figure2 chunk).

library(grid)

col_lang_line  <- "#4477AA"
col_box_fill   <- "#FFFFFF"
col_box_line   <- "#4477AA"
col_model_fill <- "#FFF7E6"
col_model_line <- "#CC7722"
col_arrow      <- "#333333"
col_note       <- "#666666"

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

    ## customer relation (single source, top center)
    box(360, 540, 640, 625, col_box_fill, col_box_line, lwd = 1.6)
    txt(500, 600, "customer relation", size = 11, face = "bold")
    txt(500, 576, "customer_id · created_at · age · gender · churn_flag", size = 8)
    txt(500, 556, "12 rows in 2025 · 5 rows in 2026", size = 8, col = col_note)

    ## fit_glm (left)
    box(60, 330, 320, 455, col_box_fill, col_box_line, lwd = 1.4)
    txt(190, 432, "fit_glm()", size = 10.5, face = "bold")
    txt(190, 406, "formula =>", size = 8)
    txt(190, 388, "'churn_flag ~ age + gender'", size = 8.5, face = "bold")
    txt(190, 364, "family => 'binomial'", size = 8)
    txt(190, 344, "relation => 2025 rows", size = 8)

    ## predict_glm (right)
    box(680, 330, 940, 455, col_box_fill, col_box_line, lwd = 1.4)
    txt(810, 432, "predict_glm()", size = 10.5, face = "bold")
    txt(810, 406, "relation => 2026 rows", size = 8)
    txt(810, 384, "model => model relation", size = 8)
    txt(810, 360, "on_new_levels => 'error' | 'na'", size = 8)

    ## model relation (center, emphasized)
    box(380, 295, 620, 480, col_model_fill, col_model_line, lwd = 2.4, r = 0.04)
    txt(500, 458, "Model relation", size = 11.5, face = "bold", col = "#7A4A00")
    grid.segments(unit(394, "native"), unit(442, "native"),
                  unit(606, "native"), unit(442, "native"),
                  gp = gpar(col = col_model_line, lwd = 0.8))
    txt(500, 424, "(Intercept) · age ·", size = 8.5)
    txt(500, 406, "genderM · genderOther", size = 8.5)
    box(394, 352, 606, 384, "#FDEBD0", col_model_line, lwd = 0.8, r = 0.15)
    txt(500, 368, "metadata: xlevels · contrasts · terms", size = 8)
    txt(500, 322, "the only state fitting\nhands to prediction", size = 8,
        face = "italic", col = "#7A4A00")

    ## cohort arrows out of customer
    arr(415, 538, 215, 458)
    txt(230, 515, "2025 rows", size = 8.5, face = "bold")
    txt(230, 498, "churn_flag observed", size = 8, col = col_note)
    arr(585, 538, 785, 458)
    txt(770, 515, "2026 rows", size = 8.5, face = "bold")
    txt(770, 498, "churn_flag unknown", size = 8, col = col_note)

    ## fit -> model -> predict
    arr(322, 388, 378, 388, col = col_model_line)
    arr(622, 388, 678, 388, col = col_model_line)

    ## predict -> prediction relation
    arr(810, 328, 810, 245)
    box(680, 130, 940, 243, col_box_fill, col_box_line, lwd = 1.6)
    txt(810, 218, "Prediction relation", size = 11, face = "bold")
    txt(810, 192, "customer_id · … ·", size = 8.5)
    txt(810, 174, "churn_flag_predicted", size = 8.5, face = "bold")
    txt(810, 150, "same rows as the 2026 input", size = 8, col = col_note)

    ## edge-case note (small, unobtrusive)
    box(80, 130, 600, 235, NA, "#BBBBBB", lwd = 0.8, lty = "dashed", r = 0.08)
    txt(100, 212, "Edge rows stay inside SQL semantics:", size = 8.5,
        face = "italic", col = col_note, just = "left")
    txt(100, 188, "c104  NULL age  →  row kept, NULL prediction", size = 8,
        col = col_note, just = "left")
    txt(100, 166, "c105  unseen gender 'Nonbinary'  →  error (default)", size = 8,
        col = col_note, just = "left")
    txt(100, 146, "or NULL for that row with on_new_levels => 'na'", size = 8,
        col = col_note, just = "left")

    popViewport()
}

out_w <- 10
out_h <- 6.4

svg("figures/figure2_running_example.svg", width = out_w, height = out_h)
draw()
invisible(dev.off())

cairo_pdf("figures/figure2_running_example.pdf", width = out_w, height = out_h)
draw()
invisible(dev.off())

cat("wrote figures/figure2_running_example.{svg,pdf}\n")
