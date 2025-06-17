data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}
#
# EC2 Instance in Public Subnet A
#
resource "aws_instance" "web_a" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true

  # Automatically provision Flask on boot
  user_data = <<-EOF
              #!/bin/bash
              # Update OS and install dependencies
              yum update -y
              amazon-linux-extras enable python3.8 nginx1
              yum install -y python3 nginx git
              pip3 install flask pymysql

              # Export RDS envvars (interpolated by Terraform)
              echo "export DB_HOST=${aws_db_instance.ult_rds_a.address}"        >> /home/ec2-user/.bash_profile
              echo "export DB_USER=${var.db_username}"                        >> /home/ec2-user/.bash_profile
              echo "export DB_PASS=${var.db_password}"                        >> /home/ec2-user/.bash_profile
              echo "export DB_NAME=\"ultdba\""                                >> /home/ec2-user/.bash_profile
              source /home/ec2-user/.bash_profile

              # Create app directory and pull code (or write inline)
              mkdir -p /home/ec2-user/flask_app
              cat << 'FLASK' > /home/ec2-user/flask_app/app.py
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
                          cursor.execute("INSERT INTO test (text) VALUES ('Hello from Flask to RDS');")
                          conn.commit()
                          cursor.execute("SELECT text FROM test ORDER BY id DESC LIMIT 1;")
                          row = cursor.fetchone()
                          return row["text"] if row else "No data found."
                  finally:
                      conn.close()
              if __name__ == "__main__":
                  app.run(host="0.0.0.0", port=5000)
              FLASK

              chown -R ec2-user:ec2-user /home/ec2-user/flask_app

              # Start Flask in the background
              su - ec2-user -c "nohup python3 /home/ec2-user/flask_app/app.py > /home/ec2-user/flask_app/flask.log 2>&1 &"

              # Install and configure Nginx to proxy port 80 → 5000
              systemctl enable nginx
              cat << 'NGINXCFG' > /etc/nginx/conf.d/flask_app.conf
              server {
                  listen       80;
                  server_name  _;
                  location / {
                      proxy_pass         http://127.0.0.1:5000;
                      proxy_http_version 1.1;
                      proxy_set_header   Upgrade $http_upgrade;
                      proxy_set_header   Connection 'upgrade';
                      proxy_set_header   Host $host;
                      proxy_cache_bypass $http_upgrade;
                  }
              }
              NGINXCFG
              nginx -t
              systemctl restart nginx
              EOF

  tags = {
    Name = "ult-web-a"
  }
}

#
# EC2 Instance in Public Subnet B
#
resource "aws_instance" "web_b" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_b.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true

  # Automatically provision Flask on boot
  user_data = <<-EOF
              #!/bin/bash
              # Update OS and install dependencies
              yum update -y
              amazon-linux-extras enable python3.8 nginx1
              yum install -y python3 nginx git
              pip3 install flask pymysql

              # Export RDS envvars (interpolated by Terraform)
              echo "export DB_HOST=${aws_db_instance.ult_rds_b.address}"        >> /home/ec2-user/.bash_profile
              echo "export DB_USER=${var.db_username}"                        >> /home/ec2-user/.bash_profile
              echo "export DB_PASS=${var.db_password}"                        >> /home/ec2-user/.bash_profile
              echo "export DB_NAME=\"ultdbb\""                                >> /home/ec2-user/.bash_profile
              source /home/ec2-user/.bash_profile

              # Create app directory and pull code (or write inline)
              mkdir -p /home/ec2-user/flask_app
              cat << 'FLASK' > /home/ec2-user/flask_app/app.py
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
                          cursor.execute("INSERT INTO test (text) VALUES ('Hello from Flask to RDS');")
                          conn.commit()
                          cursor.execute("SELECT text FROM test ORDER BY id DESC LIMIT 1;")
                          row = cursor.fetchone()
                          return row["text"] if row else "No data found."
                  finally:
                      conn.close()
              if __name__ == "__main__":
                  app.run(host="0.0.0.0", port=5000)
              FLASK

              chown -R ec2-user:ec2-user /home/ec2-user/flask_app

              # Start Flask in the background
              su - ec2-user -c "nohup python3 /home/ec2-user/flask_app/app.py > /home/ec2-user/flask_app/flask.log 2>&1 &"

              # Install and configure Nginx to proxy port 80 → 5000
              systemctl enable nginx
              cat << 'NGINXCFG' > /etc/nginx/conf.d/flask_app.conf
              server {
                  listen       80;
                  server_name  _;
                  location / {
                      proxy_pass         http://127.0.0.1:5000;
                      proxy_http_version 1.1;
                      proxy_set_header   Upgrade $http_upgrade;
                      proxy_set_header   Connection 'upgrade';
                      proxy_set_header   Host $host;
                      proxy_cache_bypass $http_upgrade;
                  }
              }
              NGINXCFG
              nginx -t
              systemctl restart nginx
              EOF

  tags = {
    Name = "ult-web-b"
  }
}

#
# EBS Volume and Attachment for web_a
#
resource "aws_ebs_volume" "vol_a" {
  availability_zone = var.public_azs[0] # same AZ as web_a
  size              = 8                 # 8 GiB volume
  tags = {
    Name = "ult-ebs-a"
  }
}

resource "aws_volume_attachment" "attach_a" {
  device_name = "/dev/xvdf" # Linux: xvdf maps to /dev/sdf
  volume_id   = aws_ebs_volume.vol_a.id
  instance_id = aws_instance.web_a.id
  # Wait until the instance is fully up before attaching
  depends_on = [aws_instance.web_a]
}


#
# EBS Volume and Attachment for web_b
#
resource "aws_ebs_volume" "vol_b" {
  availability_zone = var.public_azs[1] # same AZ as web_b
  size              = 8                 # 8 GiB volume
  tags = {
    Name = "ult-ebs-b"
  }
}

resource "aws_volume_attachment" "attach_b" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.vol_b.id
  instance_id = aws_instance.web_b.id
  depends_on  = [aws_instance.web_b]
}
