using JuMP
using Random

Random.seed!(999)


function original_model()
    """
        Define a mixed integer programming (MIP) where y is complicated varaibles (integer) and x is continues varaibles.
    
    (Reference: Rahmaniani, R., Crainic, T.G., Gendreau, M., Rei, W., 2017. The Benders decomposition algorithm: A literature review. European Journal of Operational Research 259, 801–817. https://doi.org/10.1016/j.ejor.2016.12.005)
    
    min  ...
    s.t. ...
    """
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

    @variable(model, x[1:x_dim], lower_bound = 0, base_name = "__S__var")
    @variable(model, y[1:y_dim], Int, lower_bound = 0, base_name = "__M__var")
    @constraint(model, A * y .>= b, base_name = "__M__cons")
    @constraint(model, B * y + D * x .>= d, base_name = "__S__cons")
    @expression(model, obj, sum(f[i] * x[i] for i=1:x_dim) + sum(c[i] * y[i] for i=1:y_dim))
    @objective(model, Min, obj)
    return model
end
