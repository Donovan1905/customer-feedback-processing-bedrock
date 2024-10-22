aws events put-events --region eu-west-3 --entries '[{
  "Source": "custom.feedback",
  "DetailType": "Customer Feedback",
  "Detail": "{\"text\":\"Not great, but not terrible either. It barely met my needs, but I do not think I would buy it again.\"}"
}]'
