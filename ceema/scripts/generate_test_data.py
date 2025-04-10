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

# Helper function to create timestamp
def create_timestamp(days_ago=0, hours_ago=0):
    now = datetime.datetime.now()
    timestamp = now - datetime.timedelta(days=days_ago, hours=hours_ago)
    return timestamp

# Create test data
def create_test_data():
    print("Starting test data generation...")
    
    # 1. Create test users
    users = create_users()
    
    # 2. Fetch movies from TMDB
    movies = fetch_movies_from_tmdb()
    
    # 3. Create follow relationships
    create_follow_relationships(users)
    
    # 4. Create diary entries
    diary_entries = create_diary_entries(users, movies)
    
    # 5. Create user preferences based on diary entries
    create_user_preferences(users, diary_entries, movies)
    
    # 6. Create posts
    posts = create_posts(users, movies)
    
    # 7. Create user interactions
    create_user_interactions(users, posts)
    
    print("Test data generation complete!")

# Create test users
def create_users():
    users = [
        {
            "id": "user1",
            "username": "Ahmed",
            "displayName": "Ahmed",
            "email": "ahmed@example.com",
            "bio": "Love action-packed movies!"
        },
        {
            "id": "user2",
            "username": "Layla",
            "displayName": "Layla",
            "email": "layla@example.com",
            "bio": "Indie dramas and character studies."
        },
        {
            "id": "user3",
            "username": "Omar",
            "displayName": "Omar",
            "email": "omar@example.com",
            "bio": "Always looking for a good laugh!"
        },
        {
            "id": "user4",
            "username": "Noor",
            "displayName": "Noor",
            "email": "noor@example.com",
            "bio": "The scarier, the better."
        },
        {
            "id": "user5",
            "username": "Youssef",
            "displayName": "Youssef",
            "email": "youssef@example.com",
            "bio": "I watch everything!"
        },
        {
            "id": "user6",
            "username": "Fatima",
            "displayName": "Fatima",
            "email": "fatima@example.com",
            "bio": "Classic movie enthusiast."
        },
        {
            "id": "user7",
            "username": "Khalid",
            "displayName": "Khalid",
            "email": "khalid@example.com",
            "bio": "Documentary lover."
        },
        {
            "id": "user8",
            "username": "Aisha",
            "displayName": "Aisha",
            "email": "aisha@example.com",
            "bio": "Sci-fi and fantasy fan."
        },
        {
            "id": "user9",
            "username": "Zain",
            "displayName": "Zain",
            "email": "zain@example.com",
            "bio": "Animation and anime enthusiast."
        },
        {
            "id": "user10",
            "username": "Mariam",
            "displayName": "Mariam",
            "email": "mariam@example.com",
            "bio": "Romantic movies are my guilty pleasure."
        },
        {
            "id": "user11",
            "username": "Rami",
            "displayName": "Rami",
            "email": "rami@example.com",
            "bio": "Thriller and mystery addict."
        },
        {
            "id": "user12",
            "username": "Huda",
            "displayName": "Huda",
            "email": "huda@example.com",
            "bio": "Foreign films and world cinema."
        },
        {
            "id": "user13",
            "username": "Tariq",
            "displayName": "Tariq",
            "email": "tariq@example.com",
            "bio": "Historical dramas and biopics."
        },
        {
            "id": "user14",
            "username": "Lina",
            "displayName": "Lina",
            "email": "lina@example.com",
            "bio": "Musicals and dance films."
        },
        {
            "id": "user15",
            "username": "Samir",
            "displayName": "Samir",
            "email": "samir@example.com",
            "bio": "Independent cinema lover."
        }
    ]
    
    for user in users:
        db.collection("users").document(user["id"]).set(user)
        print(f"Created user: {user['username']}")
    
    return users

