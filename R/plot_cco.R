#' Plot Conditional Contrasts
#'
#' This function plots contrasts (y-axis) against values of predictor(s)
#' variable(s) (x-axis and colors). This is especially useful in models with
#' interactions, where the values of contrasts depend on the values of
#' "condition" variables.
#'
#' @param effect Name of the variable whose contrast we want to plot on the y-axis
#' @param draw `TRUE` returns a `ggplot2` plot. `FALSE` returns a `data.frame` of the underlying data.
#' @inheritParams comparisons
#' @inheritParams plot_cme
#' @inheritParams slopes
#' @return A `ggplot2` object
#' @family plot
#' @export
#' @examples
#' mod <- lm(mpg ~ hp * drat * factor(am), data = mtcars)
#' 
#' plot_cco(mod, effect = "hp", condition = "drat")
#'
#' plot_cco(mod, effect = "hp", condition = c("drat", "am"))
#' 
#' plot_cco(mod, effect = "hp", condition = list("am", "drat" = 3:5))
#' 
#' plot_cco(mod, effect = "am", condition = list("hp", "drat" = range))
#' 
plot_cco <- function(model,
                     effect = NULL,
                     condition = NULL,
                     type = "response",
                     vcov = NULL,
                     conf_level = 0.95,
                     transform_pre = "difference",
                     transform_post = NULL,
                     draw = TRUE,
                     ...) {


    # sanity check
    if (!isTRUE(length(effect) == 1)) {
        msg <- "The `effect` argument must be a vector or list of length 1."
        insight::format_error(msg)
    }

    # shared code with plot_cco()
    tmp <- get_plot_newdata(model, condition, effect)
    dat <- tmp$modeldata
    nd <- tmp$newdata
    condition <- tmp$condition
    condition1 <- tmp$condition1
    condition2 <- tmp$condition2
    condition3 <- tmp$condition3
    resp <- tmp$resp
    respname <- tmp$respname

    # bad test!
    # plot_cco should actually support a list here as well, since we want to
    # that be passed to the comparisons() variable

    # flag <- checkmate::check_choice(effect, choices = colnames(dat))
    # if (!isTRUE(flag)) {
    #     msg <- "The `effect` argument must be a string representing one of the predictors in the model: %s"
    #     msg <- sprintf(msg, paste(setdiff(colnames(dat), respname), collapse = ", "))
    #     insight::format_error(msg)
    # }

    datplot <- comparisons(
        model,
        newdata = nd,
        type = type,
        vcov = vcov,
        conf_level = conf_level,
        variables = effect,
        transform_pre = transform_pre,
        transform_post = transform_post,
        cross = FALSE,
        ...)

    draws <- attr(datplot, "posterior_draws")
    colnames(datplot)[colnames(datplot) == condition1] <- "condition1"
    colnames(datplot)[colnames(datplot) == condition2] <- "condition2"
    colnames(datplot)[colnames(datplot) == condition3] <- "condition3"

    # colors and linetypes are categorical attributes
    if ("condition2" %in% colnames(datplot)) datplot$condition2 <- factor(datplot$condition2)
    if ("condition3" %in% colnames(datplot)) datplot$condition3 <- factor(datplot$condition3)

    # CIs are automatically added to predictions but (maybe) not marginaleffects output
    if (!"conf.low" %in% colnames(datplot)) {
        alpha <- 1 - conf_level
        datplot$conf.low <- datplot$estimate + stats::qnorm(alpha / 2) * datplot$std.error
        datplot$conf.high <- datplot$estimate - stats::qnorm(alpha / 2) * datplot$std.error
    }

    # shortcut labels
    for (i in seq_along(condition)) {
        v <- paste0("condition", i)
        fun <- function(x, lab) {
            idx <- match(x, sort(unique(x)))
            factor(lab[idx], labels = lab)
        }
        if (identical(condition[[i]], "threenum")) {
            datplot[[v]] <- fun(datplot[[v]], c("-SD", "Mean", "+SD"))
        } else if (identical(condition[[i]], "minmax")) {
            datplot[[v]] <- fun(datplot[[v]], c("Min", "Max"))
        } else if (identical(condition[[i]], "quartile")) {
            datplot[[v]] <- fun(datplot[[v]], c("Q1", "Q2", "Q3"))
        }
    }

    # return immediately if the user doesn't want a plot
    if (isFALSE(draw)) {
        attr(datplot, "posterior_draws") <- draws
        return(datplot)
    } else {
        assert_dependency("ggplot2")
    }

    # ggplot2
    p <- ggplot2::ggplot()

    # continuous x-axis
    if (is.numeric(datplot$condition1)) {
        if ("conf.low" %in% colnames(datplot)) {
             p <- p + ggplot2::geom_ribbon(
                data = datplot,
                alpha = .1,
                ggplot2::aes(
                    x = condition1,
                    y = estimate,
                    ymin = conf.low,
                    ymax = conf.high,
                    fill = condition2))
        }
        p <- p + ggplot2::geom_line(
            data = datplot,
            ggplot2::aes(
                    x = condition1,
                    y = estimate,
                    color = condition2))

    # categorical x-axis
    } else {
        if ("conf.low" %in% colnames(datplot)) {
             if (is.null(condition1)) {
                 p <- p + ggplot2::geom_pointrange(
                     data = datplot,
                     ggplot2::aes(
                        x = condition1,
                        y = estimate,
                        ymin = conf.low,
                        ymax = conf.high,
                        color = condition2))
             } else {
                 p <- p + ggplot2::geom_pointrange(
                    data = datplot,
                    position = ggplot2::position_dodge(.15),
                    ggplot2::aes(
                        x = condition1,
                        y = estimate,
                        ymin = conf.low,
                        ymax = conf.high,
                        color = condition2))
             }
        } else {
            p <- p + ggplot2::geom_point(
                data = datplot,
                ggplot2::aes(
                    x = condition1,
                    y = estimate,
                    color = condition1))
        }
    }

    if (is.null(names(effect))) {
        p <- p + ggplot2::labs(
            x = condition1,
            y = sprintf("Contrast in %s on %s", effect, respname))
    } else {
        p <- p + ggplot2::labs(
            x = condition1,
            y = sprintf("Contrast in %s on %s", names(effect), respname))
    }

    # `effect` is a categorical variable. We plot them in different facets
    contrast_cols <- grep("^contrast$|^contrast_", colnames(datplot), value = TRUE)
    for (con in contrast_cols) {
        if (length(unique(datplot[[con]])) == 1) {
            contrast_cols <- setdiff(contrast_cols, con)
        }
    }
    if (length(contrast_cols) > 0) {
        if (is.null(condition3)) {
            fo <- sprintf("~ %s", paste(contrast_cols, collapse = "+"))
            p <- p + ggplot2::facet_wrap(fo)
        } else {
            fo <- sprintf("condition3 ~ %s", paste(contrast_cols, collapse = "+"))
            p <- p + ggplot2::facet_grid(fo)
        }
    } else if (!is.null(condition3)) {
        fo <- ~ condition3
        p <- p + ggplot2::facet_wrap(fo)
    }

    # set a new theme only if the default is theme_grey. this prevents user's
    # theme_set() from being overwritten
    if (identical(ggplot2::theme_get(), ggplot2::theme_grey())) {
        p <- p +
          ggplot2::theme_minimal() +
          ggplot2::theme(legend.title = ggplot2::element_blank())
    }

    # attach model data for each of use
    attr(p, "modeldata") <- dat

    return(p)
}
