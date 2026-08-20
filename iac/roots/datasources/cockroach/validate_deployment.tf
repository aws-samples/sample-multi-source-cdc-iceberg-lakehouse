# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0


# Deployment validation checks to ensure proper resource ordering
# These checks help validate that the management instance is deployed after
# all CockroachDB infrastructure is ready

# Validate that CockroachDB nodes are available before management instance
check "cockroachdb_nodes_ready" {
  assert {
    condition     = length(aws_instance.cockroachdb) == var.NODE_COUNT
    error_message = "CockroachDB nodes must be created before management instance. Expected ${var.NODE_COUNT} nodes."
  }
}

# Validate that load balancer is ready before management instance
check "cockroachdb_lb_ready" {
  assert {
    condition     = aws_lb.cockroachdb.dns_name != ""
    error_message = "CockroachDB load balancer must be ready before management instance deployment."
  }
}

# Validate that management instance has access to node IPs
check "management_instance_node_access" {
  assert {
    condition     = length(local.cockroach_node_ips) == var.NODE_COUNT
    error_message = "Management instance must have access to all CockroachDB node IP addresses for certificate generation."
  }
}

# Output deployment order information
output "deployment_order_info" {
  description = "Information about the deployment order and dependencies"
  value = {
    cockroachdb_nodes_count = length(aws_instance.cockroachdb)
    cockroachdb_node_ips    = local.cockroach_node_ips
    load_balancer_dns       = local.cockroach_lb_dns
    deployment_note         = "Management instance deployed after all CockroachDB infrastructure"
  }
}
