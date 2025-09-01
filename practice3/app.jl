module App
# set up Genie development environment
using GenieFramework
@genietools

using Genie, Genie.Router, Genie.Renderer.Html, CSV, DataFrames, PlotlyJS

Genie.config.run_as_server = true

# Generate sample data
dates = Date(2024, 6, 1):Date(2024, 6, 25)
wflevels = rand(50:150, 25)
data = DataFrame(Date = dates, WorkforceLevel = wflevels)

# Save to CSV
csv_path = "wflevels.csv"
CSV.write(csv_path, data)
println("Generated CSV data saved to ", csv_path)

# Load the data from the CSV file
data = CSV.read(csv_path, DataFrame)

# Check if the DataFrame has the correct columns
println("DataFrame columns: ", names(data))
if !(:Date in names(data)) || !(:WorkforceLevel in names(data))
    error("CSV file does not have the required columns: Date, WorkforceLevel")
end

# Extract relevant columns for the bar chart
dates = data[!, :Date]  # Extract the Date column
workforce_levels = data[!, :WorkforceLevel]  # Extract the WorkforceLevel column

# Create the bar chart
bar_chart = Plot(
    data([:bar, x=dates, y=workforce_levels]),
    Layout(title="Workforce Levels Over 25 Days", yaxis_title="Date", xaxis_title="Workforce Level")
)

# Save the plot as an HTML file
html_path = "assets/bar_chart.html"
PlotlyJS.savehtml(bar_chart, html_path)

# Define the route for the web server
route("/") do
  content = html() do
    """
    <h1>Workforce Levels</h1>
    <div id="bar_chart"></div>
    <script>
        fetch('/assets/bar_chart.html')
            .then(response => response.text())
            .then(data => {
                var fig = JSON.parse(data);
                Plotly.newPlot('bar_chart', fig.data, fig.layout);
            });
    </script>
    """
  end
  HTML(content)
end

# Start the Genie server
Genie.AppServer.startup()

end
