from flask import Flask, request, jsonify
import os
import json

app = Flask(__name__)

@app.route('/api/optimize', methods=['POST'])
def optimize():
    # Receive form data
    departure_airport = request.form['departureAirport']
    destination_airports = request.form.getlist('destinationAirports')
    departure_date = request.form['departureDate']
    return_date = request.form['returnDate']

    # Store data for further processing
    data = {
        "departure_airport": departure_airport,
        "destination_airports": destination_airports,
        "departure_date": departure_date,
        "return_date": return_date
    }

    # Save the data to a JSON file or database
    with open('user_data.json', 'w') as f:
        json.dump(data, f)

    # Respond to the client
    return jsonify({"message": "Data received and stored for processing."})

if __name__ == '__main__':
    app.run(debug=True)