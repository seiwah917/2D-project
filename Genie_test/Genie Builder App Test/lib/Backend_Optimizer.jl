module Backend
using JuMP
using Gurobi
using Distributions
using CSV
using DataFrames

export some_function, run_optimizer, printhi

# Unhash these to test-run the LP directly from here
#demand_file_path = joinpath("uploads", "demand", "demand_data9.csv")
#para_file_path = joinpath("uploads", "parameters", "data8.csv")
#workers_file_path = joinpath("uploads", "workers", "worker_data.csv")
#demand_data = CSV.read(demand_file_path, DataFrame)
#para_data = CSV.read(para_file_path, DataFrame)
#workers_data = CSV.read(workers_file_path, DataFrame)

#Run the optimizer
function run_optimizer(demand_data, para_data, workers_data, AC_List)

    @info "Checkpoint: Function accessed"

    # Extract the relevant data from the para_data DataFrame
    
    ch = para_data.ch[1]
    cf = para_data.cf[1]
    ci = para_data.ci[1]
    cr = para_data.cr[1]
    co = para_data.co[1]
    cu = para_data.cu[1]
    cs = para_data.cs[1]
    cb = para_data.cb[1]

    # Verify the dimensions of the demand_data DataFrame
    n_periods = size(demand_data, 1) - 2  # Number of periods
    @info "n_periods:"
    @info n_periods
    n_products = size(demand_data, 2) - 1 # Assuming the first row is header with product index i
    @info "n_products:"
    @info n_products
    D = Array{Float64}(undef, n_periods, n_products)

    D = Array{Float64}(undef, n_periods, n_products)
    for t in 2:n_periods + 1
        for i in 2:n_products + 1
            D[t - 1, i - 1] = demand_data[t + 1, i]  # Adjust for 1-based indexing in Julia
        end
    end
    # Extract K (Worker production rate) array
    n_workers = size(workers_data, 1)   #number of workers

    @info "n_workers:"
    @info n_workers

    # Test that number of products matches for Demand and Workers data
    if n_products == size(workers_data, 2) - 2
        nothing 
    else
        @error "Error: Number of product types in demand CSV and workers CSV do not match. Please check your uploads."
    end

    K = Array{Float64}(undef, n_workers,n_products)
    for i in 3:n_products + 2
        for j in 1:n_workers
            K[j, i - 2] = workers_data[j, i]  # Adjust for 1-based indexing in Julia
        end
    end
    @info "Checkpoint: Data Extracted"

    # Create the model with Gurobi optimizer
    m = Model(Gurobi.Optimizer)
    i_max = n_products #product type
    j_max = n_workers #worker type

    @info "Checkpoint: Model Initialized"

    # Define the variables
    @variable(m, W[0:n_periods, 1:i_max, 1:j_max] >= 0, Int)
    @variable(m, Wi[0:n_periods, 1:j_max] >= 0, Int)    
    @variable(m, H[1:n_periods, 1:j_max] >= 0, Int)
    @variable(m, F[1:n_periods, 1:j_max] >= 0, Int)
    @variable(m, I[0:n_periods, 1:i_max] >= 0)
    @variable(m, P[1:n_periods, 1:i_max] >= 0)
    @variable(m, O[1:n_periods, 1:i_max] >= 0)
    @variable(m, U[1:n_periods, 1:i_max] >= 0)
    @variable(m, S[1:n_periods, 1:i_max] >= 0, Int)
    @variable(m, B[0:n_periods, 1:i_max] >= 0, Int)
    @variable(m, R[1:n_periods, 1:i_max] >= 0, Int)

    @info "Checkpoint: Defined Variables"
    
    # Add initial constraints for W[0] and I[0]  

    for j in 1:j_max
        @constraint(m, Wi[0, j] == workers_data[j, 2])
    end
    
    for i in 1:i_max
        @constraint(m, I[0, i] == demand_data[1, i+1])
        @constraint(m, B[0, i] == demand_data[2, i+1])
    end

    # Define the constraints

    # Workforce constraints
    for j in 1:j_max
        for t in 0:n_periods
            @constraint(m, Wi[t, j] == sum(W[t,i,j] for i in 1:i_max))
        end
    end

    for t in 1:n_periods
         for j in 1:j_max
            @constraint(m, Wi[t, j] == Wi[t-1, j] + H[t, j] - F[t, j])
            @constraint(m, H[t, j] <= 0.1 * Wi[t,j])
            @constraint(m, F[t, j] <= 0.1 * Wi[t,j])
        end
    end

    # Production Constraints
    for t in 1:n_periods
        for i in 1:i_max
            for j in 1:j_max
                @constraint(m, P[t, i] == R[t, i] + O[t, i] - U[t, i])
                @constraint(m, R[t,i] <= (K[j,i]*W[t,i,j]))
                @constraint(m, O[t,i] <= 0.25 * R[t,i])
                
            end
        end
    end

    # Demand Constraints
    for t in 1:n_periods
        for i in 1:i_max
            for j in 1:j_max
                @constraint(m, I[t, i] - B[t, i] == I[t-1, i] - B[t-1, i] + P[t, i] + S[t, i] - D[t,i])  # Ensure D[i, 1] is correctly indexed
                @constraint(m, B[t,i] <= 0.25 * P[t,i])
            end
        end
    end
    @info "Checkpoint: Defined constraints"

    #Additional constraints
    if !isempty(AC_List)
        try
            for item in AC_List #Each item inside AC_List is itself a list. 1 item defines 1 single constraint.

                #[Index 1: Constraint applies to Hiring, Firing, or Inventory?
                # Index 2: t (production period i.e. month week etc.)
                # Index 3: i (product type)
                # Index 4: j (worker type)
                # Index 5: H/F/I is <=, =, or >= some value?
                # Index 6: Value]
                @info item
                if item[1] == "H" #Index 1
                    if item[5] == "<="
                        @constraint(m, H[item[2], item[4]] <= item[6])
                    elseif item[5] == "="
                        @constraint(m, H[item[2], item[4]] == item[6])
                    elseif item[5] == ">="
                        @constraint(m, H[item[2], item[4]] >= item[6])
                    end
                end
    
                if item[1] == "F"
                    if item[5] == "<="
                        @constraint(m, F[item[2], item[4]] <= item[6])
                    elseif item[5] == "="
                        @constraint(m, F[item[2], item[4]] == item[6])
                    elseif item[5] == ">="
                        @constraint(m, F[item[2], item[4]] >= item[6])
                    end
                end
    
                if item[1] == "I"
                    if item[5] == "<="
                        @constraint(m, I[item[2], item[3]] <= item[6])                        
                    elseif item[5] == "="
                        @constraint(m, I[item[2], item[3]] == item[6])
                    elseif item[5] == ">="
                        @constraint(m, I[item[2], item[3]] >= item[6])
                    end
                end
            end
            @info "Checkpoint: Additional Constraints received successfully."
                
        catch e
            @error "Error: Additional Constraints defined incorrectly. Please check Additional Constraint inputs."
        end

    end
    

    # Define the objective function
    @objective(m, Min,
    ch * sum(H[t,j] for t in 1:n_periods, j in 1:j_max) +
    cf * sum(F[t,j] for t in 1:n_periods, j in 1:j_max) +
    ci * sum(I[t,i] for t in 1:n_periods, i in 1:i_max) +
    co * sum(O[t,i] for t in 1:n_periods, i in 1:i_max) +
    cu * sum(U[t,i] for t in 1:n_periods, i in 1:i_max) +
    cs * sum(S[t,i] for  t in 1:n_periods, i in 1:i_max) +
    cr * sum(P[t,i] for  t in 1:n_periods, i in 1:i_max) +
    cb * sum(B[t,i] for t in 1:n_periods, i in 1:i_max)
    )

    @info "Checkpoint: Defined Objective Function"

    # Optimize the model
    optimize!(m)

    @info "Checkpoint: Optimized"

    status = termination_status(m)
    if status == MOI.INFEASIBLE
        return DataFrame(), DataFrame(), -100000
    end

    @info "Checkpoint: Feasibility Verified"

    # Collect results into a DataFrame
    results_work = DataFrame(
        t = Int[],
        j = Int[],
        W = Float64[],
        H = Float64[],
        F = Float64[]
    )

    @info results_work

    results_inv = DataFrame(
        t = Int[],
        i = Int[],
        W = Float64[],
        I = Float64[],
        P = Float64[],
        O = Float64[],
        U = Float64[],
        S = Float64[],
        B = Float64[]
    )

    @info "Checkpoint: results DataFrames initialized"

    try
        for t in 1:n_periods
            for j in 1:j_max
                push!(results_work, (
                    t, j,
                    value(sum(W[t, i, j] for i in 1:i_max)),
                    value(H[t, j]),
                    value(F[t, j]),
                ))
            end
        end
    catch e
        @info "L"
        @error e
    end

    for t in 1:n_periods
        for i in 1:i_max
            push!(results_inv, (
                t, i,
                value(sum(W[t, i, j] for j in 1:j_max)),
                value(I[t, i]),
                value(P[t, i]),
                value(O[t, i]),
                value(U[t, i]),
                value(S[t, i]),
                value(B[t, i])
            ))
        end
    end

    @info "Checkpoint: results saved"

    # Save the results to CSV files
    result_path = joinpath("lib", "downloads", "optimal_workforce.csv")
    @info result_path
    try
        CSV.write(result_path, results_work)
    catch e
        @error e
    end

    result_path = joinpath("lib", "downloads", "optimal_inventory.csv")
    @info result_path
    try
        CSV.write(result_path, results_inv)
    catch e
        @error e
    end

    @info "Checkpoint: results written to file"

    # Print the results
#    for t in 1:n_periods
#        for i in 1:i_max
#            for j in 1:j_max
#                println("W[$t, $i, $j] = ", value(W[t, i, j]))
#                println("H[$t, $j] = ", value(H[t, j]))
#                println("F[$t, $j] = ", value(F[t, j]))
#                println("I[$t, $i] = ", value(I[t, i]))
#                println("P[$t, $i] = ", value(P[t, i]))
#                println("O[$t, $i] = ", value(O[t, i]))
#                println("U[$t, $i] = ", value(U[t, i]))
#                println("S[$t, $i] = ", value(S[t, i]))
#                println("B[$t, $i] = ", value(B[t, i]))
#            end
#        end
#    end
    @info "Checkpoint: results printed (disabled)"
    @info "Success!"

    return results_work, results_inv, objective_value(m)
end

#Dummy functions for testing
#We can delete this at the end but keep them here for now to help us
function printhi()
    @info "Hi!! I'm working :D"
end

function some_function(K)
    K = push!(K, 2)
    return K
end
end