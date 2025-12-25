# aws-ipv4-network-allocation

Bridge between IPAM (address space) and Network (infrastructure). Reserves IPv4 VPC and subnet CIDRs via IPAM pool allocations.

## Purpose

IPv4NetworkAllocation creates per-network pools and allocations from a regional IPAM pool, then exposes the allocated CIDRs in status for aws-network to consume.

## Pool Hierarchy

```
aws-ipam creates:
├── Global Pool /8 (10.0.0.0/8)
└── Regional Pools /12 (children of global)
      └── us-east-1 pool (10.0.0.0/12)

IPv4NetworkAllocation creates (per network):
└── VPC Pool (child of regional)
      └── VPCIpamPoolCidr (gets /16 from regional)
      │
      ├── Private Subnet Pool (child of VPC pool)
      │     └── VPCIpamPoolCidr (VPC's /16)
      │     └── allocationDefaultNetmaskLength: 20
      │     └── VPCIpamPoolCidrAllocation × N (per AZ)
      │
      └── Public Subnet Pool (child of VPC pool)
            └── VPCIpamPoolCidr (VPC's /16)
            └── allocationDefaultNetmaskLength: 24
            └── VPCIpamPoolCidrAllocation × N (per AZ)
```

## Observed-State Gating Flow

Templates execute in order, each gating on the previous step:

```
20-vpc-pool.yaml.gotmpl
    │ Creates: VPCIpamPool, VPCIpamPoolCidr
    ▼
10-observed-values.yaml.gotmpl
    │ Checks: VPC pool ready, extracts pool ID + CIDR
    ▼
30-subnet-pools.yaml.gotmpl
    │ Creates: Private pool, Public pool, PoolCidrs
    │ Gated on: $vpcPoolFullyReady
    ▼
40-subnet-allocations.yaml.gotmpl
    │ Creates: VPCIpamPoolCidrAllocation per subnet
    │ Gated on: $subnetPoolsFullyReady
    ▼
99-status.yaml.gotmpl
    │ Reads all allocation CIDRs, outputs status
```

## API

```yaml
apiVersion: aws.hops.ops.com.ai/v1alpha1
kind: IPv4NetworkAllocation
metadata:
  name: prod-east
  namespace: infra
spec:
  # Required: regional pool ID from aws-ipam status
  regionalPoolId: ipam-pool-0123456789abcdef0

  aws:
    providerConfig: default
    region: us-east-1

  vpc:
    netmaskLength: 16  # VPC CIDR size

  subnets:
    availabilityZones: [a, b, c]
    types:
      public:
        netmaskLength: 24
      private:
        netmaskLength: 20

status:
  ready: true
  cidr: "10.1.0.0/16"
  vpcPoolId: ipam-pool-xxx
  privatePoolId: ipam-pool-yyy
  publicPoolId: ipam-pool-zzz
  subnets:
    public-a: "10.1.0.0/24"
    public-b: "10.1.1.0/24"
    public-c: "10.1.2.0/24"
    private-a: "10.1.16.0/20"
    private-b: "10.1.32.0/20"
    private-c: "10.1.48.0/20"
```

## Development

```bash
make render:all     # Render all examples
make validate:all   # Validate all examples
make test           # Run KCL tests
make e2e            # Run E2E tests
```

## Key Conventions

- Uses `.m.` namespaced API versions for Crossplane 2.0 compatibility
- All templates use `setResourceNameAnnotation` for observed-state tracking
- IPAM does all CIDR math - no calculations in templates
- Status exposes CIDRs for downstream consumers (aws-network, aws-globalnetwork)

## Avoid Upbound-hosted packages

Favor `crossplane-contrib` packages over Upbound-hosted ones due to paid-account restrictions.
