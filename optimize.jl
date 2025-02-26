using JuMP
using CSV
using DataFrames
using Dates

using Cbc
using GLPK
#using Gurobi for large scale programs (can be faster but must purchase license)

data = DataFrame(CSV.File("exampleflights.csv"))

# parameters for preference 
departure_city = "CHI"
departure_date = "3/23"
return_date = "3/30"

revisit = true
min_days = 1

# cities to attend
cities = unique([data.Departure; data.Arrival])

# model
model = Model(GLPK.Optimizer)

# decision variables
@variable(model, x[i=1:nrow(data)], Bin)  # Whether to take flight i
@variable(model, arrival_day[i=1:nrow(data)], Int)  # Arrival day at destination

# minimize costs 
@objective(model, Min, sum(data.Price[i] * x[i] for i in 1:nrow(data)))

# first flight location/date
@constraint(model, sum(x[i] for i in 1:nrow(data) if data.Departure[i] == departure_city && data.Date[i] == departure_date) == 1)

# last flight location/date
@constraint(model, sum(x[i] for i in 1:nrow(data) if data.Arrival[i] == departure_city && data.Date[i] == return_date) == 1)

# each city visited once
for city in cities
    @constraint(model, sum(x[i] for i in 1:nrow(data) if data.Arrival[i] == city) >= 1)  # One incoming flight to city
    @constraint(model, sum(x[i] for i in 1:nrow(data) if data.Departure[i] == city) >= 1)  # One outgoing flight from city
end

# each flight is at least min_days apart
for i in 2:nrow(data)  # Start from the second flight
    @constraint(model, arrival_day[i] - arrival_day[i-1] >= min_days)  # At least 2 days between consecutive flights
end

# return to departure city
@constraint(model, sum(x[i] for i in 1:nrow(data) if data.Arrival[i] == departure_city) == 1)

# solve
optimize!(model)

# results
if termination_status(model) == MOI.OPTIMAL
    println("Optimal solution found!")
    println("Total cost: \$", objective_value(model))

    # collect flights/dates
    selected_flights = []
    for i in 1:nrow(data)
        if value(x[i]) > 0.5
            push!(selected_flights, (data.Departure[i], data.Arrival[i], data.Date[i], data.Price[i]))
        end
    end

    # sort by dates in order
    sorted_flights = sort(selected_flights, by = x -> Date(x[3], "m/d"))  # assuming Date format is "m/d"

    # print
    for flight in sorted_flights
        println("Take flight from $(flight[1]) to $(flight[2]) on $(flight[3]) for \$$(flight[4])")
    end
else
    println("No optimal solution found.")
end
