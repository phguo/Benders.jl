using JuMP
using MathOptInterface
const MOI = MathOptInterface
import GLPK

include("problem.jl")
include("decompose.jl")

MAX_ITERATIONS = 50
OPTIMALITY_GAP = 0.001

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
