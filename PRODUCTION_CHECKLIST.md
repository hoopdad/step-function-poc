# Production Deployment Checklist

Use this checklist when deploying the Step Functions workflow to production.

## 🔍 Pre-Deployment

### Infrastructure Review
- [ ] Review and update `variables.tf` for production values
- [ ] Set `environment = "prod"` in variables
- [ ] Configure appropriate AWS region
- [ ] Review IAM role permissions (principle of least privilege)
- [ ] Enable S3 bucket versioning (already enabled)
- [ ] Configure S3 lifecycle policies for log rotation
- [ ] Set up CloudWatch log retention policies

### Security Hardening
- [ ] Enable VPC for Lambda functions
- [ ] Configure private subnets for Lambda
- [ ] Set up NAT Gateway for external API access
- [ ] Enable AWS CloudTrail for audit logging
- [ ] Configure AWS Config for compliance
- [ ] Add API Gateway authentication (API keys, IAM, or Cognito)
- [ ] Rotate Secrets Manager secrets
- [ ] Enable AWS WAF for API Gateway
- [ ] Review and tighten security group rules
- [ ] Enable GuardDuty for threat detection

### Monitoring & Alerting
- [ ] Create CloudWatch dashboards
- [ ] Set up SNS topics for alerts
- [ ] Configure alarms for:
  - [ ] Step Functions execution failures
  - [ ] Lambda function errors
  - [ ] API Gateway 5xx errors
  - [ ] DynamoDB throttling
  - [ ] High execution duration
- [ ] Set up AWS X-Ray for tracing
- [ ] Configure CloudWatch Insights queries
- [ ] Set up PagerDuty/Opsgenie integration

### Backup & Recovery
- [ ] Enable automated S3 backups
- [ ] Configure DynamoDB point-in-time recovery
- [ ] Document recovery procedures
- [ ] Test disaster recovery plan
- [ ] Set up cross-region replication (if needed)

## 🏗️ Deployment

### Terraform
- [ ] Run `terraform plan` and review changes
- [ ] Use Terraform workspaces for environments
- [ ] Store Terraform state in S3 backend
- [ ] Enable state locking with DynamoDB
- [ ] Tag all resources appropriately
- [ ] Document infrastructure dependencies

### Lambda Functions
- [ ] Replace mock APIs with production APIs
- [ ] Configure production API endpoints
- [ ] Update authentication tokens in Secrets Manager
- [ ] Test Lambda functions individually
- [ ] Set appropriate timeout values
- [ ] Configure reserved concurrency
- [ ] Enable Lambda Insights

### Step Functions
- [ ] Update state machine for production APIs
- [ ] Review retry and error handling logic
- [ ] Configure appropriate timeouts
- [ ] Enable Express Workflows if needed for high volume
- [ ] Set up CloudWatch Events for scheduled execution

### API Gateway
- [ ] Configure custom domain name
- [ ] Set up SSL/TLS certificate
- [ ] Enable access logging
- [ ] Configure throttling limits
- [ ] Set up API keys for Jira
- [ ] Enable CORS appropriately
- [ ] Configure request/response validation

## 🧪 Testing

### Pre-Production Testing
- [ ] Deploy to staging environment first
- [ ] Run smoke tests
- [ ] Execute end-to-end integration tests
- [ ] Load test the workflow
- [ ] Test failure scenarios
- [ ] Verify callback mechanism
- [ ] Test Jira integration
- [ ] Validate monitoring and alerts

### Performance Testing
- [ ] Measure baseline performance
- [ ] Load test with expected volume
- [ ] Stress test with 2x expected load
- [ ] Test concurrent executions
- [ ] Verify auto-scaling behavior
- [ ] Check for memory leaks
- [ ] Profile Lambda cold starts

## 📊 Monitoring Post-Deployment

