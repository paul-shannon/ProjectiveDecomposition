# Two draft S4 classes for Max
#------------------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------------------
# Diagonal scaling is a standard term for what method "upscale" does; I'm adopting it for the associated data object.
# "downscale" is upscaling by the inverse, without having to explicitly represent the inverse; if "upscale" is a
# multiplication, "downscale" is the corresponding division.
#
.DiagonalScaling <- setClass ("DiagonalScaling",
                            slots = c(colFactor="numeric",
                                      rowFactor="numeric")
                  )
setGeneric("show",         signature="obj", function(obj) standardGeneric("show"))
setGeneric("getColFactor", signature="obj", function(obj) standardGeneric("getColFactor"))
setGeneric("getRowFactor", signature="obj", function(obj) standardGeneric("getRowFactor"))
setGeneric("upscale",      signature="obj", function(obj) standardGeneric("getColFactor"))
setGeneric("downscale",    signature="obj", function(obj) standardGeneric("getRowFactor"))
#setGeneric("t") -- base::t is already a generic function
setGeneric("inverse")

#------------------------------------------------------------------------------------------------------------------------
setMethod("show", "DiagonalScaling",
      function(obj, ...){
          cat(sprintf("Diagonal Scaling object of dimension (%d x %d)\n",
                        length(obj@rowFactor), length(obj@colFactor)))
          })

#------------------------------------------------------------------------------------------------------------------------
setMethod("getColFactor", "DiagonalScaling",
      function(obj){
          obj@colFactor
          })

#------------------------------------------------------------------------------------------------------------------------
setMethod("getRowFactor", "DiagonalScaling",
function(obj){
    obj@rowFactor
})

#------------------------------------------------------------------------------------------------------------------------
setMethod("t", "DiagonalScaling",
function(obj) {
  .DiagonalScaling(colFactor = obj@rowFactor, rowFactor = obj@colFactor)
})

#------------------------------------------------------------------------------------------------------------------------
setMethod("inverse", "default",
function(obj) {
    stop("Objects are not in general invertible")
})

setMethod("inverse", "DiagonalScaling",
function(obj) {
  .DiagonalScaling(colFactor = 1.0 / obj@colFactor, rowFactor = 1.0 / obj@rowFactor)
})

#------------------------------------------------------------------------------------------------------------------------
# Return the (matrix) class we are given, whether it is an S4 class or not.
#
upscale.matrix <- function(obj, matrix) {
    matrix * obj@rowFactor[row(matrix)] * obj@colFactor[col(matrix)]
}
           
upscale.dMatrix <- function(obj, matrix) {
    matrix@x * obj@rowFactor[row(matrix)] * obj@colFactor[col(matrix)]
}
           
setMethod("upscale", "DiagonalScaling",
      function(obj, matrix){
              if (is(matrix,"dMatrix")) {
                  upscale.matrix(obj,matrix)
              } else {
                  upscale.dMatrix(obj,matrix)
              }
          })

#------------------------------------------------------------------------------------------------------------------------
# Return the (matrix) class we are given, whether it is an S4 class or not.
#
downscale.matrix <- function(obj, matrix) {
    matrix / (obj@rowFactor[row(matrix)] * obj@colFactor[col(matrix)])
}
           
downscale.dMatrix <- function(obj, matrix) {
    matrix@x / (obj@rowFactor[row(matrix)] * obj@colFactor[col(matrix)])
}
           
setMethod("downscale", "DiagonalScaling",
      function(obj, matrix){
              if (is(matrix,"dMatrix")) {
                  downscale.matrix(obj,matrix)
              } else {
                  downscale.dMatrix(obj,matrix)
              }
          })

#------------------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------------------
# ScaleDecomposition:
#
# An application area for diagonal scalings. It is _not_ standard to separate the magnitude out from the
# rest of a diagonal scaling, however for purposes of decomposition of a matrix into different scaling factors,
# and especially for data normalization, it is a useful thing to do. Note that many, if not most, data normalization
# methods do not only involve scalings, so it wouldn't be appropriate to call this class (something)Normalization.
#
# Likewise, most matrix decompositions are not limited to scaling.
#------------------------------------------------------------------------------------------------------------------------
.ScaleDecomposition <- setClass ("ScaleDecomposition",
                                 slots = c(canonicalForm = "dMatrix",
                                           magnitude     = "numeric",
                                           scaling       = "DiagonalScaling")
                                   )
#------------------------------------------------------------------------------------------------------------------------
setMethod("getCanonicalForm", "ScaleDecomposition",
      function(obj){
          obj@canonicalForm
          })

#------------------------------------------------------------------------------------------------------------------------
setMethod("getMagnitude", "ScaleDecomposition",
      function(obj){
          obj@magnitude
          })

#------------------------------------------------------------------------------------------------------------------------
setMethod("getScaling", "ScaleDecomposition",
      function(obj){
          obj@scaling
          })

#------------------------------------------------------------------------------------------------------------------------
setMethod("t", "ScaleDecomposition",
function(obj){
    .ScalingDecomposition(
        canonicalForm = t(obj@canonicalForm),
        magnitude     = obj@magnitude,
        scaling       = t(obj@scaling))
})

#------------------------------------------------------------------------------------------------------------------------
# Method "inverse" was defined generic in class DiagonalScaling.
setMethod("inverse", "ScaleDecomposition",
function(obj){
    .ScalingDecomposition(
        canonicalForm = upscale(obj@scale * obj@canonicalForm, obj@scaling),
        magnitude     = 1/obj@magnitude,
        scaling       = inverse(obj@scaling))
})

#------------------------------------------------------------------------------------------------------------------------
RMS <- function(obj) { sqrt(mean(as.numeric(obj))) }

#------------------------------------------------------------------------------------------------------------------------
# Projective Decomposition (an L2-based scaling)
# This gets the magnitude part right, but doesn't do the row and column scalings
# Satisfies the criterion: RMS(row) = RMS(col) = 1.0.
setMethod("projectiveDecomposition", "ScaleDecomposition",
           function(matrix) { # Must be a real-valued matrix, broadest virtual class is Matrix::dMatrix
               scale <- RMS(matrix)
               .ScalingDecomposition(canonicalForm = (1/scale) * matrix,
                                     magnitude     = scale,
                                     scaling       = .DiagonalScaling(
                                                         colFactor = rep(1.0,dim(matrix)[2],
                                                         rowFactor = rep(1.0,dim(matrix)[1])))
} # projectiveDecomposition

#------------------------------------------------------------------------------------------------------------------------
# Doubly-Stochastic Decomposition (L1-based scaling, defined for some non-negative matrices)
# A version of Sinkhorn's algorithm computes the following decomposition.
# This gets the magnitude part right, but doesn't do the row and column scalings
# Unscaled matrix satisfies the criteria, for all rows and columns:
#    sum(row) = length(row)
#    sum(col) = length(col)
setMethod("doublyStochasticDecomposition", "ScaleDecomposition",
           function(matrix) { # Must be a real-valued matrix, broadest virtual class is Matrix::dMatrix
               scale <- sum(matrix)/prod(dim(matrix))
               .ScalingDecomposition(canonicalForm = (1/scale) * matrix,
                                     magnitude     = scale,
                                     scaling       = .DiagonalScaling(
                                                         colFactor = rep(1.0,dim(matrix)[2],
                                                         rowFactor = rep(1.0,dim(matrix)[1])))
} # doublyStochasticDecomposition

#------------------------------------------------------------------------------------------------------------------------