# Fetch movies from TMDB
def fetch_movies_from_tmdb():
    movie_data = []
    
    # Genre IDs for different types of movies
    genre_types = {
        "action": 28,
        "drama": 18,
        "comedy": 35,
        "horror": 27,
        "romance": 10749,
        "sci-fi": 878,
        "animation": 16,
        "documentary": 99,
        "thriller": 53,
        "fantasy": 14
    }
    
    for genre_name, genre_id in genre_types.items():
        print(f"Fetching {genre_name} movies from TMDB...")
        
        # Get movies by genre
        movies_response = tmdb_api_call(
            "discover/movie", 
            {
                "with_genres": genre_id,
                "sort_by": "popularity.desc",
                "page": 1
            }
        )
        
        if "results" in movies_response:
            for movie_basic in movies_response["results"][:10]:  # Get top 10 for each genre
                movie_id = movie_basic["id"]
                
                # Get detailed movie info
                movie_details = tmdb_api_call(f"movie/{movie_id}")
                
                # Get credits
                credits = tmdb_api_call(f"movie/{movie_id}/credits")
                
                if movie_details and credits:
                    # Format the data for Firestore
                    movie = {
                        "id": str(movie_id),
                        "title": movie_details.get("title", "Unknown Title"),
                        "posterUrl": f"{TMDB_IMAGE_BASE_URL}{movie_details.get('poster_path', '')}",
                        "year": movie_details.get("release_date", "")[:4] if movie_details.get("release_date") else "",
                        "overview": movie_details.get("overview", ""),
                        "genres": [{"id": str(g["id"]), "name": g["name"]} for g in movie_details.get("genres", [])],
                        "credits": {
                            "cast": [
                                {
                                    "id": str(actor["id"]),
                                    "name": actor["name"],
                                    "character": actor.get("character", "")
                                } for actor in credits.get("cast", [])[:10]  # Top 10 cast
                            ],
                            "crew": [
                                {
                                    "id": str(crew["id"]),
                                    "name": crew["name"],
                                    "job": crew["job"]
                                } for crew in credits.get("crew", []) if crew["job"] == "Director"
                            ]
                        }
                    }
                    
                    movie_data.append(movie)
                    
                    # Add to Firestore
                    db.collection("movies").document(movie["id"]).set(movie)
                    print(f"Added movie: {movie['title']}")
    
    print(f"Fetched {len(movie_data)} movies from TMDB")
    return movie_data

# Create follow relationships
def create_follow_relationships(users):
    follows = []
    
    # Make sure every user follows at least 2 other users
    for user in users:
        user_id = user["id"]
        # Get other users this user could follow
        potential_follows = [u for u in users if u["id"] != user_id]
        
        # Randomly select at least 2, up to 4 users to follow
        num_to_follow = random.randint(2, min(4, len(potential_follows)))
        users_to_follow = random.sample(potential_follows, num_to_follow)
        
        for follow_user in users_to_follow:
            follow_id = f"{user_id}_follows_{follow_user['id']}"
            follow = {
                "followerId": user_id,
                "followerName": user["username"],
                "followedId": follow_user["id"],
                "followedName": follow_user["username"],
                "createdAt": create_timestamp(random.randint(1, 30))
            }
            
            follows.append(follow)
            db.collection("follows").document(follow_id).set(follow)
            print(f"Created follow: {user['username']} follows {follow_user['username']}")
    
    return follows

