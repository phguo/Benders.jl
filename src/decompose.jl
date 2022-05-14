using JuMP
using MathOptInterface
const MOI = MathOptInterface
import GLPK

include("problem.jl")

MASTER_KW = "__M__"
SUB_KW = "__S__"
MAX_ITERATIONS = 50
OPTIMALITY_GAP = 0.001

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

function add_optimality_cut(master_model::Model, extreme_point::Array{Float64})
    θ = variable_by_name(master_model, "estimator")
    y = [variable_by_name(master_model, "__M__var[$i]") for i in 1:length(f)]
    @constraint(master_model, θ .>= transpose(extreme_point) * (d - B * y), base_name = "__M__optimality_cut")
    return master_model
end

function add_feasibility_cut(master_model::Model, extreme_ray::Array{Float64})
    y = [variable_by_name(master_model, "__M__var[$i]") for i in 1:length(f)]
    @constraint(master_model, 0 .>= transpose(extreme_ray) * (d - B * y), base_name = "__M__optimality_cut")
    return master_model
end

function benders(model::Model)
    master_model, master_ref_map = identify_master_model(model)
    optimize!(master_model)
    master_var_vals = Dict(name(var)=>value(var) for var in all_variables(master_model) if occursin(MASTER_KW, name(var)))
    
    sub_model, sub_ref_map = identify_sub_model(model, master_var_vals)
    optimize!(sub_model)

    for i in 1:MAX_ITERATIONS
        optimize!(master_model)

        if termination_status(master_model) == OPTIMAL
            master_var_vals = Dict(name(var)=>value(var) for var in all_variables(master_model) if occursin(MASTER_KW, name(var)))
            sub_model, sub_ref_map = identify_sub_model(model, master_var_vals)
            optimize!(sub_model)

            if termination_status(sub_model) == OPTIMAL
                upper_bound = objective_value(master_model) - value(variable_by_name(master_model, "estimator")) + objective_value(sub_model)
                lower_bound = objective_value(master_model)
                gap = (upper_bound - lower_bound) / lower_bound
                @show upper_bound, lower_bound, gap
                if gap > OPTIMALITY_GAP
                    extreme_point = Float64[]
                    for cons in all_constraints(sub_model, AffExpr, MOI.EqualTo{Float64})
                        push!(extreme_point, dual(cons))
                    end
                    print("Optimal sub_model -> add optimality cut.\n")
                    master_model = add_optimality_cut(master_model, extreme_point)
                else
                    break
                end
            elseif termination_status(sub_model) == INFEASIBLE
                extreme_ray = Float64[]
                for cons in all_constraints(sub_model, AffExpr, MOI.EqualTo{Float64})
                    push!(extreme_ray, dual(cons))
                end
                print("Infeasible sub_model -> add feasibility cut.\n")
                master_model = add_feasibility_cut(master_model, extreme_ray)
            else
                print("Unexpected sub_model status.\n")
            end
        
        elseif termination_status(master_model) == INFEASIBLE
            print("Infeasible master_model")
            break
        else
            print(termination_status(master_model), "\n")
            print("Unexpected master_model status.\n")
        end
    end
    
    return master_model, sub_model
end

function cb_benders(original_mdoel::Model)
    return
end

o_model, f, c, A, b, B, D, d = original_model()
benders(o_model)

set_optimizer(o_model, GLPK.Optimizer; add_bridges = false)
optimize!(o_model)
print(objective_value(o_model))
