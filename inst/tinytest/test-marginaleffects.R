source("helpers.R")
using("marginaleffects")


# marginal effects at the mean
mod <- glm(am ~ hp + mpg, data = mtcars, family = binomial)
mfx1 <- slopes(mod, newdata = datagrid())
mfx2 <- slopes(mod, newdata = "mean")
expect_equivalent(mfx1, mfx2)



# unsupported arguments
mod <- glm(am ~ hp + mpg, data = mtcars, family = binomial)
expect_error(slopes(mod, contrast_numeric = "sd"), pattern = "supported")
expect_error(slopes(mod, contrast_factor = "pairwise"), pattern = "supported")
expect_error(slopes(mod, transform_pre = mean), pattern = "supported")
expect_error(slopes(mod, transform_post = exp), pattern = "supported")
expect_error(slopes(mod, cross = TRUE), pattern = "supported")

