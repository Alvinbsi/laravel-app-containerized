
## Project Structure

laravel-app-containerized/
│
├── .github/                        # GitHub Actions workflows directory
│   └── workflows/
│       └── ci-cd-pipeline.yml       # GitHub CI/CD pipeline configuration
│
├── .gitignore                       # Git ignore file
├── docker/                          # Docker related files and configuration
│   ├── docker-compose.dev.yml       # Docker Compose configuration for development environment
│   ├── docker-compose.prod.yml      # Docker Compose configuration for production environment
│   ├── Dockerfile                   # General Dockerfile for building the application
│   ├── Dockerfile.dev               # Dockerfile for development environment
│   ├── Dockerfile.prod              # Dockerfile for production environment
│   └── nginx/                       # Nginx configuration (if used)
│
├── helm/                            # Helm charts for Kubernetes deployments
│   └── laravel-app/                 # Helm chart for Laravel app
│       ├── Chart.yaml               # Helm chart metadata
│       ├── templates/               # Templates for Kubernetes resources
│       │   └── deployment.yaml      # Deployment configuration for Helm chart
│       └── values.yaml              # Helm values configuration
│
├── kubernetes/                      # Kubernetes-related configurations
│   ├── ingress.yaml                 # Ingress resource configuration
│   ├── namespace.yaml               # Kubernetes namespace configuration
│   └── service.yaml                 # Kubernetes service configuration
│
├── terraform/                       # Terraform configurations (for infrastructure provisioning)
│   ├── main.tf                      # Main Terraform configuration
│   ├── outputs.tf                   # Terraform output variables
│   └── variables.tf                 # Terraform input variables
│
└── Readme.md                        # Project documentation




## 1. Create a Basic AWS EKS Cluster Using Terraform

### a. Directory Setup
```bash
mkdir terraform && cd terraform
```

### b. Terraform Files
1. **`main.tf`**:

provider "aws" {
  region = "ap-south-1"
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "example-eks-cluster"
  cluster_version = "1.27"

  node_groups = {
    default = {
      desired_capacity = 2
      max_size         = 3
      min_size         = 1
      instance_type    = "t3.medium"
    }
  }
}


2. **`variables.tf`**:

variable "region" {
  default = "ap-south-1"
}


3. **`outputs.tf`**:

output "eks_cluster_name" {
  value = module.eks.cluster_id
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}


### c. Terraform Commands
```bash
terraform init
terraform plan
```


## 2. Create a Helm Chart

### a. Initialize Helm Chart
```bash
mkdir helm && cd helm
helm create laravel-app
```

### b. Edit `values.yaml`
```yaml
replicaCount: 2
image:
  repository: <ECR_REPO_URL>
  tag: "latest"
  pullPolicy: IfNotPresent

service:
  type: LoadBalancer
  port: 80
```

### c. Update `deployment.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: laravel-app
  labels:
    app: laravel-app
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: laravel-app
  template:
    metadata:
      labels:
        app: laravel-app
    spec:
      containers:
      - name: laravel-app
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        ports:
        - containerPort: 80
```

---

## 3. Docker Setup

### a. Production Dockerfile
```dockerfile
FROM php:8.2-fpm-alpine

RUN apk --update add wget \
  curl \
  git \
  grep \
  build-base \
  libmemcached-dev \
  libmcrypt-dev \
  libxml2-dev \
  imagemagick-dev \
  pcre-dev \
  libtool \
  make \
  autoconf \
  g++ \
  cyrus-sasl-dev \
  libgsasl-dev \
  supervisor

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer

RUN docker-php-ext-install mysqli pdo pdo_mysql xml
RUN pecl channel-update pecl.php.net \
    && pecl install memcached \
    && pecl install imagick \
    && docker-php-ext-enable memcached \
    && docker-php-ext-enable imagick

