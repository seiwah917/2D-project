# Term 5 2D Project


This project aims to develop a versatile full-stack Aggregate Production Planning (APP) software that optimizes workforce and inventory levels using Linear Programming. 

## Installation

Clone the repository and install the following dependencies:

Ensure you have the latest version of Julia installed, and the latest version of Gurobi installed (with a valid license).

Open a terminal (cmd, powershell, Julia, etc.) of your choice. Working in VSCode with the Julia extension is strongly recommended.

First `cd` into the project directory. Ensure the following Julia packages are installed:

```bash
GenieFramework
PlotlyBase
DataFrames
CSV
StippleLatex
StippleDownloads
JuMP
Gurobi
Distributions
```
Then run:

```bash
$> julia --project 
```

Then run the app:

```julia
julia> using GenieFramework
julia> Genie.loadapp() # load app
julia> up() # start server
```

Alternatively, you can run the app with [Genie Builder](https://marketplace.visualstudio.com/items?itemName=GenieBuilder.geniebuilder) in VScode (the uploader bug disappears when the app is run in Genie Builder; however, a paid subscription may be required to render the graphs). An introductory guide is available [here](https://learn.genieframework.com/geniebuilder/docs).

## Usage

Open your browser and navigate to `http://localhost:8000/`.

## LP formulation

Specific definitions of all Variables and cost parameters may be found [here](https://docs.google.com/document/d/1MLJF5VuhOFrI6JguJtWFDWgfCjEkQjxdbmZNGW0y3ug/edit?usp=sharing).

## Important Notes

1. When clicking the `Run` button for the first time, the LP solver may take a little longer to run (up to 2 minutes).

2. The Uploaders are bugged and do not function. If you wish to run the optimizer with CSV files other than the one used, use the `download` button to download the empty templates and fill them in. Once done, copy them into the `uploads` folder. Then, open app.jl in your code editor, and rename the `Select_demand`, `Select_para`, and `Select_workers` variables as follows:

```julia
@in Select_demand = "YOUR_DEMAND_FILE.csv" #Replace the Select_demand value with your demand file name
@in Select_demand_list = ["Select Demand File", "demand_data_final_sample.csv", "YOUR_DEMAND_FILE.csv"]
@in Select_para = "YOUR_PARAMETER_FILE.csv" #Replace the Select_parameter value with your parameter file name
@in Select_para_list = ["Select Parameter File", "para_data_final_sample.csv", "YOUR_PARAMETER_FILE.csv"]    
@in Select_workers = "YOUR_WORKERS_FILE.csv" #Replace the Select_workers with your workers file name
@in Select_workers_list = ["Select Workers File", "worker_data_final_sample.csv", "YOUR_WORKERS_FILE.csv"]
```