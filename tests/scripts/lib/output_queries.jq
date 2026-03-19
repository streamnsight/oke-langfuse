def output($name):
  .[$name].value;

def fixture_cluster_id:
  output("cluster_id");

def fixture_bastion_id:
  output("bastion_id");

def cluster_id:
  .test_metadata.value.cluster.id;

def cluster_name:
  .test_metadata.value.cluster.name;

def bastion_id:
  .test_metadata.value.bastion.id;

def workload_subnet_id:
  .test_metadata.value.network.workload_subnet_id;

def kubernetes_endpoint_subnet_id:
  .test_metadata.value.network.kubernetes_endpoint_subnet_id;

def vcn_id:
  .test_metadata.value.network.vcn_id;

def devops_project_id:
  .test_metadata.value.devops.project_id;

def devops_environment_id:
  .test_metadata.value.devops.environment_id;
