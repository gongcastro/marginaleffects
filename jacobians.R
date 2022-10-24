Q
pkgload::load_all()

mod <- lm(mpg ~ hp + am, mtcars)

cmp <- comparisons(mod)

J1 <- attr(cmp, "jacobian_linear")
J2 <- attr(cmp, "jacobian")

tinytest::

head(lo)

mm_lo <- insight::get_modelmatrix(model, data = lo)
mm_hi <- insight::get_modelmatrix(model, data = hi)
J <- mm_hi - mm_lo

head(hi)

model
