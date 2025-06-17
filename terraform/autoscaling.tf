# 1) Fetch the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2_asg" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# 2) Launch Template for the Web Tier
resource "aws_launch_template" "web_lt" {
  name_prefix   = "ult-web-lt-"
  image_id      = data.aws_ami.amazon_linux_2_asg.id
  instance_type = "t2.micro"



  # Place new instances in your public subnets and give them a public IP
  network_interfaces {
    associate_public_ip_address = true
    subnet_id                   = aws_subnet.public_a.id
    security_groups             = [aws_security_group.web.id]
  }

  # Bootstrap everything on first boot

  user_data = base64encode(<<-EOF
#!/bin/bash
yum update -y
amazon-linux-extras enable python3.8 nginx1
yum install -y python3 nginx git
pip3 install flask pymysql

# Dynamically pick the right RDS endpoint & DB name based on AZ
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
if [[ "$AZ" == *"a" ]]; then
  ENDPOINT=${aws_db_instance.ult_rds_a.address}
  DBNAME="ultdba"
else
  ENDPOINT=${aws_db_instance.ult_rds_b.address}
  DBNAME="ultdbb"
fi

# Export for ec2-user shells
echo "export DB_HOST=$ENDPOINT"               >> /home/ec2-user/.bash_profile
echo "export DB_NAME=$DBNAME"                 >> /home/ec2-user/.bash_profile
echo "export DB_USER=${var.db_username}"      >> /home/ec2-user/.bash_profile
echo "export DB_PASS=${var.db_password}"      >> /home/ec2-user/.bash_profile
source /home/ec2-user/.bash_profile

# Create & deploy the Flask app
mkdir -p /home/ec2-user/flask_app
cat << 'APP' > /home/ec2-user/flask_app/app.py
from flask import Flask
import pymysql, os

app = Flask(__name__)

def get_db_connection():
    return pymysql.connect(
        host=os.getenv('DB_HOST'),
        user=os.getenv('DB_USER'),
        password=os.getenv('DB_PASS'),
        db=os.getenv('DB_NAME'),
        cursorclass=pymysql.cursors.DictCursor
    )

@app.route("/")
def index():
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS test (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    text VARCHAR(255)
                );
            """)
            cursor.execute("INSERT INTO test (text) VALUES ('Hello from Flask to RDS via ASG');")
            conn.commit()
            cursor.execute("SELECT text FROM test ORDER BY id DESC LIMIT 1;")
            return cursor.fetchone()["text"]
    finally:
        conn.close()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
APP

chown -R ec2-user:ec2-user /home/ec2-user/flask_app

# Start Flask in the background
su - ec2-user -c "nohup python3 /home/ec2-user/flask_app/app.py > /home/ec2-user/flask_app/flask.log 2>&1 &"

# Configure Nginx as a reverse proxy
cat << 'NGINX' > /etc/nginx/conf.d/flask_app.conf
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass         http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade $http_upgrade;
        proxy_set_header   Connection 'upgrade';
        proxy_set_header   Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
NGINX

systemctl enable nginx
nginx -t && systemctl restart nginx
EOF
  )


}

# 3) Auto Scaling Group
resource "aws_autoscaling_group" "web_asg" {
  name = "ult-web-asg"
  launch_template {
    id      = aws_launch_template.web_lt.id
    version = "$Latest"
  }

  min_size         = 2
  desired_capacity = 2
  max_size         = 2

  # Spread across both public subnets
  vpc_zone_identifier = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id,
  ]

  # Use ALB health checks
  health_check_type         = "ELB"
  health_check_grace_period = 120

  # Automatically register with your ALB’s target group
  target_group_arns = [aws_lb_target_group.web_tg.arn]

  # Name tag for new instances
  tag {
    key                 = "Name"
    value               = "ult-web-asg-instance"
    propagate_at_launch = true
  }

  depends_on = [aws_lb_listener.http]

  lifecycle {
    create_before_destroy = true
  }
}
