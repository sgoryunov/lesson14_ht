- На локальной машине авторизуемся:
  - yc init 
  - s3cmd –configure
- В conf.tf и meta.txt меняем locals и user свои 
- terraform init
- Вводим свой token на запросы комманд:
  - terraform plan
  - terraform apply
