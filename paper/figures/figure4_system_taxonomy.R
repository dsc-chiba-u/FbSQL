# Figure 4 (SQL-ML system taxonomy): the three groups of the Related Work
# section — in-database SQL-ML, SQL-on-engine ML, SQL-adjacent ML — with
# each system's invocation surface and model residence. A typology, not a
# ranking.
#
# Same style/palette as figure1_system_overview.R. Regenerate with:
#   docker run --rm -u "$(id -u):$(id -g)" -v "$PWD":/paper -w /paper \
#       fbsql-paper Rscript figures/figure4_system_taxonomy.R
# Caption lives in paper/paper.Rmd (fig.cap of the figure4 chunk).

library(grid)

col_lang_fill  <- "#F0F5FB"
col_lang_line  <- "#4477AA"
col_impl_fill  <- "#F5F5F5"
col_impl_line  <- "#999999"
col_box_fill   <- "#FFFFFF"
col_box_line   <- "#4477AA"
col_model_line <- "#CC7722"
col_note       <- "#666666"

draw <- function() {
    grid.newpage()
    pushViewport(viewport(xscale = c(0, 1000), yscale = c(0, 540)))

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
    card <- function(x0, y0, x1, y1, name, line1, line2, border = col_box_line,
                     lwd = 1) {
        box(x0, y0, x1, y1, col_box_fill, border, lwd = lwd)
        cx <- (x0 + x1) / 2
        txt(cx, y1 - 22, name, size = 9.5, face = "bold")
        txt(cx, y1 - 46, line1, size = 8)
        txt(cx, y1 - 66, line2, size = 8, col = col_note)
    }

    ## group 1: in-database SQL-ML
    box(30, 60, 340, 500, col_lang_fill, col_lang_line, lwd = 1.4)
    txt(185, 478, "In-database SQL-ML", size = 11, face = "bold", col = col_lang_line)
    txt(185, 456, "ML runs inside the DBMS,\ncalled as SQL functions", size = 8,
        col = col_lang_line)
    card(55, 315, 315, 405, "FbSQL (this paper)",
         "set-returning SQL functions",
         "model = a relation", border = col_model_line, lwd = 2)
    card(55, 200, 315, 290, "Apache MADlib",
         "procedure-style SQL calls",
         "model = side-effect tables")
    card(55, 85, 315, 175, "PostgresML",
         "task + algorithm SQL API",
         "model = binary in catalogs")

    ## group 2: SQL-on-engine ML
    box(360, 60, 670, 500, col_impl_fill, col_impl_line, lwd = 1.4)
    txt(515, 478, "SQL-on-engine ML", size = 11, face = "bold", col = "#555555")
    txt(515, 456, "SQL defines relations on a query\nengine; ML lives beside the SQL", size = 8,
        col = "#555555")
    card(385, 315, 645, 405, "Spark MLlib",
         "RFormula + DataFrame / Pipeline",
         "model = host-language object", border = col_impl_line)
    card(385, 200, 645, 290, "Apache Hivemall",
         "UDFs inside HiveQL",
         "model = (feature, weight) table", border = col_impl_line)

    ## group 3: SQL-adjacent ML
    box(690, 60, 970, 500, col_impl_fill, col_impl_line, lwd = 1.4, lty = "dashed")
    txt(830, 478, "SQL-adjacent ML", size = 11, face = "bold", col = "#555555")
    txt(830, 456, "reached from SQL only by\nconverting the data out", size = 8,
        col = "#555555")
    card(715, 315, 945, 405, "H2O-3 + Sparkling Water",
         "DataFrame → H2OFrame",
         "model = binary in ML cluster", border = col_impl_line)

    ## footnote
    txt(500, 25, "grouped by where the modeling computation lives relative to the SQL language — a typology, not a ranking",
        size = 8.5, face = "italic", col = col_note)

    popViewport()
}

out_w <- 10
out_h <- 5.4

svg("figures/figure4_system_taxonomy.svg", width = out_w, height = out_h)
draw()
invisible(dev.off())

cairo_pdf("figures/figure4_system_taxonomy.pdf", width = out_w, height = out_h)
draw()
invisible(dev.off())

cat("wrote figures/figure4_system_taxonomy.{svg,pdf}\n")
