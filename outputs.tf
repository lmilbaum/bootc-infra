output "public_ip" {
  value = aws_instance.this.public_ip
}

output "instance_id" {
  value = aws_instance.this.id
}

output "ssh" {
  value = "ssh -i ~/.ssh/id_rsa fedora@${aws_instance.this.public_ip}"
}