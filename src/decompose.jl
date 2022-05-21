using JuMP
using MathOptInterface
const MOI = MathOptInterface
import GLPK

include("problem.jl")

MASTER_KW = "__M__"
SUB_KW = "__S__"


function __identify_model(original_model, model_key::String)
    # Copy constraints.
    cons_filter(cons::ConstraintRef) = occursin(model_key, name(cons))
    cons_filter(cons::ConstraintRef{Model,<:MOI.ConstraintIndex{MOI.VariableIndex}}) = true
    new_model, reference_map = copy_model(original_model, filter_constraints=cons_filter)
    
    # Copy objective.
    for (coefficient, var) in linear_terms(objective_function(new_model))
        if occursin(model_key, name(var))
            set_objective_coefficient(new_model, var, coefficient)
        else
            set_objective_coefficient(new_model, var, 0)
        end
    end
    drop_zeros!(objective_function(new_model))

    set_optimizer(new_model, GLPK.Optimizer; add_bridges = false)
    # set_optimizer_attributes(new_model, "LogToConsole" => false)
    return new_model, reference_map
end

function identify_master_model(original_model::Model, master_key::String=MASTER_KW)
    master_model, reference_map = __identify_model(original_model, master_key)
    
    # Remove subproblem variables.
    for var in all_variables(original_model)
        if ! occursin(master_key, name(var))
            delete(master_model, reference_map[var])
        end
    end

    # Add an estimator.
    @variable(master_model, θ, lower_bound = 0, base_name = "estimator")
    @objective(master_model, Min, objective_function(master_model) + θ)
    return master_model, reference_map
end

function identify_sub_model(original_model::Model,  master_var_vals::Dict, sub_key::String=SUB_KW)
    sub_model, reference_map = __identify_model(original_model, sub_key)

    # Fix master problem varialbe values.
    for (var_name, var_value) in master_var_vals
        fix(variable_by_name(sub_model, var_name), var_value; force = true)
    end
    relax_integrality(sub_model)

    return sub_model, reference_map
end

function get_dual_sub_model(sub_model::Model)
    # TODO
    dual_sub_model = NaN
    return dual_sub_model
end
