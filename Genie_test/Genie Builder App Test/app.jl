module App
# == PACKAGES ==
using GenieFramework, PlotlyBase, DataFrames, CSV
using Genie.Router
using Genie.Requests
using Genie.Renderer.Html
using StippleLatex, StippleDownloads
@genietools

# == CODE IMPORTS ==

#Load backend code from Lib Folder
include("lib/Backend_Optimizer.jl")
using .Backend

# == FRONTEND HELPER FUNCTIONS ==

#Add File Function
function add_file(filename, Select_list)
    push!(Select_list, filename)
    return Select_list
end

#Delete Files Function
function delete_files(folder, dir)
    @info "delete function called"
    for file in folder
        @info "delete function looping"
        file_path = joinpath(dir, file)
        @info typeof(file)
        if (file == "demand_data_final_sample.csv") || (file == "para_data_final_sample.csv") || (file == "worker_data_final_sample.csv")
            @info "sample files protected from deletion!"
        elseif isfile(file_path)
            try
                rm(file_path)
                println("Deleted file: ", file_path)
            catch e
                println("Error deleting file: ", file_path, " - ", e)
                break
            end
        else
            println("Error deleting file: ", file_path, " - ", e)
            break
        end
    end
end

function appender(front, back)
    append!(front, back)
end

#Validate integer in input fields
function validate_integer(value)
    try
        int_value = parse(Int, value)
        return int_value
    catch e
        return nothing
    end
end

