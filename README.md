# Lost & Found — Microservices on AWS

Production-grade Lost & Found web application built as microservices on AWS for the Cloudelligent Cloud Internship. All infrastructure is Terraform, all services are Dockerized, deployed to ECS EC2 (no Fargate, no Lambda).


---

## Architecture Overview

```
Internet
    │
    ▼
[WAF] → [Public ALB] → ECS EC2 Cluster (us-east-1)
                            │
              ┌─────────────┼─────────────┐
              │             │             │
         auth-service   item-service  search-service
         (Node.js)      (Node.js)     (Node.js)
              │             │
              │         SQS: item-created-dev
              │             │
              │        matching-service (Python)
              │             │
              │         SQS: match-found-dev ← SNS: match-notifications-dev
              │             │
              │        notification-service (Python)
              │             │
              │           SES (email)
              │
         image-service   admin-service
         (Node.js)       (Node.js)
              │
             S3 (us-east-1) ──CRR──► S3 (us-west-2)

[Internal ALB] ← service-to-service communication (private subnets only)

Data:
  RDS PostgreSQL (Multi-AZ, us-east-1) ──replica──► RDS (us-west-2)
  ElastiCache Redis (Multi-AZ)
  DynamoDB (Terraform state locking)

DR Region (us-west-2):
  VPC + ECS cluster + ALB + WAF + RDS read replica (warm standby)
```

---

## Services

| Service | Port | Tech | Responsibility |
|---|---|---|---|
| auth-service | 3001 | Node.js, JWT, bcrypt | Register, login, JWT tokens |
| item-service | 3002 | Node.js, pg | CRUD for lost/found items, SQS publish |
| search-service | 3003 | Node.js, pg | Full-text search with PostgreSQL |
| matching-service | 3004 | Python, FastAPI | SQS consumer, match scoring, publish |
| notification-service | 3005 | Python, FastAPI | SQS consumer, SES email |
| image-service | 3006 | Node.js | S3 pre-signed upload URLs |
| admin-service | 3007 | Node.js | Analytics, user/item management |

---

## API Reference

All endpoints go through the public ALB. Auth endpoints require a JWT `Authorization: Bearer <token>` header unless noted.

### Auth

```
POST /auth/register
Body: { "email": "user@example.com", "password": "min12chars", "name": "Name" }
Response: { "user": { "id", "email", "name", "role" } }

POST /auth/login
Body: { "email": "user@example.com", "password": "..." }
Response: { "accessToken": "...", "refreshToken": "..." }
```

### Items

```
POST /items                          (auth required)
Body: { "type": "lost|found", "title", "description", "category", "location", "date": "YYYY-MM-DD", "image_key"? }
Response: item object

GET /items?type=lost&category=bags&location=downtown&page=1&limit=20
Response: [item, ...]

GET /items/:id
Response: item object
```

### Claims

```
POST /items/:id/claims               (auth required, cannot claim own item)
Body: { "message": "I think this is mine because..." }
Response: claim object

GET /items/:id/claims                (item owner only)
Response: [claim, ...]

PUT /items/:id/claims/:claimId/approve   (item owner only)
Response: updated claim
```

### Search

```
GET /search?q=blue+backpack&category=bags&location=downtown
Response: [item, ...]
```

### Images

```
POST /images/upload-url              (auth required)
Body: { "filename": "photo.jpg", "contentType": "image/jpeg" }
Response: { "uploadUrl": "https://s3.amazonaws.com/...", "key": "..." }
```

### Admin

```
GET /admin/analytics                 (admin role required)
GET /admin/users
GET /admin/items
```

---

## Async Pipeline

When a user posts a lost or found item, the following happens automatically:

```
POST /items
    │
    ▼
item-service publishes to SQS (lostfound-item-created-dev)
    │
    ▼
matching-service consumes message
    ├── queries RDS for items of opposite type, same category, within 30 days
    ├── scores each candidate: category (40%) + location overlap (35%) + date proximity (25%)
    └── if score >= 0.5: publishes to SQS (lostfound-match-found-dev)
                                │
                                ▼
                    SNS (lostfound-match-notifications-dev) fans out
                                │
                                ▼
                    notification-service consumes message
                        ├── looks up user emails via internal ALB → auth-service
                        └── sends HTML email via SES to both item owners
```

---

## Infrastructure

### Terraform Structure

