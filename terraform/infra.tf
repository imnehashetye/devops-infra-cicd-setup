data "http" "ip" {
  url = "http://ipv4.icanhazip.com"
}

output "ip" {
  value = data.http.ip.body
}

module "Bastion_host_SG" {
  source = "terraform-aws-modules/security-group/aws//modules/http-80"

  name        = "Bastion_host_SG-server"
  description = "Security group for Bastion_host_SG-server with HTTP ports open within VPC"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = [module.vpc.vpc_cidr_block]
  ingress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "ssh ports"
      cidr_blocks = "${chomp(data.http.ip.body)}/32"
    }
  ]
}

module "Private_host_SG" {
  source = "terraform-aws-modules/security-group/aws//modules/http-80"

  name        = "Private_host_SG-server"
  description = "Security group for Bastion_host_SG-server with HTTP ports open within VPC"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = [module.vpc.vpc_cidr_block]
  ingress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 65535
      protocol    = "tcp"
      description = "service ports"
      cidr_blocks = module.vpc.vpc_cidr_block
    }
  ]
}

module "Public_host_SG" {
  source = "terraform-aws-modules/security-group/aws//modules/http-80"

  name        = "Public_host_SG-server"
  description = "Security group for Public_host_SG-server with HTTP ports open within VPC"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = [module.vpc.vpc_cidr_block]
  ingress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "http ports"
      cidr_blocks = "${chomp(data.http.ip.body)}/32"
    }
  ]

}

# resource "tls_private_key" "key" {
#   algorithm = "RSA"
# }

# resource "local_file" "private_key" {
#   filename          = "ssh-key.pem"
#   sensitive_content = tls_private_key.key.private_key_pem
#   file_permission   = "0400"
# }

# resource "aws_key_pair" "key_pair" {
#   key_name   = "ssh-key"
#   public_key = tls_private_key.key.public_key_openssh
# }

# resource "tls_private_key" "this" {
#   algorithm = "RSA"
# }

# module "key_pair" {
#   source = "terraform-aws-modules/key-pair/aws"

#   key_name   = "deployer-one"
#   public_key = tls_private_key.this.public_key_openssh
# }

resource "aws_key_pair" "project2" {
  key_name   = "project2-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDJrkgzEelKzi8S+aPL0SYCDmQE40MNxn49kS2s32NU2ethekNBJWYhrx2kgsqsrg/tLO88+FOTbsuDfIxRs/c0qTH5hLxb+Sy0zM+Z6yK/th0uD35iwDiAuxNFgOz4iGIOjpZrnIKsQn3KYpQnXtPueLjxvaxZXIVBDJp+MyvSwCfVJPYlrsyQUw5XhZnzmfK9rfk7UdgTjgPPwk8RkRIidrYP8LC58pF9E5IeSnvGNbLHz0QsurYtKa3aIYeVn4mZ0v4ZBI1rOKbw/BXcOZShoWhYysRmuqocmj4fqHh5OS9ErB324AEa7K7orhBmoFbptfflduBVqIbkKGcw0MA4Qk2/81V4V07WYL5qrFRhqAXe74oGNTGEkc0L46evMI/Hv7absesoDtBipKihjsUeN40PkS16oa8ho8pw/Brw++BfvaSVucX29K0F/a5d8QN9AVkvd3x1wHGiX1r2CKOg5wgPL03DbuSpakILdqgkTOZmePA2t6j5mHx7ZA890CE= ubuntu@ip-172-31-86-4"
}

module "ec2_instance_bastion" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  name = "bastion-instance"

  ami                    = "ami-052efd3df9dad4825"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.project2.key_name
  monitoring             = true
  vpc_security_group_ids = [module.Bastion_host_SG.security_group_id]
  subnet_id              = module.vpc.public_subnets[0]
  associate_public_ip_address = "true"

  tags = {
    Terraform   = "true"
    Environment = "dev"
    Company = "Neha"
  }

  # Copies the ssh key file to home dir
#   provisioner "file" {
#     source      = "./${aws_key_pair.key_pair.key_name}.pem"
#     destination = "/home/ec2-user/${aws_key_pair.key_pair.key_name}.pem"

#     connection {
#       type        = "ssh"
#       user        = "ec2-user"
#       private_key = file("${aws_key_pair.key_pair.key_name}.pem")
#       host        = self.public_ip
#     }
#   }
  
  //chmod key 400 on EC2 instance
#   provisioner "remote-exec" {
#     inline = ["chmod 400 ~/${aws_key_pair.key_pair.key_name}.pem"]

#     connection {
#       type        = "ssh"
#       user        = "ec2-user"
#       private_key = file("${aws_key_pair.key_pair.key_name}.pem")
#       host        = self.public_ip
#     }

#   }

}

module "ec2_instance_jenkins" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  name = "Jenkins-instance"

  ami                    = "ami-052efd3df9dad4825"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.project2.key_name
  monitoring             = true
  vpc_security_group_ids = [module.Private_host_SG.security_group_id]
  subnet_id              = module.vpc.private_subnets[0]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

module "ec2_instance_app" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  name = "Application-instance"

  ami                    = "ami-052efd3df9dad4825"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.project2.key_name
  monitoring             = true
  vpc_security_group_ids = [module.Private_host_SG.security_group_id]
  subnet_id              = module.vpc.private_subnets[0]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}