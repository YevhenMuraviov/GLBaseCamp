output "bastion_public_ip" {
  value = aws_eip.eip_ip_bastion.public_ip
}

output "bastion_private_ip" {
  value = aws_instance.bastion_srv.private_ip
}

output "worker_private_ip" {
  value = aws_instance.worker_srv.private_ip
}

output "private_key_pem" {
  value = tls_private_key.keygen.private_key_pem
}