### Immediate Monitoring (First 24 Hours)
- [ ] Monitor CloudWatch dashboards
- [ ] Check error rates
- [ ] Verify execution success rates
- [ ] Monitor API Gateway metrics
- [ ] Check Lambda duration and errors
- [ ] Verify DynamoDB read/write capacity
- [ ] Monitor S3 storage growth

### Ongoing Monitoring
- [ ] Review weekly execution metrics
- [ ] Check cost trends
- [ ] Analyze performance patterns
- [ ] Review error logs
- [ ] Update runbooks based on issues
- [ ] Optimize based on usage patterns

## 📝 Documentation

### Production Documentation
- [ ] Update README with production specifics
- [ ] Document production architecture
- [ ] Create runbooks for common scenarios
- [ ] Document escalation procedures
- [ ] Create troubleshooting guide
- [ ] Document API contracts
- [ ] Update Jira integration guide
- [ ] Create onboarding guide for team

### Operational Procedures
- [ ] Deployment procedure
- [ ] Rollback procedure
- [ ] Incident response plan
- [ ] Change management process
- [ ] Capacity planning guidelines
- [ ] Cost optimization strategies

## 🔐 Compliance & Governance

### Compliance
- [ ] Review GDPR requirements (if applicable)
- [ ] Ensure HIPAA compliance (if applicable)
- [ ] Configure data retention policies
- [ ] Enable audit logging
- [ ] Document data flows
- [ ] Review security policies

### Cost Management
- [ ] Set up AWS Budgets
- [ ] Configure cost alerts
- [ ] Enable Cost Explorer
- [ ] Tag resources for cost allocation
- [ ] Review and optimize Reserved Instances
- [ ] Set up cost anomaly detection

## 🚀 Go-Live

### Final Checks
- [ ] All checklist items above completed
- [ ] Staging tests passed
- [ ] Team trained and ready
- [ ] Monitoring configured
- [ ] Runbooks prepared
- [ ] Stakeholders notified
- [ ] Rollback plan ready

### Communication
- [ ] Notify stakeholders of deployment
- [ ] Update status page
- [ ] Document deployment time
- [ ] Prepare status updates
- [ ] Set up communication channels

## 📞 Post-Deployment

### Week 1
- [ ] Daily monitoring reviews
- [ ] Address any immediate issues
- [ ] Collect feedback from users
- [ ] Update documentation
- [ ] Optimize based on real usage

### Month 1
- [ ] Review all metrics and KPIs
- [ ] Conduct retrospective
- [ ] Implement improvements
- [ ] Update capacity planning
- [ ] Review and optimize costs

## 🆘 Rollback Plan

If deployment fails:
1. [ ] Stop new executions
2. [ ] Let in-flight executions complete
3. [ ] Run: `terraform apply` with previous state
4. [ ] Verify rollback successful
5. [ ] Document reason for rollback
6. [ ] Plan remediation

## 📋 Production Configuration Checklist

### variables.tf Updates
```hcl
variable "environment" {
  default = "prod"
}

variable "state_machine_timeout_seconds" {
  default = 7200  # 2 hours for production
}

# Add production-specific variables:
# - enable_vpc = true
# - enable_xray = true
# - lambda_reserved_concurrency = 10
# - dynamodb_billing_mode = "PROVISIONED"
```

### Secrets Manager
- [ ] Generate strong, unique production API tokens
- [ ] Enable automatic rotation
- [ ] Configure KMS encryption
- [ ] Restrict access to production keys

### S3 Bucket
- [ ] Enable bucket logging
- [ ] Configure lifecycle policies
- [ ] Enable object lock (if needed)
- [ ] Set up replication (if needed)

## ✅ Sign-Off

### Approvals Required
- [ ] Technical Lead
- [ ] Security Team
- [ ] Operations Team
- [ ] Product Owner
- [ ] Compliance Officer (if needed)

### Deployment Authorization
- Deployment Date: _______________
- Deployed By: _______________
- Approved By: _______________
- Deployment Notes: _______________

---

**Remember**: Production deployments should always happen during maintenance windows with proper change management approval!