```
infrastructure/terraform/
├── environments/
│   ├── dev/          ← Primary region us-east-1
│   └── dr/           ← DR region us-west-2
└── modules/
    ├── vpc           VPC, subnets, NAT gateways, route tables
    ├── iam           ECS node role, task role, task execution role
    ├── ecs           Cluster, launch template, ASG, capacity provider
    ├── ecs-services  Task definitions and ECS services for all 7 apps
    ├── rds           PostgreSQL Multi-AZ, parameter group, subnet group
    ├── elasticache   Redis replication group, subnet group
    ├── alb           Public ALB, WAF, listener rules
    ├── internal-alb  Internal ALB for service-to-service (private subnets)
    ├── s3            Images bucket, versioning, encryption, CRR
    ├── sqs           Queues, DLQ, redrive policy
    ├── sns           Topics, SQS subscription, queue policy
    └── codedeploy    Blue/green deployment for auth-service
```

### Remote State

- **S3 bucket:** `lostfoundstate` (us-east-1, encrypted)
- **DynamoDB table:** `lostfound-terraform-locks`

### Secrets

All secrets are in AWS Secrets Manager — never in code or Terraform state:
- `lostfound/db-password`
- `lostfound/jwt-access-secret`
- `lostfound/jwt-refresh-secret`

---

## Deployment

### Prerequisites

- AWS CLI configured with account `395063533284`
- Terraform >= 1.10
- Docker

### First-time setup

```bash
# Initialize Terraform state backend (already done)
cd Docker/lost-found/infrastructure/terraform/environments/dev
terraform init

# Plan and apply
export TF_VAR_db_password="<password>"
terraform plan
terraform apply
```

### Deploy a service manually

```bash
# Build and push image
docker build -t 395063533284.dkr.ecr.us-east-1.amazonaws.com/lostfound/matching-service:latest \
  Docker/lost-found/services/matching-service
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin \
  395063533284.dkr.ecr.us-east-1.amazonaws.com
docker push 395063533284.dkr.ecr.us-east-1.amazonaws.com/lostfound/matching-service:latest

# Force ECS to pull new image
aws ecs update-service --cluster lostfound-cluster-dev \
  --service lostfound-matching-service-dev \
  --force-new-deployment --region us-east-1
```

### CI/CD (GitHub Actions)

Every push to `main` triggers:

1. **Build** — Docker build for all 7 services in parallel
2. **Push** — Images pushed to ECR with commit SHA tag + `latest`
3. **Security scan** — Trivy scans auth-service image for HIGH/CRITICAL CVEs
4. **Terraform plan** — Shows infrastructure diff (no auto-apply)
5. **Deploy** — `force-new-deployment` for 6 services; auth-service via CodeDeploy blue/green

Secrets required in GitHub: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_ACCOUNT_ID`, `DB_PASSWORD`

---

## Database Schema

```sql
-- Users
CREATE TABLE users (
  id               SERIAL PRIMARY KEY,
  email            VARCHAR(255) UNIQUE NOT NULL,
  password_hash    VARCHAR(255) NOT NULL,
  name             VARCHAR(255) NOT NULL,
  role             VARCHAR(50) DEFAULT 'user',
  status           VARCHAR(50) DEFAULT 'active',
  refresh_token_hash VARCHAR(255),
  last_login       TIMESTAMP,
  created_at       TIMESTAMP DEFAULT NOW(),
  updated_at       TIMESTAMP DEFAULT NOW()
);

-- Items
CREATE TABLE items (
  id          SERIAL PRIMARY KEY,
  type        VARCHAR(10) NOT NULL,        -- 'lost' or 'found'
  title       VARCHAR(255) NOT NULL,
  description TEXT,
  category    VARCHAR(100),
  location    VARCHAR(255),
  date        DATE,
  image_key   VARCHAR(500),
  status      VARCHAR(50) DEFAULT 'open',  -- open, claimed, resolved
  user_id     INTEGER REFERENCES users(id),
  created_at  TIMESTAMP DEFAULT NOW(),
  updated_at  TIMESTAMP DEFAULT NOW()
);

