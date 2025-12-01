# ACM Certificate Analysis Test Scenarios

| **NO.** | **Case ID** | **Certificate type** | **Issuer type** | **Root CA included** | **ACM installed** | **ServerVerificationStrategy** | **Output** |
|---------|-------------|----------------------|-----------------|----------------------|-------------------|--------------------------------|----------|
|    1    |      pre-01 | OpenShift managed    | Self-signed     |          Yes         |         No        | n/a                            |     [pre-01](output/pre-01.txt) |
|    2    |      pre-02 | Custom               | Self-signed     |          No          |         No        | n/a                            |     [pre-02](output/pre-02.txt) |
|    3    |      pre-03 | Custom               | Self-signed     |          Yes         |         No        | n/a                            |     [pre-03](output/pre-03.txt) |
|    4    |      pre-04 | Custom               | Well-known      |          No          |         No        | n/a                            |     [pre-04](output/pre-04.txt) |
|    5    |      pre-05 | Custom               | Well-known      |          Yes         |         No        | n/a                            |     [pre-05](output/pre-05.txt) |
|    6    |      pre-06 | RedHat managed       | Well-known      |          No          |         No        | n/a                            |     [pre-06](output/pre-06.txt) |
|    7    |     post-01 | OpenShift managed    | Self-signed     |          Yes         |        Yes        | UseAutoDetectedCABundle        |    [post-01](output/post-01.txt) |
|    8    |     post-02 | Custom               | Self-signed     |          No          |        Yes        | UseAutoDetectedCABundle        |    [post-02](output/post-02.txt) |
|    9    |     post-03 | Custom               | Self-signed     |          Yes         |        Yes        | UseAutoDetectedCABundle        |    [post-03](output/post-03.txt) |
|    10   |     post-04 | Custom               | Well-known      |          No          |        Yes        | UseAutoDetectedCABundle        |    [post-04](output/post-04.txt) |
|    11   |     post-05 | Custom               | Well-known      |          No          |        Yes        | UseSystemTruststore            |    [post-05](output/post-05.txt) |
|    12   |     post-06 | Custom               | Well-known      |          Yes         |        Yes        | UseAutoDetectedCABundle        |    [post-06](output/post-06.txt) |
|    13   |     post-07 | Custom               | Well-known      |          Yes         |        Yes        | UseSystemTruststore            |    [post-07](output/post-07.txt) |
|    14   |     post-08 | RedHat managed       | Well-known      |          No          |        Yes        | UseAutoDetectedCABundle        |    [post-08](output/post-08.txt) |
|    15   |     post-09 | RedHat managed       | Well-known      |          No          |        Yes        | UseSystemTruststore            |    [post-09](output/post-09.txt) |