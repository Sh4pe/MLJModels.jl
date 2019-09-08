## FUNCTIONS TO INSPECT METADATA OF REGISTERED MODELS AND TO
## FACILITATE MODEL SEARCH

is_supervised(::Type{<:Supervised}) = true
is_supervised(::Type{<:Unsupervised}) = false

supervised_propertynames = sort(MLJBase.SUPERVISED_TRAITS)
alpha = [:name, :package_name, :is_supervised]
omega = [:input_scitype, :target_scitype]
both = vcat(alpha, omega)
filter!(!in(both), supervised_propertynames) 
prepend!(supervised_propertynames, alpha)
append!(supervised_propertynames, omega)
const SUPERVISED_PROPERTYNAMES = Tuple(supervised_propertynames)

unsupervised_propertynames = sort(MLJBase.UNSUPERVISED_TRAITS)
alpha = [:name, :package_name, :is_supervised]
omega = [:input_scitype, :output_scitype]
both = vcat(alpha, omega)
filter!(!in(both), unsupervised_propertynames) 
prepend!(unsupervised_propertynames, alpha)
append!(unsupervised_propertynames, omega)
const UNSUPERVISED_PROPERTYNAMES = Tuple(unsupervised_propertynames)

ModelProxy = Union{NamedTuple{SUPERVISED_PROPERTYNAMES},
                   NamedTuple{UNSUPERVISED_PROPERTYNAMES}}

function Base.isless(p1::ModelProxy, p2::ModelProxy)
    if isless(p1.name, p2.name)
        return true
    elseif p1.name == p2.name
        return isless(p1.package_name, p2.package_name)
    else
        return false
    end
end

Base.show(stream::IO, p::ModelProxy) =
    print(stream, "(name = $(p.name), package_name = $(p.package_name), "*
          "... )")

function Base.show(stream::IO, ::MIME"text/plain", p::ModelProxy)
    printstyled(IOContext(stream, :color=> MLJBase.SHOW_COLOR),
                    p.docstring, bold=false, color=:magenta)
    println(stream)
    MLJBase.pretty_nt(stream, p)
end

# returns named tuple version of the dictionary i=info(SomeModelType):
function info_as_named_tuple(i) 
    propertynames = ifelse(i[:is_supervised], SUPERVISED_PROPERTYNAMES,
                           UNSUPERVISED_PROPERTYNAMES)
    propertyvalues = Tuple(i[property] for property in propertynames)
    return NamedTuple{propertynames}(propertyvalues)
end

MLJBase.traits(handle::Handle) = info_as_named_tuple(INFO_GIVEN_HANDLE[handle])
    
"""
    traits(name::String; pkg=nothing)

Returns the metadata for the registered model type with specified
`name`. The key-word argument `pkg` is required in the case of
duplicate names.

"""
function MLJBase.traits(name::String; pkg=nothing)
    name in NAMES ||
        throw(ArgumentError("There is no model named \"$name\" in "*
                            "the registry. \n Run `models()` to view all "*
                            "registered models."))
    # get the handle:
    if pkg == nothing
        handle  = Handle(name)
        if ismissing(handle.pkg)
            pkgs = PKGS_GIVEN_NAME[name]
            message = "Ambiguous model name. Use pkg=...\n"*
            "The model $model is provided by these packages: $pkgs.\n"
            throw(ArgumentError(message))
        end
    else
        handle = Handle(name, pkg)
        haskey(INFO_GIVEN_HANDLE, handle) ||
            throw(ArgumentError("$handle does not exist in the registry. \n"*
                  "Use models() to list all models. "))
    end
    return traits(handle)

end


"""
   traits(model::Model)

Return the traits associated with the specified `model`. Equivalent to
`traits(name; pkg=pkg)` where `name::String` is the name of the model type, and
`pkg::String` the name of the package containing it.
 
"""
MLJBase.traits(M::Type{<:Model}) = info_as_named_tuple(MLJBase.info(M))
MLJBase.traits(model::Model) = traits(typeof(model))

"""
    models()

List all models in the MLJ registry. Here and below *model* means the
registry metadata entry for a genuine model type (a proxy for types
whose defining code may not be loaded).

    models(conditions...)

List all models satisifying the specified `conditions`. A *condition*
is any `Bool`-valued function on models.

Excluded in the listings are the built-in model-wraps `EnsembleModel`,
`TunedModel`, and `IteratedModel`.

### Example

If

    task(model) = model.is_supervised && model.is_probabilistic

then `models(task)` lists all supervised models making probabilistic
predictions.

See also: [`localmodels`](@ref).

"""
function models(conditions...)
    unsorted = filter(traits.(keys(INFO_GIVEN_HANDLE))) do model
        all(c(model) for c in conditions)
    end
    return sort!(unsorted)
end

models() = models(x->true)

# function models(task::SupervisedTask)
#     ret = Dict{String, Any}()
#     function condition(t)
#         return t.is_supervised &&
#             task.target_scitype <: t.target_scitype &&
#             task.input_scitype <: t.input_scitype &&
#             task.is_probabilistic == t.is_probabilistic
#     end
#     return models(condition)
# end

# function models(task::UnsupervisedTask)
#     ret = Dict{String, Any}()
#     function condition(handle)
#         t = traits(handle)
#         return task.input_scitype <: t.input_scitype
#     end
#     return models(condition)
# end

"""
    localmodels(; modl=Main)
    localmodels(conditions...; modl=Main)
 

List all models whose names are in the namespace of the specified
module `modl`, additionally solving the `task`, or meeting the
`conditions`, if specified. Here a *condition* is a `Bool`-valued
function on models.

See also [models](@ref)

"""
function localmodels(args...; modl=Main)
    modeltypes = localmodeltypes(modl)
    names = map(modeltypes) do M
        traits(M).name
    end
    return filter(models(args...)) do handle
        handle.name in names
    end
end
