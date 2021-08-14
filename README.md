# PowerShell Scripts for Cisco UCS Manager Certificate Creation
# 
## Directions:
## Use the Create script to connect to your UCS Manager and create your new Certificate Request (CSR).
##
## Use the Build and Install script to convert your newly made certificate from the default CER format to a PEM format. This will also stack your certificates in the proper order and then will optionally ask you to install and activate the new certificate. 
##
### Note: Both scripts assume you use the "intermediate" certificate on UCS Manager (seperately installed) as the Trustpoint
