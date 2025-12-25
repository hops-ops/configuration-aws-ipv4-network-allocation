# aws-ipv4-network-allocation

Crossplane configuration that bridges IPAM and Network by creating per-network IPAM pools and reserving IPv4 CIDRs via `VPCIpamPoolCidrAllocation`. Exposes allocated CIDRs in status for downstream Network configurations to consume.

## Overview

This configuration implements the IPv4 allocation layer in the four-entity networking model:

```
aws-ipam (global pools)
    └── aws-ipv4-network-allocation (per-network pools + allocations)
            └── aws-network (VPC + subnets using allocated CIDRs)
```

## Pool Hierarchy

The configuration creates a hierarchy of IPAM pools:

```
Regional Pool (from aws-ipam)
└── VPC Pool (/16 default)
    ├── Private Subnet Pool
    │   └── Allocations per AZ (/20 default)
    └── Public Subnet Pool
        └── Allocations per AZ (/24 default)
```

## Usage

### Minimal Example

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: IPv4NetworkAllocation
metadata:
  name: prod-east
  namespace: infra
spec:
  # Required: regional pool ID from aws-ipam status
  regionalPoolId: ipam-pool-0123456789abcdef0
```

Uses defaults:
- VPC netmask: /16
- Private subnets: /20 in AZs a, b, c
- Public subnets: /24 in AZs a, b, c

### Standard Example

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: IPv4NetworkAllocation
metadata:
  name: prod-east
  namespace: infra
spec:
  regionalPoolId: ipam-pool-0123456789abcdef0

  aws:
    providerConfig: default
    region: us-east-1

  vpc:
    netmaskLength: 16

  subnets:
    availabilityZones:
    - a
    - b
    - c
    types:
      public:
        netmaskLength: 24
      private:
        netmaskLength: 20
```

### Custom Sizes Example

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: IPv4NetworkAllocation
metadata:
  name: dev-west
  namespace: infra
spec:
  regionalPoolId: ipam-pool-0123456789abcdef0

  aws:
    providerConfig: default
    region: us-west-2

  # Smaller VPC for dev
  vpc:
    netmaskLength: 20

  # Only 2 AZs, smaller subnets
  subnets:
    availabilityZones:
    - a
    - b
    types:
      public:
        netmaskLength: 26
      private:
        netmaskLength: 24
```

## Status

Once all allocations are ready, the status exposes:

```yaml
status:
  ready: true
  cidr: "10.0.0.0/16"
  vpcPoolId: "ipam-pool-vpc-12345"
  privatePoolId: "ipam-pool-private-12345"
  publicPoolId: "ipam-pool-public-12345"
  subnets:
    private-a: "10.0.0.0/20"
    private-b: "10.0.16.0/20"
    private-c: "10.0.32.0/20"
    public-a: "10.0.48.0/24"
    public-b: "10.0.49.0/24"
    public-c: "10.0.50.0/24"
```

## Spec Reference

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `regionalPoolId` | string | (required) | ID of the regional IPAM pool to allocate from |
| `aws.providerConfig` | string | `"default"` | AWS ProviderConfig name |
| `aws.region` | string | `"us-east-1"` | AWS region |
| `vpc.netmaskLength` | integer | `16` | VPC CIDR netmask (8-28) |
| `subnets.availabilityZones` | []string | `["a", "b", "c"]` | AZ suffixes |
| `subnets.types.public.netmaskLength` | integer | `24` | Public subnet netmask (16-28) |
| `subnets.types.private.netmaskLength` | integer | `20` | Private subnet netmask (16-28) |
| `managementPolicies` | []string | `["*"]` | Crossplane management policies |

## Observed-State Gating

The composition uses observed-state gating to create resources in stages:

1. **Stage 1**: VPC pool + CIDR (always created)
2. **Stage 2**: Subnet pools + CIDRs (after VPC pool ready)
3. **Stage 3**: Subnet allocations (after subnet pools ready)

This prevents premature resource creation and ensures CIDRs are properly allocated before dependent resources reference them.

## Development

```bash
# Render examples
make render:all

# Validate examples
make validate:all

# Run unit tests
make test

# Run E2E tests (requires AWS credentials)
make e2e
```

## Testing

### Unit Tests

Located in `tests/test-render/`, these test:
- Minimal example with defaults
- Standard example with explicit values
- Multi-step reconciliation with observed resources
- Status output with allocated CIDRs

### E2E Tests

Located in `tests/e2etest-IPv4NetworkAllocations/`. Prerequisites:
1. Run `aws-ipam` E2E test first to create persistent IPAM
2. Copy AWS credentials to `tests/e2etest-IPv4NetworkAllocations/secrets/aws-creds`
3. Update `_regional_pool_id` in `main.k` with your pool ID

## Dependencies

- Requires `aws-ipam` to create regional pools
- Used by `aws-network` for VPC/subnet CIDRs
- Part of `aws-globalnetwork` orchestration
