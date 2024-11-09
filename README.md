# sunnyvalelabs

## cloud custodian

1. deploy amazon linux 2023

2. install cloud custodian
```
aws configure
pip install c7n 
```

3. clone project
```
git clone https://github.com/alberttwong/sunnyvalelabs.git
```

4. systemd
```
cp /etc/systemd/system/custodian.timer
cp /etc/systemd/system/custodian.service
sudo systemctl daemon-reload
sudo systemctl enable custodian.timer
sudo systemctl start custodian.timer
sudo journalctl -u custodian.service
```
