#!/bin/bash

# Attendify Firebase Indexes Deployment Script
# This script deploys Firestore indexes and security rules

echo "🔥 Attendify - Firebase Deployment Script"
echo "=========================================="
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found!"
    echo "Install it with: npm install -g firebase-tools"
    exit 1
fi

echo "✅ Firebase CLI found (version: $(firebase --version))"
echo ""

# Check if logged in
echo "📝 Checking Firebase login status..."
firebase projects:list &> /dev/null
if [ $? -ne 0 ]; then
    echo "❌ Not logged in to Firebase"
    echo "Please run: firebase login"
    exit 1
fi

echo "✅ Logged in to Firebase"
echo ""

# Show current project
echo "📋 Current Firebase project:"
firebase use
echo ""

# Ask for confirmation
read -p "🤔 Do you want to deploy Firestore indexes and rules? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Deployment cancelled"
    exit 0
fi

echo ""
echo "🚀 Deploying Firestore indexes..."
echo "⏳ This may take a few minutes..."
echo ""

# Deploy indexes
firebase deploy --only firestore:indexes

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Indexes deployed successfully!"
    echo ""
else
    echo ""
    echo "❌ Index deployment failed!"
    echo "Check the error message above"
    exit 1
fi

# Ask about security rules
read -p "🤔 Deploy security rules too? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "🚀 Deploying Firestore security rules..."
    firebase deploy --only firestore:rules
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ Security rules deployed successfully!"
    else
        echo ""
        echo "❌ Security rules deployment failed!"
        exit 1
    fi
fi

echo ""
echo "=========================================="
echo "✨ Deployment Complete!"
echo "=========================================="
echo ""
echo "📌 Next steps:"
echo "1. Wait 2-3 minutes for indexes to build"
echo "2. Check index status in Firebase Console:"
echo "   https://console.firebase.google.com/project/attendiify/firestore/indexes"
echo "3. Restart your app"
echo ""
echo "🎉 All done! Your Attendify app should now work without index errors."
echo ""