# Create diary entries
def create_diary_entries(users, movies):
    diary_entries = []
    
    # Create user-specific affinities
    user_affinities = {
        "user1": {"action": 5.0, "drama": 3.0, "comedy": 3.5, "horror": 2.0, "romance": 2.5, "sci-fi": 4.0, "animation": 3.0, "documentary": 2.0, "thriller": 4.5, "fantasy": 3.5},
        "user2": {"action": 2.5, "drama": 5.0, "comedy": 3.0, "horror": 2.5, "romance": 4.5, "sci-fi": 3.0, "animation": 2.5, "documentary": 4.0, "thriller": 3.5, "fantasy": 3.0},
        "user3": {"action": 3.0, "drama": 2.5, "comedy": 5.0, "horror": 2.0, "romance": 3.5, "sci-fi": 3.5, "animation": 4.5, "documentary": 2.5, "thriller": 3.0, "fantasy": 4.0},
        "user4": {"action": 3.0, "drama": 3.5, "comedy": 2.0, "horror": 5.0, "romance": 2.0, "sci-fi": 4.0, "animation": 2.5, "documentary": 3.0, "thriller": 4.5, "fantasy": 3.5},
        "user5": {"action": 4.0, "drama": 4.0, "comedy": 4.0, "horror": 4.0, "romance": 4.0, "sci-fi": 4.0, "animation": 4.0, "documentary": 4.0, "thriller": 4.0, "fantasy": 4.0},
        "user6": {"action": 3.0, "drama": 5.0, "comedy": 3.5, "horror": 2.0, "romance": 4.5, "sci-fi": 2.5, "animation": 3.0, "documentary": 4.0, "thriller": 3.5, "fantasy": 3.0},
        "user7": {"action": 2.5, "drama": 4.0, "comedy": 3.0, "horror": 2.5, "romance": 3.0, "sci-fi": 3.5, "animation": 2.0, "documentary": 5.0, "thriller": 3.0, "fantasy": 2.5},
        "user8": {"action": 4.0, "drama": 3.0, "comedy": 3.5, "horror": 3.0, "romance": 2.5, "sci-fi": 5.0, "animation": 4.0, "documentary": 2.0, "thriller": 4.5, "fantasy": 5.0},
        "user9": {"action": 3.5, "drama": 2.5, "comedy": 4.0, "horror": 2.0, "romance": 3.0, "sci-fi": 3.5, "animation": 5.0, "documentary": 2.5, "thriller": 3.0, "fantasy": 4.5},
        "user10": {"action": 2.0, "drama": 4.0, "comedy": 3.5, "horror": 2.5, "romance": 5.0, "sci-fi": 3.0, "animation": 4.0, "documentary": 2.5, "thriller": 3.5, "fantasy": 4.0},
        "user11": {"action": 4.5, "drama": 3.5, "comedy": 2.5, "horror": 4.0, "romance": 2.0, "sci-fi": 3.5, "animation": 2.5, "documentary": 3.0, "thriller": 5.0, "fantasy": 3.0},
        "user12": {"action": 3.0, "drama": 5.0, "comedy": 3.0, "horror": 2.5, "romance": 4.0, "sci-fi": 3.0, "animation": 2.5, "documentary": 4.5, "thriller": 3.5, "fantasy": 3.0},
        "user13": {"action": 4.0, "drama": 5.0, "comedy": 3.0, "horror": 2.0, "romance": 3.5, "sci-fi": 3.0, "animation": 2.5, "documentary": 4.0, "thriller": 3.5, "fantasy": 3.0},
        "user14": {"action": 3.0, "drama": 4.5, "comedy": 4.0, "horror": 2.0, "romance": 4.0, "sci-fi": 2.5, "animation": 4.5, "documentary": 3.0, "thriller": 3.0, "fantasy": 4.0},
        "user15": {"action": 3.5, "drama": 5.0, "comedy": 3.0, "horror": 2.5, "romance": 3.0, "sci-fi": 3.5, "animation": 2.5, "documentary": 4.0, "thriller": 3.0, "fantasy": 3.5}
    }
    
    # Map genres to their type for rating calculation
    genre_to_type = {
        "28": "action",    # Action
        "18": "drama",     # Drama
        "35": "comedy",    # Comedy
        "27": "horror",    # Horror
        "10749": "romance", # Romance
        "878": "sci-fi",   # Sci-Fi
        "16": "animation", # Animation
        "99": "documentary", # Documentary
        "53": "thriller",  # Thriller
        "14": "fantasy"    # Fantasy
    }
    
    # Each user watches and rates several movies
    for user in users:
        user_id = user["id"]
        affinities = user_affinities[user_id]
        
        # Each user watches 8-12 movies
        num_movies = random.randint(8, 12)
        user_movies = random.sample(movies, num_movies)
        
        for movie in user_movies:
            # Calculate rating based on user's genre affinities and some randomness
            base_rating = 3.0  # Default rating
            for genre in movie["genres"]:
                genre_id = genre["id"]
                if genre_id in genre_to_type:
                    genre_type = genre_to_type[genre_id]
                    if genre_type in affinities:
                        # Influence rating based on user's affinity for this genre
                        affinity_boost = affinities[genre_type] - 3.0  # Convert to a +/- modifier
                        base_rating += affinity_boost * 0.5  # Dampen the effect a bit
            
            # Add some randomness (-0.5 to +0.5)
            rating = max(0.5, min(5.0, base_rating + (random.random() - 0.5)))
            rating = round(rating * 2) / 2  # Round to nearest 0.5
            
            # Create diary entry
            entry_id = f"{user_id}_{movie['id']}"
            watched_date = create_timestamp(random.randint(1, 180))  # Random date in last 180 days
            
            # Generate review text based on rating
            review = ""
            if rating >= 4.5:
                review = f"Absolutely loved {movie['title']}! One of my favorites."
            elif rating >= 3.5:
                review = f"Really enjoyed {movie['title']}. Would recommend."
            elif rating >= 2.5:
                review = f"{movie['title']} was okay. Had some good moments."
            else:
                review = f"Didn't really enjoy {movie['title']}. Not my type of movie."
            
            entry = {
                "id": entry_id,
                "userId": user_id,
                "movieId": movie["id"],
                "movieTitle": movie["title"],
                "moviePosterUrl": movie["posterUrl"],
                "movieYear": movie["year"],
                "rating": rating,
                "review": review,
                "watchedDate": watched_date,
                "isFavorite": rating >= 4.5,
                "isRewatch": random.random() < 0.2,  # 20% chance it's a rewatch
                "createdAt": create_timestamp(random.randint(1, 180))
            }
            
            diary_entries.append(entry)
            db.collection("diary_entries").document(entry_id).set(entry)
            print(f"Created diary entry: {user['username']} watched {movie['title']} - rated {rating}/5.0")
    
    return diary_entries

