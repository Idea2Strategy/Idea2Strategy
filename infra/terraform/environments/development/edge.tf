resource "aws_lb" "this" {
  count = local.enable_service_stack ? 1 : 0

  name                       = "${local.name_prefix}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb[0].id]
  subnets                    = values(aws_subnet.public)[*].id
  enable_deletion_protection = false
  drop_invalid_header_fields = true

  tags = {
    Name = "${local.name_prefix}-alb"
  }
}

resource "aws_lb_target_group" "service" {
  count = local.enable_service_stack ? 1 : 0

  name        = "${local.name_prefix}-service-tg"
  port        = var.service_target_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.this.id
  target_type = "instance"

  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    port                = "traffic-port"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group_attachment" "service" {
  count = local.enable_service_stack ? 1 : 0

  target_group_arn = aws_lb_target_group.service[0].arn
  target_id        = aws_instance.service[0].id
  port             = var.service_target_port
}

resource "aws_lb_listener" "http_forward" {
  count = local.enable_service_stack && !var.enable_https ? 1 : 0

  load_balancer_arn = aws_lb.this[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service[0].arn
  }
}

resource "aws_lb_listener" "http_redirect" {
  count = local.enable_service_stack && var.enable_https ? 1 : 0

  load_balancer_arn = aws_lb.this[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_route53_zone" "this" {
  count = local.enable_service_stack && var.existing_hosted_zone_id == "" ? 1 : 0

  name = var.domain_name

  tags = {
    Name = "${local.name_prefix}-public-zone"
  }
}

resource "aws_acm_certificate" "service" {
  count = local.enable_service_stack ? 1 : 0

  domain_name       = var.service_domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "certificate_validation" {
  for_each = local.enable_service_stack ? {
    for option in aws_acm_certificate.service[0].domain_validation_options :
    option.domain_name => {
      name   = option.resource_record_name
      record = option.resource_record_value
      type   = option.resource_record_type
    }
  } : {}

  allow_overwrite = true
  zone_id         = local.hosted_zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]
}

resource "aws_acm_certificate_validation" "service" {
  count = local.enable_service_stack && var.enable_https ? 1 : 0

  certificate_arn         = aws_acm_certificate.service[0].arn
  validation_record_fqdns = [for record in aws_route53_record.certificate_validation : record.fqdn]
}

resource "aws_lb_listener" "https" {
  count = local.enable_service_stack && var.enable_https ? 1 : 0

  load_balancer_arn = aws_lb.this[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.service[0].certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service[0].arn
  }
}

resource "aws_route53_record" "service" {
  count = local.enable_service_stack ? 1 : 0

  zone_id = local.hosted_zone_id
  name    = var.service_domain_name
  type    = "A"

  alias {
    name                   = aws_lb.this[0].dns_name
    zone_id                = aws_lb.this[0].zone_id
    evaluate_target_health = true
  }
}
