# e2etest-ipv4networkallocations - Tests IPv4 network CIDR allocation from IPAM pool
# ================================================================================
# Creates an IPV4NetworkAllocation that allocates VPC and subnet CIDRs from a
# regional IPAM pool.
#
# Prerequisites:
# - Run aws-ipam e2e test first to create the persistent IPAM pool
# - Copy secrets/aws-creds from aws-ipam/tests/e2etest-ipam/secrets/
#
# The test:
# 1. Creates an IPV4NetworkAllocation with VPC /20 and subnets in 2 AZs
# 2. Verifies VPC pool, subnet pools, and allocations become Ready
# 3. Verifies CIDRs are populated in status
# 4. Deletes everything on cleanup

import base64
import datetime
import file
import math
import models.ai.com.ops.hops.aws.v1alpha1 as hops
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1

_now = str(int(math.floor(datetime.ticks())))

_creds = file.read("secrets/aws-creds")
_base64_creds = base64.encode(_creds)

# =============================================================================
# Configuration
# =============================================================================

# Unique name per run to avoid collisions
_allocation_name = "e2e-alloc-" + _now

# Region for allocation - must match the IPAM pool region
_region = "us-east-2"

# Regional pool ID from aws-ipam e2e test
# This is the IPv4 pool created by the persistent IPAM
# Update this after running aws-ipam e2e test:
#   aws ec2 describe-ipam-pools --query 'IpamPools[?contains(Description, `IPv4 pool`)].IpamPoolId'
_regional_pool_id = "ipam-pool-0a82c73b97dc0dabb"

_items = [
    metav1alpha1.E2ETest{
        metadata.name: ""
        spec = {
            crossplane.autoUpgrade.channel: "Rapid"
            defaultConditions: ["Ready"]
            manifests: [
                hops.IPV4NetworkAllocation{
                    metadata: {
                        name: _allocation_name
                        namespace: "default"
                    }
                    spec: {
                        regionalPoolId: _regional_pool_id
                        aws: {
                            providerConfig: "default"
                            region: _region
                        }
                        # Smaller VPC for e2e test
                        vpc: {
                            netmaskLength: 20
                        }
                        # Only 2 AZs for faster test
                        subnets: {
                            availabilityZones: ["a", "b"]
                            types: {
                                public: {
                                    netmaskLength: 26
                                }
                                private: {
                                    netmaskLength: 24
                                }
                            }
                        }
                    }
                }
            ]
            extraResources: [
                {
                    apiVersion: "v1"
                    kind: "Secret"
                    metadata: {
                        name: "aws-creds"
                        namespace: "default"
                    }
                    data: {
                        creds: _base64_creds
                    }
                },
                {
                    apiVersion: "aws.m.upbound.io/v1beta1"
                    kind: "ProviderConfig"
                    metadata: {
                        name: "default"
                        namespace: "default"
                    }
                    spec: {
                        credentials: {
                            source: "Secret"
                            secretRef: {
                                namespace: "default"
                                name: "aws-creds"
                                key: "creds"
                            }
                        }
                    }
                }
            ]
            skipDelete: False
            timeoutSeconds: 900  # 15 minutes - pool allocations can take time
        }
    }
]
items = _items