# Create user preferences based on diary entries
def create_user_preferences(users, diary_entries, movies):
    for user in users:
        user_id = user["id"]
        
        # Get this user's diary entries
        user_entries = [entry for entry in diary_entries if entry["userId"] == user_id]
        
        # Build preferences from highly rated movies (>=3.5)
        likes = []
        
        # Track movie IDs that were disliked
        disliked_movie_ids = []
        
        # Process diary entries
        for entry in user_entries:
            movie_id = entry["movieId"]
            movie = next((m for m in movies if m["id"] == movie_id), None)
            
            if not movie:
                continue
                
            # Add genres, directors, and actors from highly rated movies
            if entry["rating"] >= 3.5:
                # Add liked genres
                for genre in movie["genres"]:
                    weight = min(1.0, (entry["rating"] - 2.5) / 2.5)  # Scale weight based on rating
                    likes.append({
                        "id": genre["id"],
                        "type": "genre",
                        "name": genre["name"],
                        "weight": weight
                    })
                
                # Add liked directors
                for crew in movie["credits"]["crew"]:
                    if crew["job"] == "Director":
                        weight = min(1.0, (entry["rating"] - 2.5) / 2.5)
                        likes.append({
                            "id": crew["id"],
                            "type": "director",
                            "name": crew["name"],
                            "weight": weight
                        })
                
                # Add liked actors (only the top 2)
                for actor in movie["credits"]["cast"][:2]:
                    weight = min(1.0, (entry["rating"] - 2.5) / 2.5)
                    likes.append({
                        "id": actor["id"],
                        "type": "actor",
                        "name": actor["name"],
                        "weight": weight
                    })
            
            # Add disliked movies
            if entry["rating"] <= 2.0:
                disliked_movie_ids.append(movie_id)
        
        # Create dislikes list (we'll just use low-rated movies' genres)
        dislikes = []
        for entry in user_entries:
            if entry["rating"] <= 2.0:
                movie_id = entry["movieId"]
                movie = next((m for m in movies if m["id"] == movie_id), None)
                
                if not movie:
                    continue
                    
                # Add disliked genres
                for genre in movie["genres"]:
                    weight = min(1.0, (2.5 - entry["rating"]) / 2.5)  # Higher weight for lower ratings
                    dislikes.append({
                        "id": genre["id"],
                        "type": "genre",
                        "name": genre["name"],
                        "weight": weight
                    })
        
        # Consolidate likes/dislikes (merge duplicates by summing weights)
        consolidated_likes = {}
        for like in likes:
            key = f"{like['type']}_{like['id']}"
            if key in consolidated_likes:
                consolidated_likes[key]["weight"] = min(1.0, consolidated_likes[key]["weight"] + like["weight"])
            else:
                consolidated_likes[key] = like
                
        consolidated_dislikes = {}
        for dislike in dislikes:
            key = f"{dislike['type']}_{dislike['id']}"
            if key in consolidated_dislikes:
                consolidated_dislikes[key]["weight"] = min(1.0, consolidated_dislikes[key]["weight"] + dislike["weight"])
            else:
                consolidated_dislikes[key] = dislike
        
        # Create user preferences
        preference = {
            "userId": user_id,
            "likes": list(consolidated_likes.values()),
            "dislikes": list(consolidated_dislikes.values()),
            "importanceFactors": {
                "story": random.uniform(0.7, 1.0),
                "acting": random.uniform(0.7, 1.0),
                "visuals": random.uniform(0.7, 1.0),
                "soundtrack": random.uniform(0.7, 1.0),
                "pacing": random.uniform(0.7, 1.0)
            },
            "dislikedMovieIds": disliked_movie_ids
        }
        
        db.collection("user_preferences").document(user_id).set(preference)
        print(f"Created preferences for {user['username']}: {len(preference['likes'])} likes, {len(preference['dislikes'])} dislikes")

