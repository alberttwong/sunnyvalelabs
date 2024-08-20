cd /home/ec2-user/sunnyvalelabs/
~/.local/bin/c7n-mailer --config mailer.yml --update-lambda && ~/.local/bin/custodian run --output-dir=logs --metrics aws custodian.yml
