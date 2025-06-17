#
# Application Load Balancer (public)
#
resource "aws_lb" "web_alb" {
  name               = "ult-web-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = {
    Name = "ult-web-alb"
  }
}

#
# Target group listening on port 80, protocol HTTP
#
resource "aws_lb_target_group" "web_tg" {
  name     = "ult-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.ult.id

  health_check {
    protocol            = "HTTP"
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
  }

  tags = {
    Name = "ult-web-tg"
  }
}

#
# Attach web_a to the target group
#
resource "aws_lb_target_group_attachment" "attach_a" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web_a.id
  port             = 80
}

#
# Attach web_b to the target group
#
resource "aws_lb_target_group_attachment" "attach_b" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web_b.id
  port             = 80
}

#
# ALB HTTP listener
#
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}
