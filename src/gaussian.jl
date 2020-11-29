
@doc raw"""
    Kernels.Gaussian(fwhm; maxsize=3)
    Kernels.Gaussian(position, fwhm; maxsize=3)
    Kernels.Gaussian(x, y, fwhm; maxsize=3)
    Kernels.Gaussian(::Polar, fwhm; maxsize=3, origin=(0, 0))
    Kernels.Gaussian{T}(args...; kwargs...)

An unnormalized bivariate Gaussian distribution. The position can be specified in `(x, y)` coordinates as a `Tuple`, `AbstractVector`, or as separate arguments. By default the kernel is placed at the origin. The position can also be given as a `CoordinateTransformations.Polar`, optionally centered around `origin`.

The `fwhm` can be a scalar (isotropic), vector/tuple (diagonal), or a matrix (correlated). For efficient calculations, we recommend using [StaticArrys](https://github.com/JuliaArrays/StaticArrays.jl). Here, `maxsize` is a multiple of the fwhm, and can be given as a scalar or as a tuple for each axis.

The output type can be specified, and will default to `Float64`. The amplitude is unnormalized, meaning the maximum value will always be 1. This is distinct from the probability distribution (pdf) of a bivariate Gaussian which assures the kernel *sums* to 1. This means the kernels act like a transmission weighting instead of a probability weighting.

# Functional form
```
f(x | x̂, FWHM) = exp[-4ln(2) * ||x - x̂|| / FWHM^2]
```
where `x̂` and `x` are position vectors (indices) `||⋅||` represents the square-distance, and `FWHM` is the full width at half-maximum. If `FWHM` is a vector or tuple, the weighting is applied along each axis.

If the `FWHM` is a correlated matrix, the functional form uses the square-Mahalanobis distance
```
f(x | x̂, Q) = exp[-4ln(2) * (x - x̂)ᵀ Q (x - x̂)]
```
where `Q` is the inverse covariance matrix (or precision matrix). This is equivalent to the inverse of the FWHM matrix after squaring each element.
"""
struct Gaussian{T,FT,VT<:AbstractVector,IT<:Tuple} <: PSFKernel{T}
pos::VT
fwhm::FT
indices::IT

Gaussian{T}(pos::VT, fwhm::FT, indices::IT) where {T,VT<:AbstractVector,FT,IT<:Tuple} = new{T,FT,VT,IT}(pos, fwhm, indices)
end

## constructors
# default type is Float64
Gaussian(args...; kwargs...) = Gaussian{Float64}(args...; kwargs...)
# parse indices from maxsize
Gaussian{T}(pos::AbstractVector, fwhm; maxsize=3) where {T} = Gaussian{T}(pos, fwhm, indices_from_extent(pos, fwhm, maxsize))
# default position is [0, 0]
Gaussian{T}(fwhm; kwargs...) where {T} = Gaussian{T}(SA[0, 0], fwhm; kwargs...)
# # parse position to vector
Gaussian{T}(x::Number, y::Number, fwhm; kwargs...) where {T} = Gaussian{T}(SA[x, y], fwhm; kwargs...)
Gaussian{T}(xy::Tuple, fwhm; kwargs...) where {T} = Gaussian{T}(SVector(xy), fwhm; kwargs...)
# # translate polar coordinates to cartesian, optionally recentering
Gaussian{T}(p::Polar, fwhm; origin=SA[0, 0], kwargs...) where {T} = Gaussian{T}(CartesianFromPolar()(p) .+ origin, fwhm; kwargs...)

Base.size(g::Gaussian) = map(length, g.indices)
Base.axes(g::Gaussian) = g.indices

# fallback, also covers scalar case
function Base.getindex(g::Gaussian{T}, idx::Vararg{<:Integer,2}) where T
Δ = sqeuclidean(SVector(idx), g.pos)
val = exp(-4 * log(2) * Δ / g.fwhm^2)
return convert(T, val)
end
# vector case
function Base.getindex(g::Gaussian{T,<:Union{Tuple,AbstractVector}}, idx::Vararg{<:Integer,2}) where T
weights = SA[1/first(g.fwhm)^2, 1/last(g.fwhm)^2] # manually invert
Δ = wsqeuclidean(SVector(idx), g.pos, weights)
val = exp(-4 * log(2) * Δ)
return convert(T, val)
end

# matrix case
function Base.getindex(g::Gaussian{T,<:AbstractMatrix}, idx::Vararg{<:Integer,2}) where T
R = SVector(idx) - g.pos
Δ = R' * ((g.fwhm .^2) \ R)
val = exp(-4 * log(2) * Δ)
return convert(T, val)
end

# Alias Normal -> Gaussian

"""
Kernels.Normal

An alias for [`Kernels.Gaussian`](@ref)
"""
const Normal = Gaussian

