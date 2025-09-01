module App
using GenieFramework, PlotlyBase, DataFrames, CSV
using StippleLatex, StippleDownloads
@genietools

# == Packages ==
# set up Genie development environment. Use the Package Manager to install new packages
# controllers/SliderController.jl
# == Reactive code ==
# add reactive code to make the UI interactive
@app begin
    # == Reactive variables ==
    # reactive variables exist in both the Julia backend and the browser with two-way synchronization
    # @out variables can only be modified by the backend
    # @in variables can be modified by both the backend and the browser
    # variables must be initialized with constant values, or variables defined outside of the @app block
    @in cH = 0  # Hiring Costs
    @in cF = 0  # Firing Costs
    @in cI = 0  # Inventory Costs

    # define more reactive variables and handlers as needed
    @out msgH = "Hiring Costs: "
    @out msgF = "Firing Costs: "
    @out msgI = "Inventory Costs: "

    # == Reactive handlers ==
    # Update messages when slider values change
    @onchange cH begin
        msgH = "Hiring Costs: $(cH)"
    end

    @onchange cF begin
        msgF = "Firing Costs: $(cF)"
    end

    @onchange cI begin
        msgI = "Inventory Costs: $(cI)"
    end
end

# == Pages ==
# register a new route and the page that will be loaded on access
@page("/", "app.jl.html")
end