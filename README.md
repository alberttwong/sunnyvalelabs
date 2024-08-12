# sunnyvalelabs

deploy amazon linux 2023



install cloud custodian
```
pip install c7n 
```


clone project
```
git clone https://github.com/alberttwong/sunnyvalelabs.git
```

install cronie
```
Follow https://jainsaket-1994.medium.com/installing-crontab-on-amazon-linux-2023-ec2-98cf2708b171
```


crontab
```
*/5 * * * * /home/ec2-user/sunnyvalelabs/custodian_cronjob.sh >> /home/ec2-user/sunnyvalelabs/logs/custodian.log 2>&1
```
