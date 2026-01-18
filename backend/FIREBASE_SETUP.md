# Firebase Migration Setup Guide

## Overview
The DermaScan backend has been successfully migrated from MySQL to Firebase Firestore.

## Prerequisites
- Firebase project created at [Firebase Console](https://console.firebase.google.com)
- Node.js and npm installed

## Setup Steps

### 1. Install Dependencies
```bash
npm install
```

### 2. Get Firebase Service Account Key
1. Go to Firebase Console → Project Settings
2. Navigate to Service Accounts tab
3. Click "Generate New Private Key"
4. Save the JSON file as `serviceAccountKey.json` in the backend directory

### 3. Configure Environment Variables
Create a `.env` file in the backend directory:

```env
NODE_ENV=development
FIREBASE_DATABASE_URL=https://your-project.firebaseio.com
PORT=5000
```

Replace `your-project` with your actual Firebase project ID.

### 4. Database Collections
The following Firestore collections are used:

#### login
- Document ID: Auto-generated
- Fields:
  - `username` (string, unique)
  - `password` (string, hashed with bcryptjs)
  - `role` (string)
  - `created_at` (ISO timestamp)
  - `updated_at` (ISO timestamp)

#### predictions
- Document ID: Auto-generated
- Fields:
  - `user_id` (string)
  - `image_path` (string)
  - `disease_name` (string)
  - `confidence` (number)
  - `description` (string)
  - `created_at` (ISO timestamp)
  - `updated_at` (ISO timestamp)

#### health_check
- Used internally for health check endpoint

### 5. Start the Server
```bash
# Development mode with auto-reload
npm run dev

# Production mode
npm start
```

## Key Changes from MySQL

### Authentication
- **Before**: Plain text password comparison
- **After**: Passwords are hashed using bcryptjs with 10 salt rounds

### Query Structure
- **Before**: SQL queries with parameters
- **After**: Firestore query methods with .where(), .orderBy(), etc.

### IDs
- **Before**: Auto-incremented integers
- **After**: Firebase auto-generated document IDs (strings)

### Timestamps
- **Before**: MySQL TIMESTAMP with ON UPDATE
- **After**: ISO 8601 string timestamps

## API Endpoints
All endpoints remain the same:

```
POST /api/auth/login
POST /api/auth/register
GET /api/predictions/:userid
POST /api/predictions
GET /api/predictions/detail/:id
GET /api/health
```

## Firestore Security Rules
Consider adding security rules to your Firestore database:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /login/{document=**} {
      allow read, write: if request.auth != null;
    }
    match /predictions/{document=**} {
      allow read, write: if request.auth.uid == resource.data.user_id;
    }
    match /health_check/{document=**} {
      allow write: if true;
    }
  }
}
```

## Troubleshooting

### "Cannot find module 'serviceAccountKey.json'"
- Ensure your service account key file exists in the backend directory
- Run: `firebase init admin-sdk` if you need to regenerate it

### "FIREBASE_DATABASE_URL not found"
- Add FIREBASE_DATABASE_URL to your .env file

### "Insufficient permissions" errors
- Check your Firestore security rules
- Verify service account has proper permissions

## Migration Notes
- All existing data needs to be manually migrated from MySQL to Firestore
- Consider creating a migration script if you have substantial data
- Test all endpoints after deployment
