aws events put-events --region eu-west-3 --entries '[{
  "Source": "custom.feedback",
  "DetailType": "Customer Feedback",
  "Detail": "{\"text\":\"It works, but there is nothing too special about it. It did what I needed, but I would not say I am overly impressed.\"}"
}]'
