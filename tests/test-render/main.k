import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1

_items = [
    # Test 1: Minimal example - initial render (no observed resources)
    # Should create VPC pool and CIDR with defaults
    # Note: minimal.yaml uses name "prod-east" and regionalPoolId "ipam-pool-0123456789abcdef0"
    metav1alpha1.CompositionTest{
        metadata.name: "test-ipv4-allocation-minimal"
        spec = {
            compositionPath: "apis/IPv4NetworkAllocations/composition.yaml"
            xrPath: "examples/IPv4NetworkAllocations/minimal.yaml"
            xrdPath: "apis/IPv4NetworkAllocations/definition.yaml"
            timeoutSeconds: 120
            validate: True
            assertResources: [
                # VPC Pool - child of regional pool
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPool"
                    metadata: {
                        name: "prod-east-vpc"
                        labels: {
                            "hops.ops.com.ai/network-allocation": "prod-east"
                            "hops.ops.com.ai/pool-type": "vpc"
                        }
                    }
                    spec: {
                        managementPolicies: ["*"]
                        forProvider: {
                            addressFamily: "ipv4"
                            ipamScopeId: "ipam-scope-0123456789abcdef0"
                            sourceIpamPoolId: "ipam-pool-0123456789abcdef0"
                            allocationDefaultNetmaskLength: 16
                            locale: "us-east-1"
                            region: "us-east-1"
                            tags: {
                                hops: "true"
                                "managed-by": "crossplane"
                            }
                        }
                        providerConfigRef: {
                            kind: "ProviderConfig"
                            name: "default"
                        }
                    }
                },
                # VPC Pool CIDR - allocates /16 from regional pool
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidr"
                    metadata: {
                        name: "prod-east-vpc"
                    }
                    spec: {
                        managementPolicies: ["*"]
                        forProvider: {
                            netmaskLength: 16
                            region: "us-east-1"
                        }
                        providerConfigRef: {
                            kind: "ProviderConfig"
                            name: "default"
                        }
                    }
                }
            ]
        }
    },

    # Test 2: Standard example with explicit values
    metav1alpha1.CompositionTest{
        metadata.name: "test-ipv4-allocation-standard"
        spec = {
            compositionPath: "apis/IPv4NetworkAllocations/composition.yaml"
            xrPath: "examples/IPv4NetworkAllocations/standard.yaml"
            xrdPath: "apis/IPv4NetworkAllocations/definition.yaml"
            timeoutSeconds: 120
            validate: True
            assertResources: [
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPool"
                    metadata: {
                        name: "prod-east-vpc"
                    }
                    spec: {
                        forProvider: {
                            addressFamily: "ipv4"
                            ipamScopeId: "ipam-scope-0123456789abcdef0"
                            sourceIpamPoolId: "ipam-pool-0123456789abcdef0"
                            allocationDefaultNetmaskLength: 16
                            locale: "us-east-1"
                            region: "us-east-1"
                        }
                        providerConfigRef: {
                            kind: "ProviderConfig"
                            name: "default"
                        }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidr"
                    metadata: {
                        name: "prod-east-vpc"
                    }
                    spec: {
                        forProvider: {
                            netmaskLength: 16
                            region: "us-east-1"
                        }
                    }
                }
            ]
        }
    },

    # Test 3: With VPC pool ready - should create subnet pools
    metav1alpha1.CompositionTest{
        metadata.name: "test-ipv4-allocation-step2-subnet-pools"
        spec = {
            compositionPath: "apis/IPv4NetworkAllocations/composition.yaml"
            xrPath: "examples/IPv4NetworkAllocations/standard.yaml"
            xrdPath: "apis/IPv4NetworkAllocations/definition.yaml"
            timeoutSeconds: 120
            validate: True
            observedResources: [
                # VPC Pool - Ready
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPool"
                    metadata: {
                        name: "prod-east-vpc"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "vpc-pool"
                            "crossplane.io/composition-resource-name": "vpc-pool"
                        }
                    }
                    status: {
                        conditions: [
                            { type: "Ready", status: "True" }
                        ]
                        atProvider: {
                            id: "ipam-pool-vpc-12345"
                            arn: "arn:aws:ec2:us-east-1:123456789012:ipam-pool/ipam-pool-vpc-12345"
                        }
                    }
                },
                # VPC Pool CIDR - Ready with allocated CIDR
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidr"
                    metadata: {
                        name: "prod-east-vpc"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "vpc-pool-cidr"
                            "crossplane.io/composition-resource-name": "vpc-pool-cidr"
                        }
                    }
                    status: {
                        conditions: [
                            { type: "Ready", status: "True" }
                        ]
                        atProvider: {
                            id: "ipam-pool-cidr-vpc"
                            cidr: "10.0.0.0/16"
                        }
                    }
                }
            ]
            assertResources: [
                # VPC Pool still exists
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPool"
                    metadata: { name: "prod-east-vpc" }
                },
                # Private Subnet Pool - child of VPC pool
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPool"
                    metadata: {
                        name: "prod-east-private"
                        labels: {
                            "hops.ops.com.ai/network-allocation": "prod-east"
                            "hops.ops.com.ai/pool-type": "subnet-private"
                        }
                    }
                    spec: {
                        forProvider: {
                            addressFamily: "ipv4"
                            ipamScopeId: "ipam-scope-0123456789abcdef0"
                            sourceIpamPoolId: "ipam-pool-vpc-12345"
                            allocationDefaultNetmaskLength: 20
                            locale: "us-east-1"
                            region: "us-east-1"
                        }
                    }
                },
                # Private Subnet Pool CIDR
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidr"
                    metadata: { name: "prod-east-private" }
                    spec: {
                        forProvider: {
                            cidr: "10.0.0.0/16"
                            region: "us-east-1"
                        }
                    }
                },
                # Public Subnet Pool - child of VPC pool
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPool"
                    metadata: {
                        name: "prod-east-public"
                        labels: {
                            "hops.ops.com.ai/network-allocation": "prod-east"
                            "hops.ops.com.ai/pool-type": "subnet-public"
                        }
                    }
                    spec: {
                        forProvider: {
                            addressFamily: "ipv4"
                            ipamScopeId: "ipam-scope-0123456789abcdef0"
                            sourceIpamPoolId: "ipam-pool-vpc-12345"
                            allocationDefaultNetmaskLength: 24
                            locale: "us-east-1"
                            region: "us-east-1"
                        }
                    }
                },
                # Public Subnet Pool CIDR
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidr"
                    metadata: { name: "prod-east-public" }
                    spec: {
                        forProvider: {
                            cidr: "10.0.0.0/16"
                            region: "us-east-1"
                        }
                    }
                }
            ]
        }
    },

    # Test 4: With subnet pools ready - should create allocations
    metav1alpha1.CompositionTest{
        metadata.name: "test-ipv4-allocation-step3-allocations"
        spec = {
            compositionPath: "apis/IPv4NetworkAllocations/composition.yaml"
            xrPath: "examples/IPv4NetworkAllocations/standard.yaml"
            xrdPath: "apis/IPv4NetworkAllocations/definition.yaml"
            timeoutSeconds: 120
            validate: True
            observedResources: [
                # VPC Pool - Ready
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPool"
                    metadata: {
                        name: "prod-east-vpc"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "vpc-pool"
                            "crossplane.io/composition-resource-name": "vpc-pool"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: {
                            id: "ipam-pool-vpc-12345"
                            arn: "arn:aws:ec2:us-east-1:123456789012:ipam-pool/ipam-pool-vpc-12345"
                        }
                    }
                },
                # VPC Pool CIDR - Ready
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidr"
                    metadata: {
                        name: "prod-east-vpc"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "vpc-pool-cidr"
                            "crossplane.io/composition-resource-name": "vpc-pool-cidr"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: {
                            id: "ipam-pool-cidr-vpc"
                            cidr: "10.0.0.0/16"
                        }
                    }
                },
                # Private Subnet Pool - Ready
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPool"
                    metadata: {
                        name: "prod-east-private"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "subnet-pool-private"
                            "crossplane.io/composition-resource-name": "subnet-pool-private"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: {
                            id: "ipam-pool-private-12345"
                            arn: "arn:aws:ec2:us-east-1:123456789012:ipam-pool/ipam-pool-private-12345"
                        }
                    }
                },
                # Private Subnet Pool CIDR - Ready
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidr"
                    metadata: {
                        name: "prod-east-private"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "subnet-pool-private-cidr"
                            "crossplane.io/composition-resource-name": "subnet-pool-private-cidr"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: { id: "ipam-pool-cidr-private" }
                    }
                },
                # Public Subnet Pool - Ready
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPool"
                    metadata: {
                        name: "prod-east-public"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "subnet-pool-public"
                            "crossplane.io/composition-resource-name": "subnet-pool-public"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: {
                            id: "ipam-pool-public-12345"
                            arn: "arn:aws:ec2:us-east-1:123456789012:ipam-pool/ipam-pool-public-12345"
                        }
                    }
                },
                # Public Subnet Pool CIDR - Ready
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidr"
                    metadata: {
                        name: "prod-east-public"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "subnet-pool-public-cidr"
                            "crossplane.io/composition-resource-name": "subnet-pool-public-cidr"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: { id: "ipam-pool-cidr-public" }
                    }
                }
            ]
            assertResources: [
                # Private subnet allocations for AZs a, b, c
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidrAllocation"
                    metadata: {
                        name: "prod-east-private-a"
                        labels: {
                            "hops.ops.com.ai/network-allocation": "prod-east"
                            "hops.ops.com.ai/subnet-type": "private"
                            "hops.ops.com.ai/availability-zone": "a"
                        }
                    }
                    spec: {
                        forProvider: {
                            ipamPoolId: "ipam-pool-private-12345"
                            netmaskLength: 20
                            region: "us-east-1"
                        }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidrAllocation"
                    metadata: {
                        name: "prod-east-private-b"
                        labels: {
                            "hops.ops.com.ai/subnet-type": "private"
                            "hops.ops.com.ai/availability-zone": "b"
                        }
                    }
                    spec: {
                        forProvider: {
                            ipamPoolId: "ipam-pool-private-12345"
                            netmaskLength: 20
                        }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidrAllocation"
                    metadata: {
                        name: "prod-east-private-c"
                        labels: {
                            "hops.ops.com.ai/subnet-type": "private"
                            "hops.ops.com.ai/availability-zone": "c"
                        }
                    }
                    spec: {
                        forProvider: {
                            ipamPoolId: "ipam-pool-private-12345"
                            netmaskLength: 20
                        }
                    }
                },
                # Public subnet allocations for AZs a, b, c
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidrAllocation"
                    metadata: {
                        name: "prod-east-public-a"
                        labels: {
                            "hops.ops.com.ai/subnet-type": "public"
                            "hops.ops.com.ai/availability-zone": "a"
                        }
                    }
                    spec: {
                        forProvider: {
                            ipamPoolId: "ipam-pool-public-12345"
                            netmaskLength: 24
                        }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidrAllocation"
                    metadata: {
                        name: "prod-east-public-b"
                        labels: {
                            "hops.ops.com.ai/subnet-type": "public"
                            "hops.ops.com.ai/availability-zone": "b"
                        }
                    }
                    spec: {
                        forProvider: {
                            ipamPoolId: "ipam-pool-public-12345"
                            netmaskLength: 24
                        }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidrAllocation"
                    metadata: {
                        name: "prod-east-public-c"
                        labels: {
                            "hops.ops.com.ai/subnet-type": "public"
                            "hops.ops.com.ai/availability-zone": "c"
                        }
                    }
                    spec: {
                        forProvider: {
                            ipamPoolId: "ipam-pool-public-12345"
                            netmaskLength: 24
                        }
                    }
                }
            ]
        }
    },

    # Test 5: Custom sizes example (dev-west with /20 VPC, /24 private, /26 public)
    metav1alpha1.CompositionTest{
        metadata.name: "test-ipv4-allocation-custom-sizes"
        spec = {
            compositionPath: "apis/IPv4NetworkAllocations/composition.yaml"
            xrPath: "examples/IPv4NetworkAllocations/custom-sizes.yaml"
            xrdPath: "apis/IPv4NetworkAllocations/definition.yaml"
            timeoutSeconds: 120
            validate: True
            assertResources: [
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPool"
                    metadata: { name: "dev-west-vpc" }
                    spec: {
                        forProvider: {
                            allocationDefaultNetmaskLength: 20
                            locale: "us-west-2"
                            region: "us-west-2"
                        }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidr"
                    metadata: { name: "dev-west-vpc" }
                    spec: {
                        forProvider: {
                            netmaskLength: 20
                            region: "us-west-2"
                        }
                    }
                }
            ]
        }
    },

    # Test 6: Full flow with all allocations ready - verify status
    metav1alpha1.CompositionTest{
        metadata.name: "test-ipv4-allocation-complete-status"
        spec = {
            compositionPath: "apis/IPv4NetworkAllocations/composition.yaml"
            xrPath: "examples/IPv4NetworkAllocations/standard.yaml"
            xrdPath: "apis/IPv4NetworkAllocations/definition.yaml"
            timeoutSeconds: 120
            validate: True
            observedResources: [
                # VPC Pool - Ready
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPool"
                    metadata: {
                        name: "prod-east-vpc"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "vpc-pool"
                            "crossplane.io/composition-resource-name": "vpc-pool"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: {
                            id: "ipam-pool-vpc-12345"
                            arn: "arn:aws:ec2:us-east-1:123456789012:ipam-pool/ipam-pool-vpc-12345"
                        }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidr"
                    metadata: {
                        name: "prod-east-vpc"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "vpc-pool-cidr"
                            "crossplane.io/composition-resource-name": "vpc-pool-cidr"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: { id: "ipam-pool-cidr-vpc", cidr: "10.0.0.0/16" }
                    }
                },
                # Subnet Pools - Ready
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPool"
                    metadata: {
                        name: "prod-east-private"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "subnet-pool-private"
                            "crossplane.io/composition-resource-name": "subnet-pool-private"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: { id: "ipam-pool-private-12345" }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidr"
                    metadata: {
                        name: "prod-east-private"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "subnet-pool-private-cidr"
                            "crossplane.io/composition-resource-name": "subnet-pool-private-cidr"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: { id: "ipam-pool-cidr-private" }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPool"
                    metadata: {
                        name: "prod-east-public"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "subnet-pool-public"
                            "crossplane.io/composition-resource-name": "subnet-pool-public"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: { id: "ipam-pool-public-12345" }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidr"
                    metadata: {
                        name: "prod-east-public"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "subnet-pool-public-cidr"
                            "crossplane.io/composition-resource-name": "subnet-pool-public-cidr"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: { id: "ipam-pool-cidr-public" }
                    }
                },
                # Subnet Allocations - Ready with CIDRs
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidrAllocation"
                    metadata: {
                        name: "prod-east-private-a"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "subnet-private-a"
                            "crossplane.io/composition-resource-name": "subnet-private-a"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: { id: "alloc-private-a", cidr: "10.0.0.0/20" }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidrAllocation"
                    metadata: {
                        name: "prod-east-private-b"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "subnet-private-b"
                            "crossplane.io/composition-resource-name": "subnet-private-b"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: { id: "alloc-private-b", cidr: "10.0.16.0/20" }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidrAllocation"
                    metadata: {
                        name: "prod-east-private-c"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "subnet-private-c"
                            "crossplane.io/composition-resource-name": "subnet-private-c"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: { id: "alloc-private-c", cidr: "10.0.32.0/20" }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidrAllocation"
                    metadata: {
                        name: "prod-east-public-a"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "subnet-public-a"
                            "crossplane.io/composition-resource-name": "subnet-public-a"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: { id: "alloc-public-a", cidr: "10.0.48.0/24" }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidrAllocation"
                    metadata: {
                        name: "prod-east-public-b"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "subnet-public-b"
                            "crossplane.io/composition-resource-name": "subnet-public-b"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: { id: "alloc-public-b", cidr: "10.0.49.0/24" }
                    }
                },
                {
                    apiVersion: "ec2.aws.m.upbound.io/v1beta1"
                    kind: "VPCIpamPoolCidrAllocation"
                    metadata: {
                        name: "prod-east-public-c"
                        annotations: {
                            "gotemplating.fn.crossplane.io/composition-resource-name": "subnet-public-c"
                            "crossplane.io/composition-resource-name": "subnet-public-c"
                        }
                    }
                    status: {
                        conditions: [{ type: "Ready", status: "True" }]
                        atProvider: { id: "alloc-public-c", cidr: "10.0.50.0/24" }
                    }
                }
            ]
            assertResources: [
                # XR status should be updated with all CIDRs
                {
                    apiVersion: "aws.hops.ops.com.ai/v1alpha1"
                    kind: "IPv4NetworkAllocation"
                    metadata: {
                        name: "prod-east"
                    }
                    status: {
                        ready: True
                        cidr: "10.0.0.0/16"
                        vpcPoolId: "ipam-pool-vpc-12345"
                        privatePoolId: "ipam-pool-private-12345"
                        publicPoolId: "ipam-pool-public-12345"
                        subnets: {
                            "private-a": "10.0.0.0/20"
                            "private-b": "10.0.16.0/20"
                            "private-c": "10.0.32.0/20"
                            "public-a": "10.0.48.0/24"
                            "public-b": "10.0.49.0/24"
                            "public-c": "10.0.50.0/24"
                        }
                    }
                }
            ]
        }
    }
]

items = _items
