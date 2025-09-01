module App
# set up Genie development environment
using GenieFramework
@genietools

using Genie, Genie.Router, Genie.Renderer.Html, CSV, DataFrames

function read_csv_data()
    df = CSV.read("wflevels_25days.csv", DataFrame)
    return df
end

function prepare_chart_data(df)
    dates = df.Date |> collect
    levels = df.WorkforceLevel |> collect
    return dates, levels
end

route("/") do
    df = read_csv_data()
    dates, levels = prepare_chart_data(df)
    html_content = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Workforce Levels</title>
        <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    </head>
    <body>
        <canvas id="workforceChart" width="400" height="200"></canvas>
        <script>
            var ctx = document.getElementById('workforceChart').getContext('2d');
            var chart = new Chart(ctx, {
                type: 'bar',
                data: {
                    labels: $(dates),
                    datasets: [{
                        label: 'Workforce Levels',
                        data: $(levels),
                        backgroundColor: 'rgba(75, 192, 192, 0.2)',
                        borderColor: 'rgba(75, 192, 192, 1)',
                        borderWidth: 1
                    }]
                },
                options: {
                    scales: {
                        y: {
                            beginAtZero: true
                        }
                    }
                }
            });
        </script>
    </body>
    </html>
    """
    html(html_content)
end

# Start the Genie app
Genie.config.run_as_server = true
up()

end
