#!/bin/sh

# Define the Lambda function Python file and the zip file name
LAMBDA_ZIP_FILE="../lambda.zip"
LAMBDA_CODE_PATH="./lambda_function.py"

# Check if the lambda_function.py exists
if [ ! -f "$LAMBDA_CODE_PATH" ]; then
  echo "Error: Lambda function code ($LAMBDA_CODE_PATH) not found!"
  exit 1
fi

# Step 1: Remove the existing zip file if it exists
if [ -f "$LAMBDA_ZIP_FILE" ]; then
  echo "Removing existing zip file..."
  rm "$LAMBDA_ZIP_FILE"
fi

# Step 2: Zip the updated Lambda function
echo "Zipping the updated Lambda function..."
zip "$LAMBDA_ZIP_FILE" "$LAMBDA_CODE_PATH"

# Step 3: Confirm completion
echo "Lambda function has been zipped into $LAMBDA_ZIP_FILE."
