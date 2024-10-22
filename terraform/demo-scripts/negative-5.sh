aws events put-events --region eu-west-3 --entries '[{
  "Source": "custom.feedback",
  "DetailType": "Customer Feedback",
  "Detail": "{\"text\":\"This is the worst experience I have ever had with a product. It broke within a day, and customer support was completely unhelpful. The product is shit !\"}"
}]'
