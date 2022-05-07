using JuMP
import Gurobi

function identify_sub_model(original_model::Model, master_val_vals::Dict)
    sub_model = 0
    return sub_model
end

function identify_master_model(original_model::Model, master_key::String="__M__")
    cons_filter(cons::ConstraintRef) = occursin(master_key, name(cons))
    master_model, reference_map = copy_model(original_model, filter_constraints=cons_filter)
    for (coefficient, var) in linear_terms(objective_function(master_model))
        if occursin(master_key, name(var))
            set_objective_coefficient(master_model, var, coefficient)
        else
            set_objective_coefficient(master_model, var, 0)
        end
    end
    drop_zeros!(objective_function(master_model))
    for var in all_variables(original_model)
        if has_lower_bound(var)
            set_lower_bound(reference_map[var], lower_bound(var))
        end
        if has_upper_bound(var)
            set_upper_bound(reference_map[var], upper_bound(var))
        end
        if is_integer(var)
            set_integer(reference_map[var])
        end
        if is_binary(var)
            set_binary(reference_map[var])
        end
        if ! occursin(master_key, name(var))
            delete(master_model, reference_map[var])
        end
    end
    set_optimizer(master_model, Gurobi.Optimizer; add_bridges = false)
    # set_optimizer_attributes(master_model, "LogToConsole" => false)
    return master_model
end

function optimality_cut()
    return
end

function feasibility_cut()
    return
end

function benders(model::Model)
    master_model = identify_master_model(model)
    optimize!(master_model)
    solution_summary(master_model)
    return master_model
end

function cb_benders(original_mdoel::Model)
    return
end

include("problem.jl")
benders(original_model())
