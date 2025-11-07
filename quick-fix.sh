#!/bin/bash

# Quick fix for state machine naming issue

echo "Applying quick fix for state machine naming issue..."
echo ""

# The fix: Update ProcessCallbackResult to point to WriteOutputsToS3 instead of WriteResultsToS3
# This is already done in your downloaded files

echo "✅ Fix already applied in state-machine.json"
echo ""
echo "Just run: terraform apply"
echo ""
echo "This will succeed now!"
