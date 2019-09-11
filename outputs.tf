/*
 * Copyright (c) 2019 Netic A/S. All rights reserved.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

output "mount_target_dns_name" {
  value = element(aws_efs_mount_target.this.*.dns_name, 0)
}
