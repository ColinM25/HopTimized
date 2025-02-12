using JuMP
using GLPK
using CSV
using DataFrames

# load data and define teams
flights = CSV.read("data/WCflights.csv", DataFrame)
hotels = CSV.read("data/WChotels.csv", DataFrame)
tickets = CSV.read("data/WCtickets.csv", DataFrame)
teams = unique(vcat(flights.Team, hotels.Team, tickets.Team))

team_locations = Dict(
    "HOU" => "Houston, TX",
    "LAR" => "Los Angeles, CA",
    "BUF" => "Buffalo, NY",
    "BAL" => "Baltimore, MD",
    "TB" => "Tampa Bay, FL",
    "PHI" => "Philadelphia, PA"
)

# parameters based on travel preferance 
budget = nothing
num_travelers = 4
min_rating = 9.0
min_tier = 1
selected_team = nothing

model = Model(GLPK.Optimizer)

# variable for each team
@variable(model, y_team[1:length(teams)], Bin)
@constraint(model, sum(y_team[t] for t in 1:length(teams)) == 1)

# if you want to attend a specific game
if selected_team != "" && selected_team != nothing
    @constraint(model, y_team[findfirst(==(selected_team), teams)] == 1)
end

# variables for flights, hotel, and tickets
@variable(model, x_f[1:size(flights, 1)], Bin)
@variable(model, x_h[1:size(hotels, 1)], Bin)
@variable(model, x_t[1:size(tickets, 1)], Bin)

# ensures only selecting flight,hotel,tickets if the team is selected (y_team)
@constraint(model, [i in 1:size(flights, 1)], x_f[i] <= y_team[findfirst(==(flights.Team[i]), teams)])
@constraint(model, [j in 1:size(hotels, 1)], x_h[j] <= y_team[findfirst(==(hotels.Team[j]), teams)])
@constraint(model, [k in 1:size(tickets, 1)], x_t[k] <= y_team[findfirst(==(tickets.Team[k]), teams)])

# objective (minimize travel cost)
@objective(model, Min, 
    sum(flights.Price[i] * x_f[i] for i in 1:size(flights, 1)) +
    (1 / num_travelers) * sum(hotels.Price[j] * x_h[j] for j in 1:size(hotels, 1)) +
    sum(tickets.Price[k] * x_t[k] for k in 1:size(tickets, 1))
)

# constraints
# ensure chosen selection fits in the budget
if budget != "" && budget != nothing
    @constraint(model, 
    sum(flights.Price[i] * x_f[i] for i in 1:size(flights, 1)) +
    (1 / num_travelers) * sum(hotels.Price[j] * x_h[j] for j in 1:size(hotels, 1)) +
    sum(tickets.Price[k] * x_t[k] for k in 1:size(tickets, 1)) <= budget
    )
end

# ensure the hotel meets rating preference
if min_rating != "" && min_rating != nothing
    @constraint(model, [j in 1:size(hotels, 1)], x_h[j] * hotels.Rating[j] >= min_rating * x_h[j])
end

# ensure ticket tier meets ticket preference
if min_tier != "" && min_tier != nothing
    @constraint(model, [k in 1:size(tickets, 1)], x_t[k] * tickets.Tier[k] <= min_tier * x_t[k])
end

# ensure room type fits the number of travelers
@constraint(model, [j in 1:size(hotels, 1)],
    x_h[j] * hotels.Room_Type[j] >= num_travelers * x_h[j])

# ensure 1 flight, hotel, and ticket are selected
@constraint(model, sum(x_f[i] for i in 1:size(flights, 1)) >= 1)
@constraint(model, sum(x_h[j] for j in 1:size(hotels, 1)) >= 1)
@constraint(model, sum(x_t[k] for k in 1:size(tickets, 1)) >= 1)

optimize!(model)

# results
if termination_status(model) == MOI.OPTIMAL
    for i in 1:size(flights, 1)
        if value(x_f[i]) > 0.5
            println("Your travel destination is....... \n")
            println("$(team_locations[flights[i, 1]])\n")
            println("Flight: Your flight costs \$$(flights[i, 5]) with $(flights[i, 2]), " *
        "departs at $(flights[i, 3]), " *
        "and lands in $(team_locations[flights[i, 1]]) at $(flights[i, 4]).")
        end
    end

    for j in 1:size(hotels, 1)
        if value(x_h[j]) > 0.5
            println("Hotel: Your hotel is $(hotels[j, 2]) which costs \$$(hotels[j, 3]) total, " *
            "and has a $(hotels[j, 4]) rating on Booking.com")
        end
    end

    for k in 1:size(tickets, 1)
        if value(x_t[k]) > 0.5
            tier = tickets[k, 3]
            if tier == 1
                tier = "Lower bowl"
            elseif tier == 2
                tier = "Mid-level"
            elseif tier == 3
                tier = "Upper deck"
            end
            println("Tickets: Your tickets cost \$$(tickets[k,2]) and the seats are located in the $tier \n")
            println("With hotel expenses split almongst the party, the cost per traveler is....\n")
            println("\$", round(objective_value(model),digits = 2))
        end
    end
else
    println("No solution found. Try adjusting travel parameters to be less restrictive. ")
end
