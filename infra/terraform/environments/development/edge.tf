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
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Forbidden"
      status_code  = "403"
    }
  }
}

resource "aws_lb_listener_rule" "http_cloudfront" {
  count = local.enable_service_stack && !var.enable_https ? 1 : 0

  listener_arn = aws_lb_listener.http_forward[0].arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service[0].arn
  }

  condition {
    http_header {
      http_header_name = "X-Idea2Strategy-Origin-Verify"
      values           = [random_password.cloudfront_origin_header[0].result]
    }
  }
}

resource "aws_lb_listener" "http_redirect" {
  count = local.enable_service_stack && var.enable_https ? 1 : 0

  load_balancer_arn = aws_lb.this[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Forbidden"
      status_code  = "403"
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

resource "aws_lb_listener" "https" {
  count = local.enable_service_stack && var.enable_https ? 1 : 0

  load_balancer_arn = aws_lb.this[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.cloudfront_origin[0].certificate_arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Forbidden"
      status_code  = "403"
    }
  }
}

resource "aws_lb_listener_rule" "https_cloudfront" {
  count = local.enable_service_stack && var.enable_https ? 1 : 0

  listener_arn = aws_lb_listener.https[0].arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service[0].arn
  }

  condition {
    http_header {
      http_header_name = "X-Idea2Strategy-Origin-Verify"
      values           = [random_password.cloudfront_origin_header[0].result]
    }
  }
}

resource "aws_route53_record" "service" {
  count = local.enable_service_stack && var.enable_https ? 1 : 0

  zone_id = local.hosted_zone_id
  name    = var.frontend_domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.frontend[0].domain_name
    zone_id                = aws_cloudfront_distribution.frontend[0].hosted_zone_id
    evaluate_target_health = false
  }
}