-- Claims
CREATE TABLE claims (
  id           SERIAL PRIMARY KEY,
  item_id      INTEGER REFERENCES items(id),
  claimant_id  INTEGER REFERENCES users(id),
  message      TEXT,
  status       VARCHAR(50) DEFAULT 'pending',  -- pending, approved, rejected
  created_at   TIMESTAMP DEFAULT NOW(),
  updated_at   TIMESTAMP DEFAULT NOW()
);
```

---

## Security

| Control | Implementation |
|---|---|
| Authentication | JWT access tokens (15 min) + refresh tokens (7 days) |
| Password storage | bcrypt with salt rounds |
| Rate limiting | express-rate-limit on auth endpoints |
| HTTP headers | Helmet.js on all Node.js services |
| Input validation | Joi schemas on all request bodies |
| WAF | AWS WAF on public ALB — managed rules + rate limiting |
| Secrets | AWS Secrets Manager — never in code or env files |
| TLS | RDS SSL required (`sslmode=require`) |
| Container security | Non-root users in all Dockerfiles |
| IAM | Least-privilege task roles — SQS/SNS/SES only, scoped to project queues |

---

## Disaster Recovery

**Strategy:** Warm Standby (RPO < 5 min, RTO < 30 min)

### What's deployed in us-west-2

- VPC with 3 AZs, public/private subnets, NAT gateways
- ECS cluster (warm, scaled down)
- ALB + WAF
- RDS read replica (`lostfound-postgres-dr`) — continuously replicating from us-east-1
- S3 bucket receiving Cross-Region Replication from us-east-1

### Failover procedure

1. **Detect failure** — CloudWatch alarms on ALB 5xx rate or ECS task count
2. **Promote RDS replica** (us-west-2):
   ```bash
   aws rds promote-read-replica \
     --db-instance-identifier lostfound-postgres-dr \
     --region us-west-2
   ```
3. **Scale up ECS** in us-west-2:
   ```bash
   aws ecs update-service --cluster lostfound-cluster-dr \
     --service lostfound-auth-service-dr \
     --desired-count 2 --region us-west-2
   # Repeat for all 7 services
   ```
4. **Update DNS** — Point your domain's A record to the DR ALB:
   `cloudelligent-lost-found-alb-dr-650802853.us-west-2.elb.amazonaws.com`

### Route 53 Automated Failover (pending domain registration)

Once a domain is registered, add a Terraform `route53` module:

```hcl
# Health check on primary ALB
resource "aws_route53_health_check" "primary" {
  fqdn              = "lostfound-alb-dev-1030859096.us-east-1.elb.amazonaws.com"
  port              = 80
  type              = "HTTP"
  resource_path     = "/auth/health"
  failure_threshold = 3
  request_interval  = 30
}

# Primary record (us-east-1) — FAILOVER PRIMARY
resource "aws_route53_record" "primary" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.yourdomain.com"
  type    = "A"
  set_identifier  = "primary"
  health_check_id = aws_route53_health_check.primary.id
  failover_routing_policy { type = "PRIMARY" }
  alias {
    name                   = "lostfound-alb-dev-1030859096.us-east-1.elb.amazonaws.com"
    zone_id                = "Z35SXDOTRQ7X7K"
    evaluate_target_health = true
  }
}

# Secondary record (us-west-2) — FAILOVER SECONDARY
resource "aws_route53_record" "secondary" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.yourdomain.com"
  type    = "A"
  set_identifier = "secondary"
  failover_routing_policy { type = "SECONDARY" }
  alias {
    name                   = "cloudelligent-lost-found-alb-dr-650802853.us-west-2.elb.amazonaws.com"
    zone_id                = "Z1H1FL5HABSF5"
    evaluate_target_health = true
  }
}
```

When the primary health check fails 3 consecutive times, Route 53 automatically routes all traffic to the DR ALB in us-west-2.

---

## Local Development

```bash
cd Docker/lost-found
docker-compose up
```

Services available at:
- Auth: http://localhost:3001
- Items: http://localhost:3002
- Search: http://localhost:3003
- Matching: http://localhost:3004
- Notification: http://localhost:3005
- Images: http://localhost:3006
- Admin: http://localhost:3007

Set environment variables in a `.env` file (see `.env.example`).

---

## AWS Resources Summary

| Resource | Name | Region |
|---|---|---|
| ECS Cluster | lostfound-cluster-dev | us-east-1 |
| RDS PostgreSQL | lostfound-postgres-dev | us-east-1 |
| RDS Read Replica | lostfound-postgres-dr | us-west-2 |
| ElastiCache Redis | lostfound-redis-dev | us-east-1 |
| Public ALB | lostfound-alb-dev | us-east-1 |
| Internal ALB | lostfound-internal-alb-dev | us-east-1 |
| DR ALB | cloudelligent-lost-found-alb-dr | us-west-2 |
| S3 Images | lostfound-images-dev-us-east-1 | us-east-1 |
| S3 DR Replica | lostfound-images-dev-us-west-2 | us-west-2 |
| SQS item-created | lostfound-item-created-dev | us-east-1 |
| SQS match-found | lostfound-match-found-dev | us-east-1 |
| SNS match-notifications | lostfound-match-notifications-dev | us-east-1 |
| SNS system-alerts | lostfound-system-alerts-dev | us-east-1 |
| ECR | lostfound/* (7 repos) | us-east-1 |
| Terraform State | lostfoundstate (S3) | us-east-1 |
| State Lock | lostfound-terraform-locks (DynamoDB) | us-east-1 |
