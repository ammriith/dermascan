const express = require('express');
const { db, auth, admin } = require('../db');
const bcryptjs = require('bcryptjs');

const router = express.Router();

// Login endpoint
router.post('/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    
    if (!username || !password) {
      return res.status(400).json({ error: 'Username and password are required' });
    }
    
    // Query Firestore for user
    const usersSnapshot = await db.collection('login').where('username', '==', username).limit(1).get();
    
    if (usersSnapshot.empty) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    
    const userDoc = usersSnapshot.docs[0];
    const userData = userDoc.data();
    
    // Compare passwords using bcryptjs
    const isPasswordValid = await bcryptjs.compare(password, userData.password);
    
    if (!isPasswordValid) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    
    res.json({
      message: 'Login successful',
      user: {
        userid: userDoc.id,
        username: userData.username,
        role: userData.role
      }
    });
  } catch (error) {
    console.error('Error during login:', error);
    res.status(500).json({ error: 'Failed to login' });
  }
});

// Register endpoint
router.post('/register', async (req, res) => {
  try {
    const { username, password, role } = req.body;
    
    if (!username || !password || !role) {
      return res.status(400).json({ error: 'Username, password, and role are required' });
    }
    
    // Check if username already exists
    const existingUser = await db.collection('login').where('username', '==', username).limit(1).get();
    
    if (!existingUser.empty) {
      return res.status(400).json({ error: 'Username already exists' });
    }
    
    // Hash password
    const hashedPassword = await bcryptjs.hash(password, 10);
    
    // Create new user document
    const newUserRef = await db.collection('login').add({
      username: username,
      password: hashedPassword,
      role: role,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    });
    
    res.status(201).json({
      message: 'User registered successfully',
      userid: newUserRef.id
    });
  } catch (error) {
    console.error('Error during registration:', error);
    res.status(500).json({ error: 'Failed to register' });
  }
});

module.exports = router;
