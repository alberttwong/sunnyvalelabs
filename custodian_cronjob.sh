#!/bin/bash
cd /home/ec2-user/sunnyvalelabs/
custodian run --output-dir=logs --metrics aws custodian.yml