RUN rm /var/cache/apk/*

WORKDIR /var/www
COPY ./dev/docker-compose/php/supervisord-app.conf /etc/supervisord.conf

ENTRYPOINT ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisord.conf"]
```

### b. Development Dockerfile
```dockerfile
FROM php:8.1-cli
WORKDIR /app
COPY . .
RUN docker-php-ext-install pdo pdo_mysql
CMD ["php", "-S", "0.0.0.0:8000", "-t", "public"]
```

### c. Docker Compose
```yaml
version: '3.7'
services:
  app:
    build:
      args:
        user: webuser
        uid: 1000
      context: ./
      dockerfile: Dockerfile
    image: ap-laravel
    container_name: ap-app
    restart: unless-stopped
    logging:
      options:
        max-size: "5k"
    ports:
      - '${FORWARD_VITE_PORT:-5173}:5173'
    working_dir: /var/www/
    volumes:
      - ./:/var/www
      - ./dev/docker-compose/php/app.ini:/usr/local/etc/php/conf.d/app.ini
    extra_hosts:
      - host.docker.internal:host-gateway
    networks:
      - ap

  nginx:
    image: nginx:alpine
    container_name: ap-nginx
    restart: unless-stopped
    logging:
      options:
        max-size: "5k"
    ports:
      - '${FORWARD_NGINX_PORT:-80}:80'
    volumes:
      - ./:/var/www
      - ./dev/docker-compose/nginx:/etc/nginx/conf.d/
    networks:
      - ap

  worker-local:
    build:
      context: ./
      dockerfile: ./dev/docker-compose/worker-local/Dockerfile
      args:
        queueTimeout: 30
        queueTries: 2
        queues: default,indexing,notifications
    image: ap-worker-local
    container_name: ap-worker-local
    restart: unless-stopped
    logging:
      options:
        max-size: "5k"
    working_dir: /var/www/
    volumes:
      - ./:/var/www
      - ./dev/docker-compose/php/app.ini:/usr/local/etc/php/conf.d/app.ini
    extra_hosts:
        - host.docker.internal:host-gateway
    networks:
      - ap

  mysql:
    image: mysql
    command: mysqld --sql_mode=""
    container_name: ap-mysql
    restart: unless-stopped
    logging:
      options:
        max-size: "5k"
    ports:
      - '${FORWARD_DB_PORT:-3306}:3306'
    environment:
      MYSQL_DATABASE: ${DB_DATABASE}
      MYSQL_ROOT_PASSWORD: ${DB_PASSWORD}
      MYSQL_PASSWORD: ${DB_PASSWORD}
      MYSQL_USER: ${DB_USERNAME} cannot use this anymore
      SERVICE_TAGS: dev
      SERVICE_NAME: mysql
    volumes:
      - ./dev/docker-compose/mysql:/docker-entrypoint-initdb.d
    networks:
      - ap

  redis:
    build:
      context: ./
      dockerfile: ./dev/docker-compose/redis/Dockerfile
    privileged: true
    command: sh -c "/redis/init.sh"
    volumes:
      - ./dev/docker-compose/redis/redis.conf:/usr/local/etc/redis/redis.conf
    restart: unless-stopped
    container_name: ap-redis
    ports:
      - '${FORWARD_REDIS_PORT:-6379}:6379'
    networks:
      - ap
    logging:
      options:
        max-size: "5k"
    healthcheck:
      test: [ "CMD", "redis-cli", "ping" ]

networks:
  ap:
    driver: bridge
```

---

## 4. Implement CI/CD Pipeline

### a. GitLab CI/CD Pipeline
#### **`.gitlab-ci.yml`**:
```yaml
stages:
  - test
  - build
  - deploy

test:
  script:
    - php artisan test

build:
  script:
    - docker build -t <ECR_REPO_URL>:latest .
    - aws ecr get-login-password | docker login --username AWS --password-stdin <ECR_REPO_URL>
    - docker push <ECR_REPO_URL>:latest

deploy:
  script:
    - helm upgrade --install laravel-app ./helm/laravel-app --namespace default
```

---

## 5. Add IAM User

### a. AWS CLI Commands
```bash
aws iam create-user --user-name eks-ecr-user
aws iam attach-user-policy --user-name eks-ecr-user --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
aws iam attach-user-policy --user-name eks-ecr-user --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess
```

---

## 6. Documentation

### a. README.md
Include:
- Terraform commands
- Helm chart usage
- Docker and Docker Compose instructions
- CI/CD pipeline steps

### b. Security Improvements
- Use multi-stage builds in Dockerfiles.
- Scan images for vulnerabilities.
- Limit container privileges.

---

This configuration meets all the specified criteria and includes optional improvements. Let me know if you need additional details or further assistance!