# Create posts
def create_posts(users, movies):
    posts = []
    
    # Each user makes posts about some of the movies
    for user in users:
        user_id = user["id"]
        
        # Choose 5-8 random movies for this user to post about
        num_posts = random.randint(5, 8)
        post_movies = random.sample(movies, num_posts)
        
        for movie in post_movies:
            # Generate post content
            content_templates = [
                f"Just watched {movie['title']}! {random.choice(['Loved it!', 'It was pretty good.', 'Highly recommend it!', 'One of my favorites now.'])}",
                f"Finally got around to seeing {movie['title']}. {random.choice(['Worth the wait!', 'Not what I expected.', 'So good!', 'Classic film.'])}",
                f"{movie['title']} is {random.choice(['amazing', 'incredible', 'worth watching', 'a masterpiece'])}. The {random.choice(['acting', 'directing', 'cinematography', 'story'])} was outstanding.",
                f"My thoughts on {movie['title']}: {random.choice(['A must-see!', 'Solid entertainment.', 'Not bad at all.', 'Exceeded expectations!'])}",
                f"Watched {movie['title']} last night. {random.choice(['What a ride!', 'So many emotions.', 'Cannot stop thinking about it.', 'Already planning to rewatch.'])}",
                f"Just finished {movie['title']}. {random.choice(['Mind blown!', 'So many layers to unpack.', 'The ending was perfect.', 'Need to process this one.'])}",
                f"{movie['title']} - {random.choice(['Instant classic', 'Underrated gem', 'Hidden treasure', 'Modern masterpiece'])}",
                f"Cannot believe I waited this long to watch {movie['title']}. {random.choice(['Worth every minute!', 'What was I thinking?', 'Better late than never.', 'Should have watched it sooner.'])}"
            ]
            content = random.choice(content_templates)
            
            # Create post
            post_id = f"post_{user_id}_{movie['id']}"
            created_at = create_timestamp(random.randint(1, 90))  # Post made in last 90 days
            
            # Generate random number of likes (0-20)
            num_likes = random.randint(0, 20)
            likers = random.sample([u["id"] for u in users if u["id"] != user_id], min(num_likes, len(users)-1))
            
            # Generate random rating (if any)
            rating = 0.0
            if random.random() < 0.7:  # 70% chance of including a rating
                rating = random.randint(1, 5)
            
            post = {
                "id": post_id,
                "userId": user_id,
                "userName": user["username"],
                "content": content,
                "movieId": movie["id"],
                "movieTitle": movie["title"],
                "moviePosterUrl": movie["posterUrl"],
                "movieYear": movie["year"],
                "movieOverview": movie["overview"],
                "createdAt": created_at,
                "likes": likers,
                "commentCount": random.randint(0, 12),
                "rating": rating
            }
            
            posts.append(post)
            db.collection("posts").document(post_id).set(post)
            print(f"Created post: {user['username']} posted about {movie['title']} - {len(likers)} likes")
    
    return posts

