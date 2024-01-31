resource "random_id" "creation_token" {
  byte_length = 8
  prefix      = "${var.name}-"
}

resource "aws_efs_file_system" "file_system" {
  creation_token = var.creation_token
  encrypted  = var.encrypted
  kms_key_id = var.kms_key_id
  throughput_mode = var.throughput_mode
  performance_mode = var.performance_mode
  provisioned_throughput_in_mibps = var.provisioned_throughput_in_mibps
  tags = var.tags
}

resource "aws_efs_mount_target" "mount_target" {
  count = length(var.subnets)

  file_system_id  = aws_efs_file_system.file_system.id
  subnet_id       = element(var.subnets, count.index)
  security_groups = [aws_security_group.mount_target.id]
}

resource "aws_security_group" "mount_target_client" {
  name        = "${var.name}-mount-target-client"
  description = "Allow traffic out to NFS for ${var.name}-mnt."
  vpc_id      = var.vpc_id

  depends_on = [aws_efs_mount_target.mount_target]

  tags = merge(
    tomap({"Name" = "${var.name}-mount-target-client"}),
    tomap({"terraform" = "true"}),
    var.tags,
  )
}

resource "aws_security_group_rule" "nfs_egress" {
  description              = "Allow NFS traffic out from EC2 to mount target"
  type                     = "egress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.mount_target_client.id
  source_security_group_id = aws_security_group.mount_target.id
}

resource "aws_security_group" "mount_target" {
  name        = "${var.name}-mount-target"
  description = "Allow traffic from instances using ${var.name}-ec2."
  vpc_id      = var.vpc_id

  tags = merge(
    tomap({"Name" = "${var.name}-mount-target"}),
    tomap({"terraform" = "true"}),
    var.tags,
  )
}

resource "aws_security_group_rule" "nfs_ingress" {
  description              = "Allow NFS traffic into mount target from EC2"
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.mount_target.id
  source_security_group_id = aws_security_group.mount_target_client.id
}
