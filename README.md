This project aims to try Amazon event bridge and Bedrock to create a customer feedback analysis solution.

![Untitled-2024-01-25-1629](https://github.com/user-attachments/assets/ea063b83-db3a-477a-b31f-86a0442f4bda)

# Sample test payloads

```
aws events put-events --region eu-west-3 --entries '[{
  "Source": "custom.feedback",
  "DetailType": "Customer Feedback",
  "Detail": "{\"text\":\"This is the worst experience I have ever had with a product. It broke within a day, and customer support was completely unhelpful. The product is horrible !\"}"
}]'
```

```
aws events put-events --region eu-west-3 --entries '[{
  "Source": "custom.feedback",
  "DetailType": "Customer Feedback",
  "Detail": "{\"text\":\"This product exceeded my expectations! The quality and service were outstanding, and I will definitely recommend it to others.\"}"
}]'
```
