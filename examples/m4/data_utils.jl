function download_m4()
    # URLs for the M4 dataset
    train_url = "https://www.mcompetitions.unic.ac.cy/wp-content/uploads/2018/03/Daily-train.csv"
    test_url = "https://www.mcompetitions.unic.ac.cy/wp-content/uploads/2018/03/Daily-test.csv"

    # Create the data directories if they don't exist
    data_dir = joinpath("..", "data", "m4")
    mkpath(data_dir)

    # File paths for saving the data
    train_file_path = joinpath(data_dir, "Daily-train.csv")
    test_file_path = joinpath(data_dir, "Daily-test.csv")

    # Download the data files
    println("Downloading M4 Daily-train dataset...")
    Downloads.download(train_url, train_file_path)

    println("Downloading M4 Daily-test dataset...")
    Downloads.download(test_url, test_file_path)

    return println("Download completed!")
end

function get_m4_data(backcast_length, forecast_length, batch_size, is_training=true)
    filename = is_training ? "data/m4/train/Daily-train.csv" : "data/m4/val/Daily-test.csv"

    df = CSV.read(filename, DataFrame)
    x = Float64[]
    y = Float64[]

    for row in eachrow(df)
        time_series = [v == "" ? NaN : parse(Float64, v) for v in row[2:end]]
        time_series_cleaned = filter(!isnan, time_series)

        if length(time_series_cleaned) < backcast_length + forecast_length
            continue
        end

        if is_training
            j = rand(backcast_length:(length(time_series_cleaned) - forecast_length + 1))
            push!(x, time_series_cleaned[(j - backcast_length):(j - 1)])
            push!(y, time_series_cleaned[j:(j + forecast_length - 1)])
        else
            for j in backcast_length:(length(time_series_cleaned) - forecast_length + 1)
                push!(x, time_series_cleaned[(j - backcast_length):(j - 1)])
                push!(y, time_series_cleaned[j:(j + forecast_length - 1)])
            end
        end
    end

    x = reshape(reduce(vcat, x), :, length(x) ÷ backcast_length)
    y = reshape(reduce(vcat, y), :, length(y) ÷ forecast_length)

    # Split into batches
    x_batches = [x[:, i:min(i + batch_size - 1, end)] for i in 1:batch_size:size(x, 2)]
    y_batches = [y[:, i:min(i + batch_size - 1, end)] for i in 1:batch_size:size(y, 2)]

    return x_batches, y_batches
end

function batch_data(data, batch_size)
    num_batches = ceil(Int, length(data) / batch_size)
    batches = []

    for i in 1:num_batches
        start_idx = (i - 1) * batch_size + 1
        end_idx = min(i * batch_size, length(data))

        backcast_batch = hcat([data[j][1] for j in start_idx:end_idx]...)
        forecast_batch = hcat([data[j][2] for j in start_idx:end_idx]...)

        push!(batches, (backcast_batch, forecast_batch))
    end

    return batches
end

function evaluate_predictions(y_true, y_pred)
    mse = mean((y_true .- y_pred) .^ 2)
    mae = mean(abs.(y_true .- y_pred))
    ss_res = sum((y_true .- y_pred) .^ 2)
    ss_tot = sum((y_true .- mean(y_true)) .^ 2)
    r_squared = 1 - ss_res / ss_tot

    return mse, mae, r_squared
end
