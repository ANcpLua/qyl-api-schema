// =============================================================================
// OpenTelemetry resource JSON projection
// =============================================================================
// Resource attributes identifying the entity producing telemetry.
// =============================================================================

import "../common/types.tsp";
import "./enums.tsp";

using Qyl.Api.Contracts.Common;

namespace Qyl.Api.Contracts.OTel.Resource;

// =============================================================================
// Resource Model
// =============================================================================

@doc("Resource describes the entity producing telemetry")
model Resource {
  @doc("Service name (required)")
  @encodedName("application/json", "service_name")
  serviceName: string;

  @doc("Service namespace for grouping")
  @encodedName("application/json", "service_namespace")
  serviceNamespace?: string;

  @doc("Service instance ID (unique per instance)")
  @encodedName("application/json", "service_instance_id")
  serviceInstanceId?: string;

  @doc("Service version")
  @encodedName("application/json", "service_version")
  serviceVersion?: SemVer;

  @doc("Telemetry SDK name")
  @encodedName("application/json", "telemetry_sdk_name")
  telemetrySdkName?: string;

  @doc("Telemetry SDK language")
  @encodedName("application/json", "telemetry_sdk_language")
  telemetrySdkLanguage?: Enums.TelemetrySdkLanguage;

  @doc("Telemetry SDK version")
  @encodedName("application/json", "telemetry_sdk_version")
  telemetrySdkVersion?: SemVer;

  @doc("Telemetry distribution version")
  @encodedName("application/json", "telemetry_distro_version")
  telemetryDistroVersion?: SemVer;

  @doc("Deployment environment (e.g., production, staging)")
  @encodedName("application/json", "deployment_environment")
  deploymentEnvironment?: string;

  @doc("Cloud provider")
  @encodedName("application/json", "cloud_provider")
  cloudProvider?: CloudProvider;

  @doc("Cloud region")
  @encodedName("application/json", "cloud_region")
  cloudRegion?: string;

  @doc("Cloud availability zone")
  @encodedName("application/json", "cloud_availability_zone")
  cloudAvailabilityZone?: string;

  @doc("Cloud account ID")
  @encodedName("application/json", "cloud_account_id")
  cloudAccountId?: string;

  @doc("Cloud platform (e.g., aws_ecs, gcp_cloud_run)")
  @encodedName("application/json", "cloud_platform")
  cloudPlatform?: string;

  @doc("Host name")
  @encodedName("application/json", "host_name")
  hostName?: string;

  @doc("Host ID")
  @encodedName("application/json", "host_id")
  hostId?: string;

  @doc("Host type (e.g., n1-standard-1)")
  @encodedName("application/json", "host_type")
  hostType?: string;

  @doc("Host architecture (e.g., amd64, arm64)")
  @encodedName("application/json", "host_arch")
  hostArch?: HostArch;

  @doc("Operating system type")
  @encodedName("application/json", "os_type")
  osType?: OsType;

  @doc("Operating system description")
  @encodedName("application/json", "os_description")
  osDescription?: string;

  @doc("Operating system version")
  @encodedName("application/json", "os_version")
  osVersion?: string;

  @doc("Process ID")
  @encodedName("application/json", "process_pid")
  processPid?: int64;

  @doc("Process executable name")
  @encodedName("application/json", "process_executable_name")
  processExecutableName?: string;

  @doc("Process command line")
  @encodedName("application/json", "process_command_line")
  processCommandLine?: string;

  @doc("Process runtime name")
  @encodedName("application/json", "process_runtime_name")
  processRuntimeName?: string;

  @doc("Process runtime version")
  @encodedName("application/json", "process_runtime_version")
  processRuntimeVersion?: string;

  @doc("Container ID")
  @encodedName("application/json", "container_id")
  containerId?: string;

  @doc("Container name")
  @encodedName("application/json", "container_name")
  containerName?: string;

  @doc("Container image name")
  @encodedName("application/json", "container_image_name")
  containerImageName?: string;

  @doc("Container image tags")
  @encodedName("application/json", "container_image_tags")
  containerImageTags?: string[];

  @doc("Kubernetes cluster name")
  @encodedName("application/json", "k8s_cluster_name")
  k8sClusterName?: string;

  @doc("Kubernetes namespace")
  @encodedName("application/json", "k8s_namespace_name")
  k8sNamespaceName?: string;

  @doc("Kubernetes pod name")
  @encodedName("application/json", "k8s_pod_name")
  k8sPodName?: string;

  @doc("Kubernetes pod UID")
  @encodedName("application/json", "k8s_pod_uid")
  k8sPodUid?: string;

  @doc("Kubernetes deployment name")
  @encodedName("application/json", "k8s_deployment_name")
  k8sDeploymentName?: string;

  @doc("Additional resource attributes")
  attributes?: Attribute[];

  @doc("Dropped attributes count")
  @encodedName("application/json", "dropped_attributes_count")
  droppedAttributesCount?: Count;

  @doc("Entities participating in this Resource, keyed by attributes on the Resource.")
  @encodedName("application/json", "entity_refs")
  entityRefs?: EntityRef[];
}

// =============================================================================
// Resource-Related Enums
// =============================================================================

@doc("Cloud provider types")
enum CloudProvider {
  @doc("Alibaba Cloud")
  alibabaCloud: "alibaba_cloud",

  @doc("Amazon Web Services")
  aws: "aws",

  @doc("Microsoft Azure")
  azure: "azure",

  @doc("Google Cloud Platform")
  gcp: "gcp",

  @doc("Heroku")
  heroku: "heroku",

  @doc("IBM Cloud")
  ibmCloud: "ibm_cloud",

  @doc("Tencent Cloud")
  tencentCloud: "tencent_cloud",
}

@doc("Host architecture types")
enum HostArch {
  @doc("AMD64 / x86_64")
  amd64: "amd64",

  @doc("ARM32")
  arm32: "arm32",

  @doc("ARM64 / aarch64")
  arm64: "arm64",

  @doc("Itanium")
  ia64: "ia64",

  @doc("PowerPC 32-bit")
  ppc32: "ppc32",

  @doc("PowerPC 64-bit")
  ppc64: "ppc64",

  @doc("IBM z/Architecture")
  s390x: "s390x",

  @doc("x86 32-bit")
  x86: "x86",
}

@doc("Operating system types")
enum OsType {
  @doc("Microsoft Windows")
  windows: "windows",

  @doc("Linux")
  linux: "linux",

  @doc("Apple macOS")
  darwin: "darwin",

  @doc("FreeBSD")
  freebsd: "freebsd",

  @doc("NetBSD")
  netbsd: "netbsd",

  @doc("OpenBSD")
  openbsd: "openbsd",

  @doc("DragonFly BSD")
  dragonflybsd: "dragonflybsd",

  @doc("HP-UX")
  hpux: "hpux",

  @doc("AIX")
  aix: "aix",

  @doc("Oracle Solaris")
  solaris: "solaris",

  @doc("IBM z/OS")
  zOs: "z_os",
}
