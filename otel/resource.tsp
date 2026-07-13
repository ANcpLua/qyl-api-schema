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
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Service.Name)
  serviceName: string;

  @doc("Service namespace for grouping")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Service.Namespace)
  serviceNamespace?: string;

  @doc("Service instance ID (unique per instance)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Service.InstanceId)
  serviceInstanceId?: string;

  @doc("Service version")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Service.Version)
  serviceVersion?: SemVer;

  @doc("Telemetry SDK name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Telemetry.SdkName)
  telemetrySdkName?: string;

  @doc("Telemetry SDK language")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Telemetry.SdkLanguage)
  telemetrySdkLanguage?: Enums.TelemetrySdkLanguage;

  @doc("Telemetry SDK version")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Telemetry.SdkVersion)
  telemetrySdkVersion?: SemVer;

  @doc("Auto-instrumentation agent name")
  @encodedName("application/json", "telemetry.auto.version")
  telemetryAutoVersion?: SemVer;

  @doc("Deployment environment (e.g., production, staging)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Deployment.EnvironmentName)
  deploymentEnvironment?: string;

  @doc("Cloud provider")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Cloud.Provider)
  cloudProvider?: CloudProvider;

  @doc("Cloud region")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Cloud.Region)
  cloudRegion?: string;

  @doc("Cloud availability zone")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Cloud.AvailabilityZone)
  cloudAvailabilityZone?: string;

  @doc("Cloud account ID")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Cloud.AccountId)
  cloudAccountId?: string;

  @doc("Cloud platform (e.g., aws_ecs, gcp_cloud_run)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Cloud.Platform)
  cloudPlatform?: string;

  @doc("Host name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Host.Name)
  hostName?: string;

  @doc("Host ID")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Host.Id)
  hostId?: string;

  @doc("Host type (e.g., n1-standard-1)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Host.Type)
  hostType?: string;

  @doc("Host architecture (e.g., amd64, arm64)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Host.Arch)
  hostArch?: HostArch;

  @doc("Operating system type")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Os.Type)
  osType?: OsType;

  @doc("Operating system description")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Os.Description)
  osDescription?: string;

  @doc("Operating system version")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Os.Version)
  osVersion?: string;

  @doc("Process ID")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Process.Pid)
  processPid?: int64;

  @doc("Process executable name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Process.ExecutableName)
  processExecutableName?: string;

  @doc("Process command line")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Process.CommandLine)
  processCommandLine?: string;

  @doc("Process runtime name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Process.RuntimeName)
  processRuntimeName?: string;

  @doc("Process runtime version")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Process.RuntimeVersion)
  processRuntimeVersion?: string;

  @doc("Container ID")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Container.Id)
  containerId?: string;

  @doc("Container name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Container.Name)
  containerName?: string;

  @doc("Container image name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Container.ImageName)
  containerImageName?: string;

  @doc("Container image tag")
  @encodedName("application/json", "container.image.tag")
  containerImageTag?: string;

  @doc("Kubernetes cluster name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.K8s.ClusterName)
  k8sClusterName?: string;

  @doc("Kubernetes namespace")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.K8s.NamespaceName)
  k8sNamespaceName?: string;

  @doc("Kubernetes pod name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.K8s.PodName)
  k8sPodName?: string;

  @doc("Kubernetes pod UID")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.K8s.PodUid)
  k8sPodUid?: string;

  @doc("Kubernetes deployment name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.K8s.DeploymentName)
  k8sDeploymentName?: string;

  @doc("Additional resource attributes")
  attributes?: Attribute[];

  @doc("Dropped attributes count")
  @encodedName("application/json", "dropped_attributes_count")
  droppedAttributesCount?: Count;
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