# Create user interactions (views, likes, etc.)
def create_user_interactions(users, posts):
    interactions = []
    
    # Each user interacts with several posts
    for user in users:
        user_id = user["id"]
        
        # Choose random posts to interact with (excluding own posts)
        other_posts = [post for post in posts if post["userId"] != user_id]
        num_interactions = min(len(other_posts), random.randint(8, 20))  # Increased from 5-15 to 8-20
        interaction_posts = random.sample(other_posts, num_interactions)
        
        for post in interaction_posts:
            # View interaction
            view_time = random.randint(5, 180)  # Increased from 5-120 to 5-180 seconds
            view_percentage = random.randint(50, 100)  # 50% to 100% viewed
            
            view_interaction = {
                "userId": user_id,
                "postId": post["id"],
                "actionType": "view",
                "timestamp": create_timestamp(random.randint(0, 30)),
                "source": random.choice(["timeline", "profile", "search", "recommend"]),
                "viewPercentage": view_percentage,
                "viewTimeSeconds": view_time
            }
            
            interaction_id = f"{user_id}_{post['id']}_view"
            interactions.append(view_interaction)
            db.collection("userInteractions").document(interaction_id).set(view_interaction)
            
            # Like interaction (60% chance, increased from 50%)
            if random.random() < 0.6 and user_id not in post["likes"]:
                like_interaction = {
                    "userId": user_id,
                    "postId": post["id"],
                    "actionType": "like",
                    "timestamp": create_timestamp(random.randint(0, 30)),
                    "source": random.choice(["timeline", "profile", "search", "recommend"])
                }
                
                interaction_id = f"{user_id}_{post['id']}_like"
                interactions.append(like_interaction)
                db.collection("userInteractions").document(interaction_id).set(like_interaction)
                
                # Also update the post's likes array
                db.collection("posts").document(post["id"]).update({
                    "likes": firestore.ArrayUnion([user_id])
                })
            
            # Comment interaction (40% chance, increased from 30%)
            if random.random() < 0.4:
                comment_templates = [
                    "Great post!",
                    "I totally agree!",
                    "I need to watch this one.",
                    "One of my favorites too!",
                    "Interesting take on this movie.",
                    "Nice review!",
                    "Thanks for sharing!",
                    "I had different thoughts on this one.",
                    "Have you seen the sequel?",
                    "Who was your favorite character?",
                    "The cinematography was stunning!",
                    "The soundtrack was amazing!",
                    "The ending was perfect!",
                    "The acting was incredible!",
                    "The story was so engaging!",
                    "The direction was masterful!",
                    "The special effects were impressive!",
                    "The character development was excellent!",
                    "The plot twists were unexpected!",
                    "The dialogue was so well-written!"
                ]
                
                comment_content = random.choice(comment_templates)
                
                comment_interaction = {
                    "userId": user_id,
                    "postId": post["id"],
                    "actionType": "comment",
                    "timestamp": create_timestamp(random.randint(0, 30)),
                    "source": random.choice(["timeline", "profile", "search", "recommend"]),
                    "additionalData": {"content": comment_content}
                }
                
                interaction_id = f"{user_id}_{post['id']}_comment_{int(time.time())}"
                interactions.append(comment_interaction)
                db.collection("userInteractions").document(interaction_id).set(comment_interaction)
                
                # Also create the actual comment document
                comment = {
                    "userId": user_id,
                    "userName": user["username"],
                    "content": comment_content,
                    "postId": post["id"],
                    "createdAt": create_timestamp(random.randint(0, 30)),
                    "likes": []
                }
                
                db.collection("posts").document(post["id"]).collection("comments").add(comment)
                
                # Update comment count on post
                db.collection("posts").document(post["id"]).update({
                    "commentCount": firestore.Increment(1)
                })
    
    print(f"Created {len(interactions)} user interactions")
    return interactions

if __name__ == "__main__":
    create_test_data() 