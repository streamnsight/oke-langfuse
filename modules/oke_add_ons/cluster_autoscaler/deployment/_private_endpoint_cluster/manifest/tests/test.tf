module "test1" {
  source = "../../manifest"
  autoscaler_pool_settings = [{
    autoscale = true
    min_nodes = 12
    max_nodes = 50
    id        = "my-node-pool1"
    },
    {
      autoscale = true
      min_nodes = 3
      max_nodes = 5
      id        = "my-node-pool2"
  }]
  compartment_id                           = "my-compartment-id"
  region                                   = "us-ashburn-1"
  image                                    = "us_ashburn-1.oric.io/oracle/oci-cluster-autoscaler:1.26-4"
  cloud_provider                           = "oci"
  cluster_autoscaler_use_workload_identity = true
}
output "test1" {
  value = module.test1.manifest_yaml == file("./fixtures/test1.yaml")
}

module "test2" {
  source = "../../manifest"
  autoscaler_pool_settings = [{
    autoscale = true
    min_nodes = 12
    # max_nodes = 50
    id = "my-node-pool"
  }]
  compartment_id                           = "my-compartment-id"
  region                                   = "us-ashburn-1"
  image                                    = "us_ashburn-1.oric.io/oracle/oci-cluster-autoscaler:1.26-4"
  cloud_provider                           = "oci"
  cluster_autoscaler_use_workload_identity = false
}

output "test2" {
  value = module.test2.manifest_yaml == file("./fixtures/test2.yaml")
}

output "test2b" {
  value = yamldecode(module.test2.manifest_yaml)["items"][0]
}