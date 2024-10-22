aws events put-events --region eu-west-3 --entries '[{
  "Source": "custom.feedback",
  "DetailType": "Customer Feedback",
  "Detail": "{\"text\":\"The product is okay. It does the job, but nothing about it stands out.\"}"
}]'
