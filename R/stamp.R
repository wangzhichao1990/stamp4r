#' stamp R6 class
#' @description
#' stamp R6 class
#' @details
#' stamp R6 class
#' @export
stamp <- R6Class(
  classname = "stamp",
  public = list(
    #' @field feature_table 一个data.frame或者tibble，用来存储特征矩阵
    #' 第一列是特征列，如基因或者微生物等
    feature_table = NULL,
    #' @field metadata 一个data.frame或者tibble，用来存储分组信息
    #' 第一列是样本列
    metadata = NULL,
    #' @field diff 一个data.frame或者tibble，用来存储差异分析结果
    diff = NULL,
    #' @field diff_features 一个字符向量，用来存储差异特征
    diff_features = NULL,
    #' @field test 差异分析使用的假设检验，默认是wilcox.test
    test = NULL,
    #' @field feature_col 特征列名
    feature_col = NULL,
    #' @field sample_col 样本列名
    sample_col = NULL,
    #' @field group_col 分组列名
    group_col = NULL,

    #' @description
    #' Create a new stamp object.
    #' @param feature_table feature_table.
    #' @param metadata metadata.
    #' @return A new `stamp` object.
    #' @examples
    #' obj <- stamp$new(feature_table = feature_table, metadata = metadata)
    initialize = function(feature_table = NA,
                          metadata = NA) {
      if (!(is.data.frame(feature_table) ||
        tibble::is_tibble(feature_table))) {
        stop("feature_table must \be a data.frame or tibble!")
      }
      if (!(is.data.frame(metadata) ||
        tibble::is_tibble(metadata))) {
        stop("metadata must be a data.frame or tibble!")
      }
      self$feature_table <- feature_table
      self$metadata <- metadata
      self$feature_col <- colnames(feature_table)[[1]]
      self$sample_col <- colnames(metadata)[[1]]
      self$group_col <- colnames(metadata)[[2]]
    },
    #' @description
    #' cal diff
    #' @param test default="wilcox.test" "t.test"
    #' @param p.adjust.method default="fdr"
    #' @return a data.frame or tibble, diff test result
    cal_diff = function(test = "wilcox.test", p.adjust.method = "fdr") {
      self$test <- test
      test <- dplyr::case_match(
        test,
        "wilcox.test" ~ c(wilcox.test),
        "t.test" ~ c(t.test),
      )[[1]]
      res <- self$longdata %>%
        dplyr::group_by(.data[[self$feature_col]]) %>%
        dplyr::group_modify(
          ~ broom::tidy(
            test(
              as.formula(paste0("value ~ ", self$group_col)),
              data = .x,
              conf.int = TRUE
            )
          )
        ) %>%
        dplyr::ungroup() %>%
        dplyr::mutate(p.adjust = p.adjust(p.value,
          method = p.adjust.method
        )) %>%
        dplyr::arrange(p.adjust)
      self$diff <- res
      res
    },
    #' @description
    #' filter diff features
    #' @param p_threshold default=0.05
    #' @return null
    filter_diff_features = function(p_threshold = 0.05) {
      if (is.null(self$diff)) self$cal_diff()
      res <- self$diff %>%
        dplyr::filter(p.adjust <= p_threshold) %>%
        dplyr::pull(.data[[self$feature_col]])
      self$diff_features <- res
      res
    },
    #' @description
    #' plot extended errorbar plot
    #' @return a ggplot2 object
    plot_extended_errorbar = function() {
      if (is.null(self$diff)) self$cal_diff()
      if (is.null(self$diff_features)) self$filter_diff_features()
      if (length(self$diff_features) == 0) stop("no diff features")
      data1 <- self$stats %>%
        dplyr::filter(.data[[self$feature_col]] %in% self$diff_features) %>%
        dplyr::mutate(mean = mean * 100)
      data2 <- self$diff %>%
        dplyr::filter(.data[[self$feature_col]] %in% self$diff_features) %>%
        dplyr::mutate(dplyr::across(
          c(estimate, conf.low, conf.high),
          ~ .x * 100
        ))
      p1 <- ggplot(data1, aes(
        x = .data[[self$feature_col]],
        y = mean, fill = Group
      )) +
        xlab("") +
        ylab("Proportion(%)") +
        scale_x_discrete(limits = levels(factor(data1[[self$feature_col]]))) +
        coord_flip() +
        theme(
          panel.background = element_rect(fill = "transparent"),
          panel.grid = element_blank(),
          axis.ticks.length = unit(0.4, "lines"),
          axis.ticks = element_line(color = "black"),
          axis.line = element_line(colour = "black"),
          axis.title.x = element_text(
            colour = "black",
            size = 12, face = "bold"
          ),
          axis.text = element_text(colour = "black", size = 10, face = "bold"),
          legend.title = element_blank(),
          legend.text = element_text(
            size = 12, face = "bold", colour = "black",
            margin = margin(r = 20)
          ),
          legend.position = "bottom",
          legend.direction = "horizontal",
          legend.key.width = unit(0.8, "cm"),
          legend.key.height = unit(0.5, "cm")
        )
      if (nrow(data1) / 2 > 1) {
        for (i in 1:(nrow(data1) / 2 - 1)) {
          p1 <- p1 + annotate("rect",
            xmin = i + 0.5, xmax = i + 1.5, ymin = -Inf, ymax = Inf,
            fill = ifelse(i %% 2 == 0, "white", "gray95")
          )
        }
      }
      p1 <- p1 + geom_col(
        position = "dodge",
        width = 0.5,
        color = "black"
      ) + scale_fill_manual(values = c("#80B1D3", "#FDB462"))

      p2 <- ggplot(data2, aes(x = Pathway, y = estimate)) +
        theme(
          panel.background = element_rect(fill = "transparent"),
          panel.grid = element_blank(),
          axis.ticks.length = unit(0.4, "lines"),
          axis.ticks = element_line(color = "black"),
          axis.line = element_line(colour = "black"),
          axis.title.x = element_text(
            colour = "black",
            size = 12, face = "bold"
          ),
          axis.text = element_text(
            colour = "black", size = 10,
            face = "bold"
          ),
          axis.text.y = element_blank(),
          legend.position = "none",
          axis.line.y = element_blank(),
          axis.ticks.y = element_blank(),
          plot.title = element_text(
            size = 15,
            face = "bold", colour = "black",
            hjust = 0.5
          )
        ) +
        scale_x_discrete(limits = levels(factor(data2[[self$feature_col]]))) +
        coord_flip() +
        xlab("") +
        ylab("Difference in mean proportions (%)") +
        labs(title = "95% confidence intervals")
      if (nrow(data2) > 1) {
        for (i in 1:(nrow(data2) - 1)) {
          p2 <- p2 + annotate("rect",
            xmin = i + 0.5, xmax = i + 1.5, ymin = -Inf, ymax = Inf,
            fill = ifelse(i %% 2 == 0, "white", "gray95")
          )
        }
      }
      p2 <- p2 + geom_errorbar(aes(ymax = conf.high, ymin = conf.low)) +
        geom_point(color = ifelse(data2$estimate > 0, "#FDB462", "#80B1D3"))


      p3 <- ggplot(data2) +
        geom_text(aes(x = Pathway, y = 0.5),
          label = data2$p.adjust %>% round(3),
          hjust = 0, fontface = "bold", inherit.aes = FALSE, size = 3
        ) +
        geom_text(aes(x = nrow(data2) / 2 + 0.5, y = 0.85),
          label = "p-value(corrected)", srt = 90,
          fontface = "bold", size = 5
        ) +
        theme(
          panel.background = element_blank(),
          panel.grid = element_blank(),
          axis.line = element_blank(),
          axis.ticks = element_blank(),
          axis.text = element_blank(),
          axis.title = element_blank()
        ) +
        coord_flip() +
        ylim(c(0, 1))
      p1 + p2 + p3 + patchwork::plot_layout(width = c(2, 2, 1))
    }
  ),
  active = list(
    #' @field longdata long data
    longdata = function() {
      res <- self$feature_table %>%
        tidyr::pivot_longer(
          -1,
          names_to = self$sample_col,
          values_to = "value"
        ) %>%
        dplyr::left_join(metadata)
      res
    },
    #' @field stats stats
    stats = function() {
      self$longdata %>%
        dplyr::group_by(
          .data[[self$feature_col]],
          .data[[self$group_col]]
        ) %>%
        dplyr::summarise(
          n = dplyr::n(),
          mean = mean(value),
          sd = sd(value),
          se = sd / sqrt(n)
        ) %>%
        dplyr::ungroup()
    }
  )
)
