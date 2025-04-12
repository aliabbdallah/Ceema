import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore
import requests
import json
import datetime
import time
import random
import uuid

# Initialize Firebase Admin SDK
cred = credentials.Certificate("scripts/service-account-key.json")
firebase_admin.initialize_app(cred)

db = firestore.client()

# TMDB API configuration
TMDB_API_KEY = "4ae207526acb81363b703e810d265acf"  # Replace with your actual API key
TMDB_BASE_URL = "https://api.themoviedb.org/3"
TMDB_IMAGE_BASE_URL = "https://image.tmdb.org/t/p/w500"

# Helper function for TMDB API calls
def tmdb_api_call(endpoint, params={}):
    params["api_key"] = TMDB_API_KEY
    response = requests.get(f"{TMDB_BASE_URL}/{endpoint}", params=params)
    return response.json() if response.status_code == 200 else {}

db = firestore.client()

# Helper function to create timestamp
def create_timestamp(days_ago=0, hours_ago=0):
    now = datetime.datetime.now()
    timestamp = now - datetime.timedelta(days=days_ago, hours=hours_ago)
    return timestamp

def add_more_users():
    """Adds 10 more users to the Firebase database"""
    
    # New users to add
    new_users = [
        {
            "id": "user16",
            "username": "Maya",
            "displayName": "Maya",
            "email": "maya@example.com",
            "bio": "Obsessed with sci-fi and adventure films!"
        },
        {
            "id": "user17",
            "username": "Hassan",
            "displayName": "Hassan",
            "email": "hassan@example.com",
            "bio": "Film student focusing on cinematography."
        },
        {
            "id": "user18",
            "username": "Leila",
            "displayName": "Leila",
            "email": "leila@example.com",
            "bio": "Animated films are my passion."
        },
        {
            "id": "user19",
            "username": "Karim",
            "displayName": "Karim",
            "email": "karim@example.com",
            "bio": "Film critic and podcast host."
        },
        {
            "id": "user20",
            "username": "Sophia",
            "displayName": "Sophia",
            "email": "sophia@example.com",
            "bio": "Vintage movies and old Hollywood glamour."
        },
        {
            "id": "user21",
            "username": "Amira",
            "displayName": "Amira",
            "email": "amira@example.com",
            "bio": "Psychological thrillers and crime drama."
        },
        {
            "id": "user22",
            "username": "Ziad",
            "displayName": "Ziad",
            "email": "ziad@example.com",
            "bio": "Film festival enthusiast and collector."
        },
        {
            "id": "user23",
            "username": "Dalia",
            "displayName": "Dalia",
            "email": "dalia@example.com",
            "bio": "Superhero movies and action franchises."
        },
        {
            "id": "user24",
            "username": "Jamal",
            "displayName": "Jamal",
            "email": "jamal@example.com",
            "bio": "Documentary filmmaker and nature lover."
        },
        {
            "id": "user25",
            "username": "Nadia",
            "displayName": "Nadia",
            "email": "nadia@example.com",
            "bio": "Korean and Japanese cinema enthusiast."
        },
    ]
    
    # Create user preferences data structure
    user_affinities = {
        "user16": {"action": 3.5, "drama": 3.0, "comedy": 3.0, "horror": 2.0, "romance": 3.0, "sci-fi": 5.0, "animation": 3.5, "documentary": 2.5, "thriller": 4.0, "fantasy": 4.5},
        "user17": {"action": 3.0, "drama": 4.5, "comedy": 2.5, "horror": 3.0, "romance": 3.5, "sci-fi": 4.0, "animation": 3.0, "documentary": 4.0, "thriller": 3.5, "fantasy": 3.0},
        "user18": {"action": 2.5, "drama": 3.0, "comedy": 4.0, "horror": 2.0, "romance": 3.5, "sci-fi": 3.5, "animation": 5.0, "documentary": 3.0, "thriller": 2.5, "fantasy": 4.0},
        "user19": {"action": 3.5, "drama": 4.5, "comedy": 3.5, "horror": 3.0, "romance": 3.0, "sci-fi": 3.5, "animation": 3.0, "documentary": 4.5, "thriller": 4.0, "fantasy": 3.5},
        "user20": {"action": 2.5, "drama": 5.0, "comedy": 3.0, "horror": 2.0, "romance": 4.5, "sci-fi": 2.5, "animation": 3.0, "documentary": 3.5, "thriller": 3.0, "fantasy": 2.5},
        "user21": {"action": 3.5, "drama": 4.0, "comedy": 2.5, "horror": 4.0, "romance": 2.5, "sci-fi": 3.5, "animation": 2.0, "documentary": 3.5, "thriller": 5.0, "fantasy": 3.0},
        "user22": {"action": 3.0, "drama": 4.5, "comedy": 3.0, "horror": 3.0, "romance": 3.5, "sci-fi": 3.5, "animation": 3.0, "documentary": 4.5, "thriller": 3.5, "fantasy": 3.5},
        "user23": {"action": 5.0, "drama": 3.0, "comedy": 3.5, "horror": 3.0, "romance": 3.0, "sci-fi": 4.5, "animation": 3.5, "documentary": 2.0, "thriller": 4.0, "fantasy": 4.5},
        "user24": {"action": 2.5, "drama": 3.5, "comedy": 3.0, "horror": 2.0, "romance": 2.5, "sci-fi": 3.0, "animation": 3.0, "documentary": 5.0, "thriller": 3.5, "fantasy": 2.5},
        "user25": {"action": 3.5, "drama": 4.5, "comedy": 3.0, "horror": 3.5, "romance": 4.0, "sci-fi": 4.0, "animation": 4.5, "documentary": 3.5, "thriller": 4.0, "fantasy": 3.5},
    }
    
    # Add users to Firestore
    for user in new_users:
        db.collection("users").document(user["id"]).set(user)
        print(f"Created user: {user['username']}")
        
        # Create basic preference structure for each user
        preference = {
            "userId": user["id"],
            "likes": [],  # Will be populated when they rate movies
            "dislikes": [],  # Will be populated when they rate movies
            "importanceFactors": {
                "story": random.uniform(0.7, 1.0),
                "acting": random.uniform(0.7, 1.0),
                "visuals": random.uniform(0.7, 1.0),
                "soundtrack": random.uniform(0.7, 1.0),
                "pacing": random.uniform(0.7, 1.0)
            },
            "dislikedMovieIds": []
        }
        
        db.collection("user_preferences").document(user["id"]).set(preference)
        print(f"Created preferences for {user['username']}")
    
    # Create follow relationships for new users
    # Get existing users to create relationships with
    existing_users_ref = db.collection("users").limit(15).stream()  # Get first 15 users
    existing_users = [{"id": doc.id, "username": doc.to_dict().get("username")} for doc in existing_users_ref]
    
    for user in new_users:
        user_id = user["id"]
        # Each new user follows 3-5 existing users
        num_to_follow = random.randint(3, 5)
        users_to_follow = random.sample(existing_users, num_to_follow)
        
        for follow_user in users_to_follow:
            follow_id = f"{user_id}_follows_{follow_user['id']}"
            follow = {
                "followerId": user_id,
                "followerName": user["username"],
                "followedId": follow_user["id"],
                "followedName": follow_user["username"],
                "createdAt": create_timestamp(random.randint(1, 15))
            }
            
            db.collection("follows").document(follow_id).set(follow)
            print(f"Created follow: {user['username']} follows {follow_user['username']}")
        
        # Some existing users follow the new users too (2-4 each)
        num_followers = random.randint(2, 4)
        followers = random.sample(existing_users, num_followers)
        
        for follower in followers:
            follow_id = f"{follower['id']}_follows_{user_id}"
            follow = {
                "followerId": follower["id"],
                "followerName": follower["username"],
                "followedId": user_id,
                "followedName": user["username"],
                "createdAt": create_timestamp(random.randint(1, 10))
            }
            
            db.collection("follows").document(follow_id).set(follow)
            print(f"Created follow: {follower['username']} follows {user['username']}")
    
    print(f"Successfully added {len(new_users)} new users!")
    return new_users

# Execute function if this script is run directly
if __name__ == "__main__":
    add_more_users()