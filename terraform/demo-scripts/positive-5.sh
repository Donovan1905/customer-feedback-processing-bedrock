aws events put-events --region eu-west-3 --entries '[{
  "Source": "custom.feedback",
  "DetailType": "Customer Feedback",
  "Detail": "{\"text\":\"This product exceeded my expectations! The quality and service were outstanding, and I will definitely recommend it to others.\"}"
}]'
