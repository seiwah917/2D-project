module App
# == Packages ==
using CSV
using DataFrames
using GenieFramework
using PlotlyBase
using StippleDownloads
using StippleLatex
@genietools
include("lib/Backend_Optimizer.jl")
using .Backend
#variables
Month = 0
WorkerType = 0
ProductType = 0

# == Reactive code ==
@app begin
    # == Reactive variables ==
    @in Month = []
    @in WorkerType = []
    @in ProductType = []
    @in isHiringChecked = false
    @in isFiringChecked = false
    @in isInventoryChecked = false
    @out msgM = "Months (t): "
    @out msgW = "Worker Type (i): "
    @out msgP = "Product Type (j): "
    @out msgInput = "Check the necessary variables to vary"
    @out msgOutput = "Output given below"
    @out hiringData = 0
    @out firingData = 0
    @out inventoryData = 0

    @onchange Month begin
        msgM = "Months (t): $(Month)"
    end

    @onchange WorkerType begin
        msgW = "Worker Type (i): $(WorkerType)"
    end

    @onchange ProductType begin
        msgP = "Product Type (j): $(ProductType)"
    end
    function updateData()
        if isHiringChecked
            hiringData = H[Month, WorkerType, ProductType]
        else
            hiringData = 0
        end

        if isFiringChecked
            firingData = F[Month, WorkerType, ProductType]
        else
            firingData = 0
        end

        if isInventoryChecked
            inventoryData = I[Month, WorkerType, ProductType]
        else
            inventoryData = 0
        end
    end

    @onchange isHiringChecked updateData
    @onchange isFiringChecked updateData
    @onchange isInventoryChecked updateData
    @onchange Month updateData
    @onchange WorkerType updateData
    @onchange ProductType updateData

end

# == Pages ==
@page("/", "app.jl.html")
end



