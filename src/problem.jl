using JuMP
import Gurobi


function original_model()
    # model = Model(Gurobi.Optimizer, add_bridges = false)
    model = Model()
    
    f = [i for i=1:3]
    c = [i for i=1:3]
    y_dim = length(f)
    x_dim = length(c)
    A = randn(3, 3)
    b = [30 for i=1:3]
    B = randn(3, 3)
    D = randn(3, 3)
    d = [30 for i=1:3]

    @variable(model, x[1:x_dim], lower_bound = 0, base_name = "__S__")
    @variable(model, y[1:y_dim], Int, lower_bound = 0, base_name = "__M__")
    @constraint(model, A * y .<= b, base_name = "__M__")
    @constraint(model, B * y + D * x .<= d)
    @expression(model, obj, sum(f[i] * x[i] for i=1:x_dim) + sum(c[i] * y[i] for i=1:y_dim))
    @objective(model, Min, obj)
    return model
end