# == REACTIVE CODE ==
@app begin
    # == REACTIVE VARIABLES ==
    # @out variables can only be modified by the backend
    # @in variables can be modified by both the backend and the browser
    # variables must be initialized with constant values, or variables defined outside of the @app block


    #Dropdown list variables
    @in Select_demand = "Select Demand File"
    @in Select_demand_list = ["Select Demand File", "demand_data_final_sample.csv"]
    @in Select_para = "Select Parameter File"
    @in Select_para_list = ["Select Parameter File", "para_data_final_sample.csv"]    
    @in Select_workers = "Select Workers File"
    @in Select_workers_list = ["Select Workers File", "worker_data_final_sample.csv"]

    @in worker_type = "Select worker type"    #Variables for Graphs
    @in product_type = "Select product type"
    @in worker_list = ["Select worker type"]
    @in product_list = ["Select product type"]

    @in selected_worker = :j   #Helper variables for Graph dropdowns
    @in selected_product = :i


    #Uploader variables
    @out upl_acceptext = ".csv, text/csv"
    @out upl_maxsize = 1 * 1024 * 1024 #1MB max upload capacity
    @out upl_caption = "No CSV file selected"
    @in Select = "" #Identifies which uploader is being used, sends filepath to correct dropdown list
    @in enableClearUploads = false
    @in disableClearButton = true
    @in ClearUploadsClicked = false


    #Additional Constraint Variables
    @in AC_List = []      #List collating Input lists as Constraints to send to Back-End
    @in Display_List = [] #List that helps display added constraints on UI
    @in Temp_List = []    #Another helper list for UI display

    @in updateClearButtonClicked = false  #Clear button Variable
    @in disable_inputs = true             #Disable Input Variable

    @in H_List = ["", 0, 0, 0, "", 0] #Input lists (collates all input fields for one constraint)
    @in F_List = ["", 0, 0, 0, "", 0]
    @in I_List = ["", 0, 0, 0, "", 0]

    @in Month = ""                    #Key-in Input Field Variables
    @in WorkerType = ""
    @in ProductType = ""
    @in ValueField = ""
    @out msgM = "Production Period (t): "
    @out msgW = "Worker Type (j): "
    @out msgP = "Product Type (i): "
    @out msgV = "Value:"

    @in isHiringChecked = false       #Checkbox Variables
    @in isFiringChecked = false
    @in isInventoryChecked = false
    @in updateButtonClicked = false
    @in updateClearButtonClicked = false

    @in Radio_buttons = ""            #Radio Buttons (<=/=/>=) Variable

    @out updatedHiringValue = 0       #I'm pretty sure these don't do anything,
    @out updatedFiringValue = 0       #but I'm not gonna delete them on the off chance
    @out updatedInventoryValue = 0    #that something goes horribly wrong lol


    #LP Output (results) and Graph variables
    @in results_workforce = DataFrame() #Overall results from LP initialized as empty DataFrame
    @in results_inventory = DataFrame()
    @in results_cost = 0 #Objective cost value
    @in results_H_cost = 0 #total hiring cost value
    @in results_F_cost = 0 #total firing cost value
    @in results_I_cost = 0 #total inventory cost value
    @in results_x_W = Float64[] #X axis for graphs initialized as empty Float Vector
    @in results_x_I = Float64[] #X axis for graphs initialized as empty Float Vector

    @in results_y_W = Float64[]   #Y axis for Workforce graph also Float Vector
    @in results_y_I = Float64[]   #Y axis for Inventory graph also Float Vector
    @in results_y_B = Float64[]   #Y axis for Backlog graph also Float Vector
    @in results_y_H = Float64[]
    @in results_y_F = Float64[]

    @in results_Wgraph = DataFrame() #DataFrame to help with Workforce Graph
    @in results_Igraph = DataFrame() #DataFrame to help with Inventory Graph


    #Other
    @in run_loading = false #Shows loading spinner while LP is loading
    @out dummy_update = false

    # == REACTIVE HANDLERS ==
    # reactive handlers watch a variable and execute a block of code when its value changes

    #Upload location handler
    @onchange fileuploads begin
        @info "Checkpoint: onchange activated"
        if !isempty(fileuploads)
            @info fileuploads
            @info "Checkpoint: verified that upload exists"

            @info Select
            if Select == "Demand"
                filename = fileuploads["name"]
                @info filename
                try
                    isdir(joinpath("lib", "uploads", "demand")) || mkpath(joinpath("lib", "uploads", "demand"))
                    mv(fileuploads["path"], joinpath("lib", "uploads", "demand", filename), force=true)
                catch e
                    @error "Error processing file: $(e)"
                end

                Select_demand_list = add_file(filename, Select_demand_list)
                Select_demand = Select_demand_list[end]
                @show Select_demand_list
            end

            if Select == "Parameter"
                filename = fileuploads["name"]
                @info filename
                try
                    isdir(joinpath("lib", "uploads", "parameters")) || mkpath(joinpath("lib", "uploads", "parameters"))
                    mv(fileuploads["path"], joinpath("lib", "uploads", "parameters", filename), force=true)
                catch e
                    @error "Error processing file: $(e)"
                end

                Select_para_list = add_file(filename, Select_para_list)
                Select_para = Select_para_list[end]
                @show Select_para_list
            end

            if Select == "Workers"
                filename = fileuploads["name"]
                @info filename
                try
                    isdir(joinpath("lib", "uploads", "workers")) || mkpath(joinpath("lib", "uploads", "workers"))
                    mv(fileuploads["path"], joinpath("lib", "uploads", "workers", filename), force=true)
                catch e
                    @error "Error processing file: $(e)"
                end

                Select_workers_list = add_file(filename, Select_workers_list)
                Select_workers = Select_workers_list[end]
                @show Select_workers_list
            end
            @info "Checkpoint: Upload saved to correct folder"

            #Reset
            Select = ""
            @info fileuploads
            fileuploads = Dict{AbstractString,AbstractString}()
            @info fileuploads
    
        end
    end

    #Upload event handlers
    @event demand_uploaded begin
        @info "Demand file uploaded"
        @info fileuploads
        fileuploads = Dict{AbstractString,AbstractString}()
        @info fileuploads
        @info "Checkpoint: Select and fileuploads cleared"

    end
    @event para_uploaded begin
        @info "Parameter file uploaded"
        @info fileuploads
        fileuploads = Dict{AbstractString,AbstractString}()
        @info fileuploads
        @info "Checkpoint: Select and fileuploads cleared"
    end
    @event workers_uploaded begin
        @info "Workers file uploaded"
        @info fileuploads
        fileuploads = Dict{AbstractString,AbstractString}()
        @info fileuploads
        @info "Checkpoint: Select and fileuploads cleared"
    end

    @event demand_rejected begin
        @info "Demand file rejected"
        notify(__model__, "Demand file rejected. Please make sure it is a valid CSV file.")
    end
    @event para_rejected begin
        @info "Parameter file rejected"
        notify(__model__, "Parameter file rejected. Please make sure it is a valid CSV file.")
    end
    @event workers_rejected begin
        @info "Workers file rejected"
        notify(__model__, "Workers file rejected. Please make sure it is a valid CSV file.")
    end

    @event demand_added begin
        @info "Demand file added"
        @info fileuploads
    end
    @event para_added begin
        @info "Parameter file added"
    end
    @event workers_added begin
        @info "Workers file added"
    end

    @event demand_removed begin
        @info "Demand file removed"
    end
    @event para_removed begin
        @info "Parameter file removed"
    end
    @event workers_removed begin
        @info "Workers file removed"
    end

    @event demand_started begin
        @info "Demand file upload started"
        @info fileuploads
    end
    @event para_started begin
        @info "Parameter file upload started"
    end
    @event workers_started begin
        @info "Workers file upload started"
    end

    @event demand_uploading begin
        @info "Demand file uploading"
        try
            Select = "Demand"
        catch e
        end
        @info "Select set to:"
        @info Select        
    end
    @event para_uploading begin
        @info "Parameter file uploading"
        try
            Select = "Parameter"
        catch e
        end
        @info "Select set to:"
        @info Select
    end
    @event workers_uploading begin
        @info "Workers file uploading"
        try
            Select = "Workers"
        catch e
        end
        @info "Select set to:"
        @info Select
    end

    @event demand_finished begin
        @info "Demand file upload finished"
    end
    @event para_finished begin
        @info "Parameter file upload finished"
    end
    @event workers_finished begin
        @info "Workers file upload finished"
    end

    @event demand_failed begin
        @info "Demand file upload failed"
    end
    @event para_failed begin
        @info "Parameter file upload failed"
    end    
    @event workers_failed begin
        @info "Workers file upload failed"
    end

    # Clear All Uploads handlers
    @onchange enableClearUploads begin #Toggle handler
        if enableClearUploads == true
            disableClearButton = false
        else
            disableClearButton = true
        end 
    end

    @onchange ClearUploadsClicked begin #Button handler
        if ClearUploadsClicked == true
            try
                #Delete all files
                @info "started"
                demand_dir = joinpath("lib", "uploads", "demand")
                demand_files = readdir(demand_dir)
                para_dir = joinpath("lib", "uploads", "parameters")
                para_files = readdir(para_dir)
                workers_dir = joinpath("lib", "uploads", "workers")
                workers_files = readdir(workers_dir)
                @info "directories retrieved for deletion"
                @info demand_files
                delete_files(demand_files, demand_dir)
                delete_files(para_files, para_dir)
                delete_files(workers_files, workers_dir)

            catch e
                @error e
            end

            @info "all files deleted, resetting all variables"

            #Clear dropdowns
            Select_demand_list = ["Select Demand File", "demand_data_final_sample.csv"]
            Select_demand = Select_demand_list[1]
            Select_para_list = ["Select Parameter File", "para_data_final_sample.csv"]
            Select_para = Select_para_list[1]            
            Select_workers_list = ["Select Workers File", "worker_data_final_sample.csv"]
            Select_workers = Select_workers_list[1]
            worker_list = ["Select worker type"]
            worker_type = worker_list[1]
            product_list = ["Select product type"]
            product_type = product_list[1]

            #Clear additional constraints
            isHiringChecked = false
            isFiringChecked = false
            isInventoryChecked = false
            Month = ""
            ProductType = ""
            WorkerType = ""
            ValueField = ""
            msgM = "Production Period (t): "
            msgW = "Worker Type (j): "
            msgP = "Product Type (i): "
            msgV = "Value: "
            AC_List = []
            Temp_List = []
            Display_List = []

            #Clear cost display panels
            results_cost = 0
            results_H_cost = 0
            results_F_cost = 0
            results_I_cost = 0

            #Clear graphs
            results_x = Float64[]
            results_y_W = Float64[]
            results_y_I = Float64[]
            results_y_B = Float64[]
            results_y_H = Float64[]
            results_y_F = Float64[]        
            results_Wgraph = DataFrame()
            results_Igraph = DataFrame()

            ClearUploadsClicked = false
            notify(__model__, "All files deleted.")
        end
    end

    # Downloader handlers
    @event download begin #Download LP solution
        try
            solution = joinpath("lib", "downloads", "optimal_workforce.csv")
            io = IOBuffer()
            open(solution, "r") do file
                write(io, read(file))
            end
            seekstart(io)
            download_binary(__model__, take!(io), "optimal_workforce.csv")
        catch ex
            println("Error during download: ", ex)
        end
        try
            solution = joinpath("lib", "downloads", "optimal_inventory.csv")
            io = IOBuffer()
            open(solution, "r") do file
                write(io, read(file))
            end
            seekstart(io)
            download_binary(__model__, take!(io), "optimal_inventory.csv")
        catch ex
            println("Error during download: ", ex)
        end
    end

    @event download_templates begin #Download Empty Template CSVs
        try
            solution = joinpath("lib", "downloads", "empty_demand_file.csv")
            io = IOBuffer()
            open(solution, "r") do file
                write(io, read(file))
            end
            seekstart(io)
            download_binary(__model__, take!(io), "empty_demand_file.csv")
        catch ex
            println("Error during download: ", ex)
        end
        try
            solution = joinpath("lib", "downloads", "empty_parameter_file.csv")
            io = IOBuffer()
            open(solution, "r") do file
                write(io, read(file))
            end
            seekstart(io)
            download_binary(__model__, take!(io), "empty_parameter_file.csv")
        catch ex
            println("Error during download: ", ex)
        end
        try
            solution = joinpath("lib", "downloads", "empty_worker_file.csv")
            io = IOBuffer()
            open(solution, "r") do file
                write(io, read(file))
            end
            seekstart(io)
            download_binary(__model__, take!(io), "empty_worker_file.csv")
        catch ex
            println("Error during download: ", ex)
        end
    end


    # Run Button handler
    @event run begin
        run_loading = true
        try
            worker_list = ["Select worker type"]
            product_list = ["Select product type"]
            worker_type = worker_list[1]
            product_type = product_list[1]        

            demand_file_path = joinpath("lib", "uploads", "demand", Select_demand)
            para_file_path = joinpath("lib", "uploads", "parameters", Select_para)
            workers_file_path = joinpath("lib", "uploads", "workers", Select_workers)
            @info "Checkpoint: Custom constraints received"

            @info demand_file_path
            @info para_file_path
            @info workers_file_path

            # Load the CSV files into DataFrames
            demand_data = CSV.read(demand_file_path, DataFrame)
            para_data = CSV.read(para_file_path, DataFrame)
            workers_data = CSV.read(workers_file_path, DataFrame)
            @info "Checkpoint: Data extracted"

            # Run optimizer
            results_workforce, results_inventory, results_cost = run_optimizer(demand_data, para_data, workers_data, AC_List)
            @info results_cost

            if results_cost == -100000
                results_cost = 0
                notify(__model__, "Error: Model Infeasible. Try loosening the added constraints!")
                run_loading = false
            else
                @info "Checkpoint: Optimized results saved successfully"            
                # DataFrame of all variables (Workforce, Inventory, Backlog, etc.) saved to a DataFrame called results
                # Cost saved to a Float64 variable called results_cost

                # Calculating respective H/F/I costs
                results_H_cost = para_data.ch[1]*sum(results_workforce.H)
                results_F_cost = para_data.cf[1]*sum(results_workforce.F)
                results_I_cost = para_data.ci[1]*sum(results_inventory.I)

                # Display graphs
                results_Wgraph = deepcopy(results_workforce) #Copy results so that for each graph
                results_Igraph = deepcopy(results_inventory) #we have a list to manipulate freely with dropdowns.

                results_x_W = results_Wgraph.t
                results_y_W = results_Wgraph.W
                results_y_H = results_Wgraph.H
                results_y_F = results_Wgraph.F

                results_x_I = results_Igraph.t
                results_y_I = results_Igraph.I #y-axis for Inventory
                results_y_B = (results_Igraph.B) .* -1 #y-axis for Backlog
                @info "Checkpoint: Graphs rendering successfully."

                #Note that we're displaying I and B on the same graph.
                #Backlog is essentially negative inventory so all values are multiplied by -1 for display.
                #Update graph dropdown variables
                worker_string = string.(results_workforce[:, selected_worker]) #Extract worker/product lists as lists of strings
                product_string = string.(results_inventory[:, selected_product])

                worker_list = appender(worker_list, unique(worker_string)) #Use list of strings to populate worker_list and product_list
                product_list = appender(product_list, unique(product_string))

                @info "Graph dropdown lists:"
                @info worker_list
                @info product_list
                @info "Checkpoint: Dropdowns updated successfully."
            end
        catch e
            @error e
            notify(__model__, e)
        end
        run_loading = false
    end


    # Additional Constraint input handlers
    @onchange Select_demand begin
        if (Select_demand!="Select Demand File") && (Select_para!="Select Parameter File") && (Select_workers!="Select Workers File")
            disable_inputs = false
            @info "enabled"
        else
            disable_inputs = true
            @info "disabled"
        end
    end

    @onchange Select_para begin
        if (Select_demand!="Select Demand File") && (Select_para!="Select Parameter File") && (Select_workers!="Select Workers File")
            disable_inputs = false
            @info "enabled"
        else
            disable_inputs = true
        end
    end

    @onchange Select_workers begin
        if (Select_demand!="Select Demand File") && (Select_para!="Select Parameter File") && (Select_workers!="Select Workers File")
            disable_inputs = false
            @info "enabled"
        else
            disable_inputs = true
        end
    end

    @onchange Month begin
        if (isnothing(validate_integer(Month)) && ((isHiringChecked || isFiringChecked) || isInventoryChecked))
            msgM = "Invalid input: Please enter an integer for Production Period."
        elseif Select_demand != "Select Demand File"
            demand_file_path = joinpath("lib", "uploads", "demand", Select_demand)
            tmax = length(CSV.read(demand_file_path, DataFrame)[:,1]) - 2

            #Check that 0 < input t <= tmax
            if (parse(Int, Month) > tmax) || (parse(Int, Month) <= 0)
                @info tmax
                notify(__model__, "Invalid input. Please enter a positive integer less than $(tmax).")
                msgM = "Invalid input: exceeds $(tmax)"
                Month = ""
            else
                msgM = "Production Period (t): $(Month)"
            end
        end
    end

    @onchange WorkerType begin
        if (isnothing(validate_integer(WorkerType)) && (isHiringChecked || isFiringChecked))
            msgW = "Invalid input: Please enter an integer for Worker Type."
        elseif Select_workers != "Select Workers File"
            workers_file_path = joinpath("lib", "uploads", "workers", Select_workers)
            @info workers_file_path
            jmax = length(CSV.read(workers_file_path, DataFrame)[:,2])

            #Check that 0 < input j <= jmax
            if (parse(Int, WorkerType) > jmax) || (parse(Int, WorkerType) <= 0)
                @info jmax
                notify(__model__, "Invalid input. Please enter a positive integer less than $(jmax).")
                msgW = "Invalid input: exceeds $(jmax)"
                WorkerType = ""
            else
                msgW = "Worker Type (j): $(WorkerType)"
            end
        end
    end

    @onchange ProductType begin
        if (isnothing(validate_integer(ProductType)) && isInventoryChecked)
            msgP = "Invalid input: Please enter an integer for Product Type."
        elseif Select_workers != "Select Workers File"
            workers_file_path = joinpath("lib", "uploads", "workers", Select_workers)
            imax = length(CSV.read(workers_file_path, DataFrame)[2,:]) - 2
            try
                #Check that 0 < input i < imax
                if (parse(Int, ProductType) > imax) || (parse(Int, ProductType) <= 0)
                    @info imax
                    notify(__model__, "Invalid input. Please enter a positive integer less than $(imax).")
                    msgP = "Invalid input: exceeds $(imax)"
                    ProductType = ""
                else
                    msgP = "Product Type (i): $(ProductType)"
                end
            catch e
                @info "error caught!"
                @info e
            end
        end
    end

    @onchange ValueField begin
        if (ValueField == "" && (isHiringChecked || isFiringChecked || isInventoryChecked))
            msgV = "Invalid input: not +ve integer"
        elseif (isnothing(validate_integer(ValueField)) || validate_integer(ValueField) < 0) && !ClearUploadsClicked
            notify(__model__, "Invalid input. Please enter a positive integer.")
            msgV = "Invalid input: not +ve integer"
            ValueField = ""
        else
            msgV = "Value: $(ValueField)"
        end
    end

    @onchange updateButtonClicked begin #"Add Constraint" button handler
        if updateButtonClicked
            @info "Hi."
            # Process the checkbox values only if the inputs are valid integers

            if Radio_buttons == "" #Check that an operator has been specified
                @info "Error caught: radio buttons left empty."
                notify(__model__, "Invalid input: Please set an operator (≤/=/≥)")
            
            elseif !(isHiringChecked || isFiringChecked || isInventoryChecked)
                @info "Error caught: checkbox not selected."
                notify(__model__, "Invalid input: Checkboxes left empty")

            elseif ((isHiringChecked && isInventoryChecked) || (isFiringChecked && isInventoryChecked))
                @info "Error caught: wrong checkbox selection."
                notify(__model__, "Invalid input: Unable to set H/F simultaneously with I.")

            else
                try
                    Display_List = [] #Reset the display list
                    t = parse(Int, Month)
                    VF = parse(Int, ValueField)

                    # Save the inputs
                    if isHiringChecked
                        j = parse(Int, WorkerType)    
                        H_List[6] = VF
                        H_List[5] = Radio_buttons
                        H_List[4] = j
                        H_List[3] = "n/a"
                        H_List[2] = t
                        H_List[1] = "H"
                        push!(AC_List, deepcopy(H_List))
                        updatedHiringValue = H_List[6]
                    end

                    if isFiringChecked
                        j = parse(Int, WorkerType)
                        F_List[6] = VF
                        F_List[5] = Radio_buttons
                        F_List[4] = j
                        F_List[3] = "n/a"
                        F_List[2] = t
                        F_List[1] = "F"
                        push!(AC_List, deepcopy(F_List))
                        updatedFiringValue = F_List[6]
                    end

                    if isInventoryChecked
                        i = parse(Int, ProductType)
                        I_List[6] = VF
                        I_List[5] = Radio_buttons
                        I_List[4] = "n/a"
                        I_List[3] = i
                        I_List[2] = t
                        I_List[1] = "I"
                        push!(AC_List, deepcopy(I_List))
                        updatedInventoryValue = I_List[6]
                    end

                    for Constraint in AC_List
                        Concopy = deepcopy(Constraint)
                        Displaystring = join(string.(Concopy), " ")
                        add_file(Displaystring, Display_List) #Not actually adding a file, but this func also works to push into arrays
                    end

                    @info "AC_List:"
                    @info AC_List
                    @info "Display_List:"
                    @info Display_List

                catch e
                    # Handle invalid inputs
                    @error e
                    notify(__model__, "Error: Please fix invalid/missing inputs.")
                    msgM = "Error: Please fix invalid/missing inputs."
                    msgW = "Error: Please fix invalid/missing inputs."
                    msgP = "Error: Please fix invalid/missing inputs."
                    msgV = "Error: Please fix invalid/missing inputs."
                end
            end
            Display_List = Display_List
            updateButtonClicked = false
            @info "Button update complete"
        end
    end

    @onchange updateClearButtonClicked begin #Clear All Constraints button
        if updateClearButtonClicked == true
            try
                Month = ""
                WorkerType = ""
                ProductType = ""
                ValueField = ""
                isHiringChecked = false
                isFiringChecked = false
                isInventoryChecked = false
                msgM = "Production Period (t): "
                msgW = "Worker Type (j): "
                msgP = "Product Type (i): "
                msgV = "Value:"
                updatedHiringValue = 0
                updatedFiringValue = 0
                updatedInventoryValue = 0
                worker_list = ["Select worker type"]
                product_list = ["Select product type"]
                worker_type = worker_list[1]
                product_type = product_list[1]

                AC_List = []
                Display_List = []
                Temp_List = []
                H_List = ["", 0, 0, 0, "", 0]
                F_List = ["", 0, 0, 0, "", 0]
                I_List = ["", 0, 0, 0, "", 0]
                @info AC_List
                updateClearButtonClicked = false
            catch e
                @error e
            end
        end
    end

    @onchange Radio_buttons begin
        if isHiringChecked
            H_List[5] = Radio_buttons
        end
        if isFiringChecked
            F_List[5] = Radio_buttons
        end
        if isInventoryChecked
            I_List[5] = Radio_buttons
        end
        @info H_List
        @info F_List
        @info I_List
    end

    @event remove_all begin
        AC_List = []
        H_List = ["", 0, 0, 0, "", 0]
        F_List = ["", 0, 0, 0, "", 0]
        I_List = ["", 0, 0, 0, "", 0]
        @info AC_List
    end

    @event remove_item begin
        @info "Hey!"
        Temp_List = deepcopy(Display_List)
        @info Temp_List
    end

    @onchange Display_List begin
        if !isempty(Temp_List)
            for item in Temp_List
                if !(item in Display_List)
                    idx = findfirst(x -> x == item, Temp_List)
                    @info idx
                    splice!(AC_List, idx)        
                end
            end
            Temp_List = []
            @info "Success! Constraint Removed."
            @info AC_List
        end
    end

    #Graph handlers
    @onchange worker_type begin
        if worker_type != "Select worker type"

            #Start by resetting the DataFrame
            results_Wgraph = results_workforce 

            #Filter the DataFrame for selected j
            selected_j = parse(Int, worker_type)
            results_Wgraph = filter(row -> row.j == selected_j, results_Wgraph)

            #Update graph
            results_x_W = results_Wgraph.t
            results_y_W = results_Wgraph.W
            results_y_H = results_Wgraph.H
            results_y_F = results_Wgraph.F

        elseif !isempty(results_workforce)
            results_Wgraph = results_workforce
            results_x_W = results_Wgraph.t
            results_y_W = results_Wgraph.W
            results_y_H = results_Wgraph.H
            results_y_F = results_Wgraph.F                
        end
    end


    @onchange product_type begin
        if product_type != "Select product type"

            #Start by resetting the DataFrame
            results_Igraph = results_inventory

            #Filter the DataFrame for selected i
            selected_i = parse(Int, product_type)
            results_Igraph = filter(row -> row.i == selected_i, results_Igraph)

            #Update graph
            results_x_I = results_Igraph.t
            results_y_I = results_Igraph.I
            results_y_B = (results_Igraph.B) .* -1

        elseif !isempty(results_inventory)            
            results_Igraph = results_inventory
            results_x_I = results_Igraph.t
            results_y_I = results_Igraph.I
            results_y_B = (results_Igraph.B) .* -1                
        end
    end

    #Just for debugging! Nothing to see here :)
    @event test begin
        try
            results, results_cost = CSV.read(joinpath("lib", "downloads", "workforce_inventory.csv"), DataFrame)
            @info results_cost
            # Display graphs

            results_x_I = results.t

            #results.i is a Vector that reads from column 'i' of the results DataFrame.
            #We save this to results_x to map to the x-axis of the graphs.
            #y axis works the same way.

            results_y_W = results.W #y-axis for Workforce

            results_y_I = results.I #y-axis for Inventory
            results_y_B = (results.B) .* -1 #y-axis for Backlog
        catch e
            @error e
        end
    end

    @event test2 begin
        @info AC_List
        @info Display_List
        @info Temp_List
    end

    @onchange dummy_update begin
        @info "updated"
        dummy_update = true
    end

end

# == PAGES ==
# register a new route and the page that will be loaded on access

@page("/", "app.jl.html")
end
# == ADVANCED FEATURES ==
#(Unused)
#=
- The @private macro defines a reactive variable that is not sent to the browser. 
This is useful for storing data that is unique to each user session but is not needed
in the UI.
    @private table = DataFrame(a = 1:10, b = 10:19, c = 20:29)
=#
