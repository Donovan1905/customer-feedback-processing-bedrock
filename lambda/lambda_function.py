import json
import boto3
import os
import uuid

# Initialize clients
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['DYNAMODB_TABLE'])
bedrock_client = boto3.client('bedrock-runtime', region_name='eu-west-3')  # Adjust region if necessary
eventbridge = boto3.client('events')  # Initialize EventBridge client
sns_client = boto3.client('sns')  # Initialize SNS client


def lambda_handler(event, context):
    print(event)
    feedback = event.get('detail', {})
    feedback_text = feedback.get('text', '')

    if feedback_text:
        sentiment, score = analyze_sentiment(feedback_text)
        feedback_id = str(uuid.uuid4())

        # Save feedback, sentiment, and score to DynamoDB
        table.put_item(
            Item={
                'FeedbackID': feedback_id,
                'FeedbackText': feedback_text,
                'Sentiment': sentiment,
                'Score': score,
                'Timestamp': event['time']
            }
        )

        # Trigger EventBridge event if the feedback is Negative and score >= 3
        if sentiment == "Negative" and int(score) >= 3:
            print("Need to send SNS")
            # Send event to EventBridge with a different source
            eventbridge.put_events(
                Entries=[
                    {
                        'Source': 'custom.feedback_processed',  # Use a different source to avoid looping
                        'DetailType': 'FeedbackEvent',
                        'Detail': json.dumps({
                            'feedback_id': feedback_id,
                            'feedback_text': feedback_text,
                            'sentiment': sentiment,
                            'score': int(score)  # Send score as a number, not a string
                        }),
                        'EventBusName': 'default'
                    }
                ]
            )

    return {
        'statusCode': 200,
        'body': json.dumps('Feedback processed successfully!')
    }



def analyze_sentiment(text):
    # Define a clear prompt asking Claude to return the sentiment and score
    prompt = f"""
    Human: Based on the following text, return only one of these three options: 'Positive', 'Negative', or 'Neutral'. If the sentiment is 'Positive' or 'Negative', also provide a sentiment score between 1 and 5, where 5 represents the strongest sentiment (e.g., 5 for extremely positive or 5 for extremely negative). Format the response as 'Sentiment: [Positive/Negative/Neutral], Score: [1-5 or N/A]'.
    Text: "{text}"
    Assistant:
    """

    # Input configuration with model-specific parameters
    model_kwargs = {
        "max_tokens": 20,  # Keep this small since we only expect a short response
        "temperature": 0,  # Set to 0 for deterministic response
        "top_k": 250,
        "top_p": 1,
        "stop_sequences": ["\n\nHuman"],  # Stop after the first response
    }

    # Body structure for the Bedrock model
    body = {
        "anthropic_version": "bedrock-2023-05-31",
        "system": "Analyze the sentiment of the customer feedback.",
        "messages": [
            {"role": "user", "content": [{"type": "text", "text": prompt}]},
        ],
    }
    body.update(model_kwargs)

    # Call Claude 3 Haiku model using Bedrock
    response = bedrock_client.invoke_model(
        modelId="anthropic.claude-3-haiku-20240307-v1:0",  # Claude 3 Haiku model ID
        body=json.dumps(body),
    )

    # Read the StreamingBody content and decode it
    response_body = response['body'].read().decode('utf-8')

    # Parse the result
    result = json.loads(response_body)

    # Print the result for debugging
    print(f"Bedrock response: {result}")

    # Safely extract the sentiment and score from Claude's response
    # Expected response format: "Sentiment: Positive, Score: 5" or "Sentiment: Neutral, Score: N/A"
    sentiment_data = result['content'][0].get('text', 'Sentiment: FailedToIdentify, Score: N/A').strip()

    # Parse the sentiment and score
    sentiment, score = parse_sentiment_and_score(sentiment_data)

    return sentiment, score


def parse_sentiment_and_score(sentiment_data):
    # Default values if parsing fails
    sentiment = "FailedToIdentify"
    score = "N/A"
    print(sentiment_data)
    # Split the response string to extract sentiment and score
    try:
        # Example format: "Sentiment: Positive, Score: 5"
        sentiment_part, score_part = sentiment_data.split(',')
        sentiment = sentiment_part.split(':')[1].strip()
        score = score_part.split(':')[1].strip()
    except Exception as e:
        print(f"Error parsing sentiment and score: {e}")

    return sentiment, score
