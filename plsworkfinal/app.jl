module App

# == Packages ==
using CSV
using DataFrames
using GenieFramework
using PlotlyBase
using StippleDownloads
using StippleLatex
@genietools

# == Variables ==
Month = 0
WorkerType = 0
ProductType = 0

# Load the CSV file with results
results_df = CSV.read(raw"C:\Users\kaele\OneDrive\Documents\Kaelen's stuff\SUTD\TERM 5\2D\Term 5 2D Project\Backend\data7.csv", DataFrame)

# == Reactive code ==
@app begin
    # == Reactive variables ==
    @in Month = 0
    @in WorkerType = 0
    @in ProductType = 0
    @in isHiringChecked = false
    @in isFiringChecked = false
    @in isInventoryChecked = false
    @in updateButtonClicked = false
    @out msgM = "Months (t): "
    @out msgW = "Worker Type (i): "
    @out msgP = "Product Type (j): "
    @out updatedHiringValue = 0
    @out updatedFiringValue = 0
    @out updatedInventoryValue = 0

    function validate_integer(value::String)
        try
            int_value = parse(Int, value)
            return int_value
        catch e
            return nothing
        end
    end

    @onchange Month begin
        if isnothing(validate_integer(Month))
            msgM = "Invalid input: Please enter an integer for Months."
        else
            msgM = "Months (t): $(Month)"
        end
    end

    @onchange WorkerType begin
        if isnothing(validate_integer(WorkerType))
            msgW = "Invalid input: Please enter an integer for Worker Type."
        else
            msgW = "Worker Type (i): $(WorkerType)"
        end
    end

    @onchange ProductType begin
        if isnothing(validate_integer(ProductType))
            msgP = "Invalid input: Please enter an integer for Product Type."
        else
            msgP = "Product Type (j): $(ProductType)"
        end
    end

    @onchange updateButtonClicked begin
        if updateButtonClicked
            # Process the checkbox values only if the inputs are valid integers
            if !isnothing(validate_integer(Month)) && !isnothing(validate_integer(WorkerType)) && !isnothing(validate_integer(ProductType))
                t = parse(Int, Month)
                k = parse(Int, WorkerType)
                j = parse(Int, ProductType)

                # Fetch the corresponding values from the results DataFrame
                row = filter(r -> r.i == t && r.k == k && r.j == j, results_df)
                
                if !isempty(row)
                    updatedHiringValue = isHiringChecked ? row.H[1] : 0
                    updatedFiringValue = isFiringChecked ? row.F[1] : 0
                    updatedInventoryValue = isInventoryChecked ? row.I[1] : 0
                else
                    updatedHiringValue = 0
                    updatedFiringValue = 0
                    updatedInventoryValue = 0
                end

                updateButtonClicked = false
            else
                # Handle invalid inputs
                msgM = "Error: Please fix the invalid inputs."
                msgW = "Error: Please fix the invalid inputs."
                msgP = "Error: Please fix the invalid inputs."
            end
        end
    end
end

# == Pages ==
# Register a new route and the page that will be loaded on access
@page("/", "app.jl.html")
end

