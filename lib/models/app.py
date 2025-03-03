from flask import Flask, request, jsonify
import tensorflow as tf
import joblib
import numpy as np

app = Flask(__name__)

# Load model and mappings
model = tf.keras.models.load_model('recommendation_model')
user_mapping = joblib.load('user_mapping.joblib')
movie_mapping = joblib.load('movie_mapping.joblib')

@app.route('/predict', methods=['POST'])
def predict():
    data = request.json
    user_id = data['userId']
    movie_ids = data['movieIds']
    
    # Convert IDs to indices
    user_idx = user_mapping.get(user_id, -1)
    movie_indices = [movie_mapping.get(id, -1) for id in movie_ids]
    
    if user_idx == -1:
        return jsonify({'error': 'Unknown user'})
    
    # Make predictions
    user_input = np.array([user_idx] * len(movie_indices))
    movie_input = np.array(movie_indices)
    
    predictions = model.predict([user_input, movie_input])
    
    # Format response
    results = [
        {'movieId': movie_id, 'score': float(score)}
        for movie_id, score in zip(movie_ids, predictions.flatten())
    ]
    
    return jsonify({'predictions': results})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)