# SF Academy Exchange App

### Overview

This is a platform that enables users to exchange a currency to another, depositing money from a bank and then withdraw them at the end of the operations.

- current **client** implementation allow only currency USD and EUR.
- deposit and withdraw from the bank are simulated
- no integration with real bank api been done
- no information about bank and platform transaction (deposit and withdraw) are saved

### Get Started

1. `git clone --recursive https://github.com/ZhouJian26/sf-academy.git`
2. `cd sf-academy`
3. `docker-compose up --build`
4. open a browser and go to `localhost`
5. enjoy!

**NOTE** you **must** have docker installed

### More Information

- [web application](https://github.com/ZhouJian26/sf-academy-webapp)
- [nginx server](https://github.com/ZhouJian26/sf-academy-nginx)
- [api server](https://github.com/ZhouJian26/sf-academy-api)
- [exchange microservice](https://github.com/ZhouJian26/sf-academy-exchange-microservice)
- [user microservice](https://github.com/ZhouJian26/sf-academy-user-microservice)
- [user database](https://github.com/ZhouJian26/sf-academy-user-db)
- [cicd infrastructure](https://github.com/ZhouJian26/sf-academy/tree/master/sf-academy-infrastructure-cicd)
- [application infrastructure](https://github.com/ZhouJian26/sf-academy/tree/master/sf-academy-infrastructure-backend)

### Deploy in AWS

1. `git clone --recursive https://github.com/ZhouJian26/sf-academy.git`
2. `cd sf-academy/sf-academy-infrastructure-cicd`
3. create a variables.tfvars file with [those variables]()
4. `terraform init -var-file="variables.tfvars"`
5. `terraform apply`
6. `cd ../sf-academy-infrastructure-backend`
7. create a .tf file with [those variables]()
8. `terraform init`
9. `terraform apply`
10. enjoy!

**NOTE**

- you **must** have docker and terraform installed
- you **must** have aws account configured
- **at least one** docker image per container have to be pushed into ecr
- you may need fork all the submodules to get access to GH API

### Technology

- Docker
- Terraform
- gRPC
- OpenAPI
- NodeJS
- NextJS
- AWS
