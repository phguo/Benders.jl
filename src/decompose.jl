using JuMP
using MathOptInterface
const MOI = MathOptInterface
import GLPK

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

    # Copy variable informations.
    # for var in all_variables(original_model)
    #     if has_lower_bound(var)
    #         set_lower_bound(reference_map[var], lower_bound(var))
    #     end
    #     if has_upper_bound(var)
    #         set_upper_bound(reference_map[var], upper_bound(var))
    #     end
    #     if is_integer(var)
    #         set_integer(reference_map[var])
    #     end
    #     if is_binary(var)
    #         set_binary(reference_map[var])
    #     end
    # end
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

    # TODO: dual

    return sub_model, reference_map
end

function optimality_cut()
    # TODO
    return
end

function feasibility_cut()
    # TODO
    return
end

function benders(model::Model)
    master_model, master_ref_map = identify_master_model(model)
    optimize!(master_model)
    @show solution_summary(master_model)
    master_var_vals = Dict(name(var)=>value(var) for var in all_variables(master_model) if occursin(MASTER_KW, name(var)))
    
    sub_model, sub_ref_map = identify_sub_model(model, master_var_vals)
    optimize!(sub_model)
    @show solution_summary(sub_model)
    return 
end

function cb_benders(original_mdoel::Model)
    return
end

include("problem.jl")
benders(original_model())
