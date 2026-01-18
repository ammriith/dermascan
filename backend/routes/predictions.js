const express = require('express');
const { db } = require('../db');

const router = express.Router();

// Get all predictions for a user
router.get('/predictions/:userid', async (req, res) => {
  try {
    const { userid } = req.params;
    
    const predictionsSnapshot = await db.collection('predictions')
      .where('user_id', '==', userid)
      .orderBy('created_at', 'desc')
      .get();
    
    const predictions = [];
    predictionsSnapshot.forEach(doc => {
      predictions.push({
        id: doc.id,
        ...doc.data()
      });
    });
    
    res.json(predictions);
  } catch (error) {
    console.error('Error fetching predictions:', error);
    res.status(500).json({ error: 'Failed to fetch predictions' });
  }
});

// Create a new prediction
router.post('/predictions', async (req, res) => {
  try {
    const { user_id, image_path, disease_name, confidence, description } = req.body;
    
    if (!user_id || !disease_name) {
      return res.status(400).json({ error: 'user_id and disease_name are required' });
    }
    
    const newPredictionRef = await db.collection('predictions').add({
      user_id: user_id,
      image_path: image_path || null,
      disease_name: disease_name,
      confidence: confidence || null,
      description: description || null,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    });
    
    res.status(201).json({
      id: newPredictionRef.id,
      message: 'Prediction created successfully'
    });
  } catch (error) {
    console.error('Error creating prediction:', error);
    res.status(500).json({ error: 'Failed to create prediction' });
  }
});

// Get prediction by ID
router.get('/predictions/detail/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const predictionDoc = await db.collection('predictions').doc(id).get();
    
    if (!predictionDoc.exists) {
      return res.status(404).json({ error: 'Prediction not found' });
    }
    
    res.json({
      id: predictionDoc.id,
      ...predictionDoc.data()
    });
  } catch (error) {
    console.error('Error fetching prediction:', error);
    res.status(500).json({ error: 'Failed to fetch prediction' });
  }
});

module.exports = router;
