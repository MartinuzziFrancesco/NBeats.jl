function generic_basis(backcast_size::Int, forecast_size::Int)
    return function (theta::AbstractArray)
        backcast = theta[:, 1:backcast_size]
        forecast = theta[:, (end - forecast_size + 1):end]
        return backcast, forecast
    end
end

function trend_basis(degree_of_polynomial::Int, backcast_size::Int, forecast_size::Int)
    polynomial_size = degree_of_polynomial + 1
    backcast_time = hcat(
        [
            Float32.((0:(backcast_size - 1)) / backcast_size) .^ i for
            i in 0:degree_of_polynomial
        ]...,
    )
    forecast_time = hcat(
        [
            Float32.((0:(forecast_size - 1)) / forecast_size) .^ i for
            i in 0:degree_of_polynomial
        ]...,
    )

    return function (theta::AbstractArray)
        backcast = theta[:, (polynomial_size + 1):end] * backcast_time
        forecast = theta[:, 1:polynomial_size] * forecast_time
        return backcast, forecast
    end
end

function seasonality_basis(harmonics::Int, backcast_size::Int, forecast_size::Int)
    frequency = vcat(
        zeros(Float32, 1), collect(1:(harmonics / 2 * forecast_size)) / harmonics
    )

    backcast_grid = -2π * (collect(0:(backcast_size - 1)) / forecast_size) * frequency'
    forecast_grid = 2π * (collect(0:(forecast_size - 1)) / forecast_size) * frequency'

    backcast_cos_template = cos.(backcast_grid)
    backcast_sin_template = sin.(backcast_grid)
    forecast_cos_template = cos.(forecast_grid)
    forecast_sin_template = sin.(forecast_grid)

    return function (theta::AbstractArray)
        params_per_harmonic = size(theta, 2) ÷ 4
        backcast_harmonics_cos =
            theta[:, (2 * params_per_harmonic + 1):(3 * params_per_harmonic)] *
            backcast_cos_template
        backcast_harmonics_sin =
            theta[:, (3 * params_per_harmonic + 1):end] * backcast_sin_template
        backcast = backcast_harmonics_sin + backcast_harmonics_cos

        forecast_harmonics_cos = theta[:, 1:params_per_harmonic] * forecast_cos_template
        forecast_harmonics_sin =
            theta[:, (params_per_harmonic + 1):(2 * params_per_harmonic)] *
            forecast_sin_template
        forecast = forecast_harmonics_sin + forecast_harmonics_cos

        return backcast, forecast
    end
end
