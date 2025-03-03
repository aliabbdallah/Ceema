from flask import Flask, request, jsonify
import tensorflow as tf
import joblib
import numpy as np

app = Flask(__name__)

# Load model and mappings
print("Loading model and mappings...")
model = tf.keras.models.load_model('models/recommendation_model.keras')
user_mapping = joblib.load('models/user_mapping.joblib')
movie_mapping = joblib.load('models/movie_mapping.joblib')
print("Model and mappings loaded successfully!")

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'healthy'})

@app.route('/predict', methods=['POST'])
def predict():
    try:
        data = request.get_json()
        user_id = data['userId']
        movie_ids = data['movieIds']
        
        # Convert IDs to indices
        user_idx = user_mapping.get(str(user_id), -1)
        movie_indices = [movie_mapping.get(str(id), -1) for id in movie_ids]
        
        if user_idx == -1:
            return jsonify({
                'error': 'Unknown user',
                'status': 'error'
            }), 400
        
        # Make predictions
        user_input = np.array([user_idx] * len(movie_indices))
        movie_input = np.array(movie_indices)
        
        predictions = model.predict([user_input, movie_input])
        
        # Format response
        results = [
            {
                'movieId': str(movie_id),
                'score': float(score)
            }
            for movie_id, score in zip(movie_ids, predictions.flatten())
        ]
        
        return jsonify({
            'predictions': results,
            'status': 'success'
        })

    except Exception as e:
        return jsonify({
            'error': str(e),
            'status': 'error'
        }), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)