# Firestore Structure for Comments, Likes, and Shares

## Collections and Documents

### 1. Posts Collection
This collection already exists in your app. We've updated the post document structure to include:

```
posts/{postId}
{
  userId: string,
  userName: string,
  userAvatar: string,
  content: string,
  movieId: string,
  movieTitle: string,
  moviePosterUrl: string,
  movieYear: string,
  movieOverview: string,
  createdAt: timestamp,
  likes: array<string>, // Array of user IDs who liked the post
  commentCount: number, // Counter for number of comments
  shares: array<string>, // Array of user IDs who shared the post
  rating: number
}
```

### 2. Comments Collection
This is a new top-level collection to store all comments:

```
comments/{commentId}
{
  postId: string, // Reference to the post this comment belongs to
  userId: string, // User who created the comment
  userName: string,
  userAvatar: string,
  content: string,
  createdAt: timestamp,
  likes: array<string> // Array of user IDs who liked the comment
}
```

## Firestore Rules

You should update your Firestore security rules to protect these collections. Here's a basic example:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Posts rules
    match /posts/{postId} {
      allow read: if true; // Anyone can read posts
      allow create: if request.auth != null; // Only authenticated users can create posts
      allow update: if request.auth != null && 
                     (request.auth.uid == resource.data.userId || // Post owner can update
                      request.resource.data.diff(resource.data).affectedKeys().hasOnly(['likes', 'commentCount', 'shares'])); // Anyone can update likes, commentCount, shares
      allow delete: if request.auth != null && request.auth.uid == resource.data.userId; // Only post owner can delete
    }
    
    // Comments rules
    match /comments/{commentId} {
      allow read: if true; // Anyone can read comments
      allow create: if request.auth != null; // Only authenticated users can create comments
      allow update: if request.auth != null && 
                     (request.auth.uid == resource.data.userId || // Comment owner can update
                      request.resource.data.diff(resource.data).affectedKeys().hasOnly(['likes'])); // Anyone can update likes
      allow delete: if request.auth != null && request.auth.uid == resource.data.userId; // Only comment owner can delete
    }
  }
}
```

## Indexes

You'll need to create the following indexes to support the queries used in the app:

1. For the `comments` collection:
   - Fields indexed: `postId` (Ascending), `createdAt` (Ascending)
   - Query scope: Collection

2. For the `posts` collection (if not already created):
   - Fields indexed: `createdAt` (Descending), `userId` (Ascending)
   - Query scope: Collection

3. For the `watchlist_items` collection:
   - Fields indexed: `userId` (Ascending), `movie.id` (Ascending)
   - Query scope: Collection
   
4. For the `watchlist_items` collection (for filtered queries):
   - Fields indexed: `userId` (Ascending), `addedAt` (Descending)
   - Query scope: Collection
   
5. For the `watchlist_items` collection (for sorting by title):
   - Fields indexed: `userId` (Ascending), `movie.title` (Ascending/Descending)
   - Query scope: Collection
   
6. For the `watchlist_items` collection (for sorting by year):
   - Fields indexed: `userId` (Ascending), `movie.year` (Ascending/Descending)
   - Query scope: Collection

## Implementation Notes

1. **Comments**: We're using a separate top-level collection for comments rather than a subcollection. This makes it easier to query all comments for a post and to maintain the comment count on the post document.

2. **Likes**: Both posts and comments store likes as arrays of user IDs. This approach works well for a moderate number of likes. If your app scales to have posts with thousands of likes, you might want to consider a different approach, such as a subcollection of likes.

3. **Shares**: Similar to likes, shares are stored as an array of user IDs in the post document.

4. **Counter**: The `commentCount` field in the post document is a counter that is incremented when a comment is added and decremented when a comment is deleted. This allows for efficient display of the comment count without having to query all comments.

## How to Create in Firebase Console

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to "Firestore Database" in the left sidebar
4. The `posts` collection likely already exists
5. You don't need to manually create the `comments` collection - it will be created automatically when the first comment is added through the app
6. Go to the "Rules" tab to update your security rules
7. Go to the "Indexes" tab to create the necessary indexes
